open! Core
open Protocol_emulator

module Model = struct
  type t =
    { fault : Machine.Fault.t
    ; moved : bool
    }
end

module Variant = struct
  type t =
    { k : int
    ; source : string
    ; config : Program_config.t
    ; words : int list
    ; analyser : unit Or_error.t
    ; kernel : unit Or_error.t
    ; rejections : Kernel.Rejection.t list
    ; model : Model.t Lazy.t
    }

  let accepted t = Result.is_ok t.analyser && Result.is_ok t.kernel

  let late t =
    let { Model.fault; moved } = force t.model in
    moved || not (Machine.Fault.equal fault Machine.Fault.none)
  ;;
end

type t =
  { swept : Swept.t
  ; certified : Certified.t
  ; wait_pc : int
  ; slack : int
  ; edges : int list list
  }

let nops ~side_set_count ~side k =
  let longest = 1 lsl (Isa.Field.delay_side.width - side_set_count) in
  let side = if side_set_count = 0 then "" else [%string " side %{side#Int}"] in
  let nop cycles =
    let delay = if cycles = 1 then "" else [%string " [%{cycles - 1#Int}]"] in
    [%string "    nop%{side}%{delay}"]
  in
  let rest = if k % longest = 0 then [] else [ nop (k % longest) ] in
  List.init (k / longest) ~f:(fun _ -> nop longest) @ rest
;;

let timer_mask = (1 lsl Isa.timer_bits) - 1

(* far longer than any burst *)
let longest_run = 1 lsl 22

(* The core alone on the model, driven as the sweep drives it: the preamble, then each
   burst once the core waits for the host again. Each run's edges on the wire in cycles
   from its first, the setup's first, and the faults at the end. *)
let run ~config ~words ~preamble ~bursts =
  let level (m : Machine.t) = (m.pin_out lsr Swept.wire) land 1 in
  let waits_for_host =
    Array.of_list_map words ~f:(fun w ->
      match Isa.of_word ~side_set_count:config.Program_config.side_set_count w with
      | Ok (Op { op = Wait (Fifo Tx_not_empty); _ }) -> true
      | Ok _ | Error _ -> false)
  in
  let engine =
    List.fold
      preamble
      ~init:(Machine.create ~config ~program:words |> ok_exn)
      ~f:(fun m w -> Machine.write_tx m w |> ok_exn)
  in
  let system = ref (System.create [ engine ]) in
  let core () = List.hd_exn !system.engines in
  let idle () =
    let m = core () in
    List.is_empty m.tx_fifo && m.pc < Array.length waits_for_host && waits_for_host.(m.pc)
  in
  let until_idle () =
    let edges = Queue.create () in
    let steps = ref 0 in
    (* a run starts at the wait for the host, with its words in the fifo *)
    while !steps = 0 || not (idle ()) do
      Int.incr steps;
      if !steps > longest_run then raise_s [%message "the core never waits for the host"];
      let before = level (core ()) in
      system := System.step !system ~pads:0;
      if before <> level (core ()) then Queue.enqueue edges (core ()).now
    done;
    match Queue.to_list edges with
    | [] -> []
    | first :: _ as edges -> List.map edges ~f:(fun at -> (at - first) land timer_mask)
  in
  let setup = until_idle () in
  let runs =
    List.map bursts ~f:(fun burst ->
      system
      := System.update !system 0 ~f:(fun m ->
           List.fold burst ~init:m ~f:(fun m w -> Machine.write_tx m w |> ok_exn));
      until_idle ())
  in
  setup :: runs, (core ()).fault
;;

let assembled (swept : Swept.t) (certified : Certified.t) source =
  let program = Asm.assemble source |> ok_exn in
  program, Asm.Program.configure program (swept.on_wire certified.config)
;;

let ran (swept : Swept.t) ~config ~words =
  run ~config ~words ~preamble:(Option.to_list swept.period) ~bursts:swept.bursts
;;

let check (swept : Swept.t) (certified : Certified.t) ~edges k ~source =
  let program, config = assembled swept certified source in
  let words = Asm.Program.words program |> ok_exn in
  let { Swept.period; _ } = swept in
  let { Certified.single_capture_edge; _ } = certified in
  let table =
    Analyser.analyse ?period ~single_capture_edge ~config program.instructions
    |> Kernel.Table.of_analyser
  in
  { Variant.k
  ; source
  ; config
  ; words
  ; analyser =
      Analyser.check
        ?period
        ~single_capture_edge
        ~config:(swept.on_wire certified.config)
        program
      |> Or_error.ignore_m
  ; kernel = Kernel.check ?period ~single_capture_edge ~config ~words table
  ; rejections = Kernel.rejections ?period ~single_capture_edge ~config ~words table
  ; model =
      lazy
        (let moved_to, fault = ran swept ~config ~words in
         { Model.fault; moved = not ([%equal: int list list] moved_to edges) })
  }
;;

(* The deadline wait with the least slack and its pc, the first of any tie. *)
let tightest (swept : Swept.t) (certified : Certified.t) =
  let timed =
    Timed_program.of_source_exn
      ?period:swept.period
      ~single_capture_edge:certified.single_capture_edge
      ~config:(swept.on_wire certified.config)
      certified.source
  in
  Timed_program.rows timed
  |> List.filter_map ~f:(fun (r : Analyser.Row.t) ->
    Option.bind r.slack ~f:(fun s -> s.lo) |> Option.map ~f:(fun slack -> slack, r.pc))
  |> List.min_elt ~compare:[%compare: int * int]
  |> Option.value_exn ~message:"no deadline wait"
;;

let with_nops (certified : Certified.t) ~wait_pc k =
  let program, lines =
    match Asm.assemble_with_lines certified.source with
    | Ok assembled -> assembled
    | Error _ -> raise_s [%message "BUG: certified firmware does not assemble"]
  in
  let side =
    match List.nth_exn program.instructions wait_pc with
    | Op { op = Wait (Deadline _); side_set; _ } -> side_set
    | _ -> raise_s [%message "BUG: not a deadline wait" (wait_pc : int)]
  in
  let line = List.nth_exn lines wait_pc in
  let added = nops ~side_set_count:program.side_set_count ~side k in
  List.concat_mapi (String.split certified.source ~on:'\n') ~f:(fun i text ->
    if i + 1 <> line
    then [ text ]
    else (
      (* a label on the wait's line would leave the nops behind the jumps to it *)
      let code = List.hd_exn (String.split text ~on:';') in
      if String.mem code ':'
      then
        raise_s
          [%message
            "a label on the wait's line" (certified.name : string) (text : string)];
      added @ [ text ]))
  |> String.concat ~sep:"\n"
;;

let variant t k =
  check
    t.swept
    t.certified
    ~edges:t.edges
    k
    ~source:(with_nops t.certified ~wait_pc:t.wait_pc k)
;;

let of_swept (swept : Swept.t) =
  let certified = Library.find_certified_exn swept.name in
  let slack, wait_pc = tightest swept certified in
  let edges =
    let program, config = assembled swept certified certified.source in
    fst (ran swept ~config ~words:(Asm.Program.words program |> ok_exn))
  in
  { swept; certified; wait_pc; slack; edges }
;;

let every t = List.init (t.slack + 4) ~f:(variant t)
