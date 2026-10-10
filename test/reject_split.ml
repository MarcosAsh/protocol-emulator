open! Core
open Protocol_emulator

module Variant = struct
  type t =
    { name : string
    ; firmware : Certified.t
    ; config : Program_config.t
    ; words : int list
    }
end

let firmware =
  List.filter Library.certified ~f:(fun (c : Certified.t) ->
    not (c.single_capture_edge || c.any_data))
;;

let variants (firmware : Certified.t) =
  let program = Asm.assemble firmware.source |> ok_exn in
  let config = Asm.Program.configure program firmware.config in
  let words = Asm.Program.words program |> ok_exn in
  let length = List.length words in
  List.concat_mapi words ~f:(fun pc word ->
    let instruction = Isa.of_word ~side_set_count:config.side_set_count word |> ok_exn in
    let changed =
      match instruction with
      | Jmp { cond; target } ->
        List.filter_map
          [ target - 1; target + 1 ]
          ~f:(fun target ->
            Option.some_if
              (target >= 0 && target < length)
              ([%string "jmp %{target#Int}"], Isa.Jmp { cond; target }))
      | Op { op; delay; side_set } ->
        List.init (1 lsl Isa.Field.delay_side.width) ~f:Fn.id
        |> List.filter_map ~f:(fun d ->
          Option.some_if
            (d <> delay)
            ([%string "delay %{d#Int}"], Isa.Op { op; delay = d; side_set }))
    in
    List.filter_map changed ~f:(fun (change, instruction) ->
      match Isa.to_word ~side_set_count:config.side_set_count instruction with
      | Error _ -> None
      | Ok changed ->
        Some
          { Variant.name = [%string "%{firmware.name} pc %{pc#Int} %{change}"]
          ; firmware
          ; config
          ; words = List.mapi words ~f:(fun i w -> if i = pc then changed else w)
          }))
;;

module Verdict = struct
  type t =
    | Accepted
    | Missed
    | Analyser_limit
    | No_table
    | Accepted_but_missed
    | Witness_refused
  [@@deriving sexp_of, compare, equal, enumerate]
end

let accepted (v : Variant.t) =
  let { Certified.period; single_capture_edge; _ } = v.firmware in
  let instructions =
    List.map v.words ~f:(fun word ->
      Isa.of_word ~side_set_count:v.config.side_set_count word |> ok_exn)
  in
  let rows =
    Analyser.analyse ?period ~single_capture_edge ~config:v.config instructions
  in
  Kernel.check
    ?period
    ~single_capture_edge
    ~config:v.config
    ~words:v.words
    (Kernel.Table.of_analyser rows)
  |> Result.is_ok
;;

let loads_p = function
  | Isa.Op { op = Mov { dest = P; _ } | Out { dest = P; _ } | Alu { dest = P; _ }; _ } ->
    true
  | Jmp _ | Op _ -> false
;;

(* One run, cut before the first load of [p] that breaks the period premise. Firmware with
   no period gets odd-seed hosts. *)
let run ?(random_host = false) (v : Variant.t) ~cycles ~seed =
  let random = Splittable_random.of_int seed in
  let int hi = Splittable_random.int random ~lo:0 ~hi in
  let program = Array.of_list v.words in
  let instruction pc =
    Isa.of_word
      ~side_set_count:v.config.side_set_count
      (if pc < Array.length program then program.(pc) else 0)
    |> ok_exn
  in
  let period = if random_host then None else v.firmware.period in
  let host_word () =
    match period with
    | Some period when seed % 2 = 0 -> period
    | Some _ | None ->
      if seed % 4 = 3 then if int 1 = 0 then int 7 else 0xffff else int 0xffff
  in
  let rec loop (m : Machine.t) cycle =
    if cycle = cycles
    then m.fault.missed_deadline, cycle
    else (
      let m =
        if int 3 = 0 && List.length m.tx_fifo < Machine.fifo_depth
        then Machine.write_tx m (host_word ()) |> ok_exn
        else m
      in
      let m =
        if int 3 = 0
        then (
          match Machine.read_rx m with
          | Some (_, m) -> m
          | None -> m)
        else m
      in
      let after = Machine.step m ~inputs:(int ((1 lsl Isa.pin_space) - 1)) in
      let issued = (not m.halted) && m.stall = 0 in
      match period with
      | Some period when issued && loads_p (instruction m.pc) && after.p <> period ->
        m.fault.missed_deadline, cycle
      | _ -> loop after (cycle + 1))
  in
  let m = Machine.create ~config:v.config ~program:v.words |> ok_exn in
  let m =
    Option.value_map period ~default:m ~f:(fun period ->
      Machine.write_tx m period |> ok_exn)
  in
  loop m 0
;;

let classify ?random_host ?(runs = 4) ?(cycles = 20_000) (v : Variant.t) =
  let results = List.init runs ~f:(fun seed -> run ?random_host v ~cycles ~seed) in
  let missed = List.exists results ~f:fst in
  let ran = List.sum (module Int) results ~f:snd in
  let verdict : Verdict.t =
    match accepted v, missed with
    | true, false -> Accepted
    | true, true -> Accepted_but_missed
    | false, true -> Missed
    | false, false ->
      let { Certified.period; single_capture_edge; _ } = v.firmware in
      (match
         Table_query.witness
           ?period
           ~single_capture_edge
           ~config:v.config
           ~words:v.words
           ()
       with
       | None -> No_table
       | Some table ->
         (match
            Kernel.check
              ?period
              ~single_capture_edge
              ~config:v.config
              ~words:v.words
              table
          with
          | Ok () -> Analyser_limit
          | Error _ -> Witness_refused))
  in
  verdict, `Cycles ran
;;

let print_split ?runs ?cycles variants =
  let verdicts =
    List.map variants ~f:(fun (v : Variant.t) -> v, classify ?runs ?cycles v)
  in
  List.iter Verdict.all ~f:(fun verdict ->
    let count = List.count verdicts ~f:(fun (_, (v, _)) -> Verdict.equal v verdict) in
    print_s [%message (verdict : Verdict.t) (count : int)]);
  List.iter verdicts ~f:(fun (v, (verdict, `Cycles cycles)) ->
    match verdict with
    | Accepted | Missed -> ()
    | Analyser_limit | No_table | Accepted_but_missed | Witness_refused ->
      print_s [%message v.name (verdict : Verdict.t) (cycles : int)])
;;
