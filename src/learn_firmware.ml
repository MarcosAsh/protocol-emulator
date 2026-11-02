open! Core

module Pins = struct
  type t =
    | Line of int
    | Clocked of
        { clock : int
        ; data : int
        ; deselect : bool
        }
  [@@deriving sexp_of]
end

type t =
  { source : string
  ; period : int
  ; ticks : int
  ; timed : Timed_program.t
  }

(* Source written a line at a time, with fresh labels. *)
module Writer = struct
  type t =
    { lines : string Queue.t
    ; mutable labels : int
    }

  let create () = { lines = Queue.create (); labels = 0 }
  let line t s = Queue.enqueue t.lines ("    " ^ s)
  let comment t s = Queue.enqueue t.lines ("; " ^ s)
  let label t name = Queue.enqueue t.lines (name ^ ":")

  let fresh t name =
    t.labels <- t.labels + 1;
    sprintf "%s%d" name t.labels
  ;;

  (* [reg] to [n]: the top five bits by [set], then a doubling and maybe an add a bit. *)
  let load t reg n =
    let bits = Int.max 5 (Int.ceil_log2 (n + 1)) in
    line t (sprintf "set %s, %d" reg (n lsr (bits - 5)));
    for i = bits - 6 downto 0 do
      line t (sprintf "add %s, %s" reg reg);
      if (n lsr i) land 1 = 1 then line t (sprintf "add %s, 1" reg)
    done
  ;;

  (* [n] more deadlines with the pins held: inline, an [x] loop, or [y] round it, which
     only runs outside a frame's bits where [y] is free. *)
  let waits t n ~y_free =
    if n <= 3
    then
      for _ = 1 to n do
        line t "wait t+"
      done
    else if n <= 32
    then (
      let l = fresh t "hold" in
      line t (sprintf "set x, %d" (n - 1));
      label t l;
      line t "wait t+";
      line t (sprintf "jmp x--, %s" l))
    else if y_free && n <= 1024
    then (
      let outer = n / 32 in
      let rest = n - (outer * 32) in
      let o = fresh t "outer" in
      let i = fresh t "inner" in
      line t (sprintf "set y, %d" (outer - 1));
      label t o;
      line t "set x, 31";
      label t i;
      line t "wait t+";
      line t (sprintf "jmp x--, %s" i);
      line t (sprintf "jmp y--, %s" o);
      if rest > 0
      then (
        let r = fresh t "rest" in
        line t (sprintf "set x, %d" (rest - 1));
        label t r;
        line t "wait t+";
        line t (sprintf "jmp x--, %s" r)))
    else raise_s [%message "a run too long for the firmware" (n : int)]
  ;;

  let to_string t = String.concat_lines (Queue.to_list t.lines)
end

let level_value b = Bool.to_int b

let config_of ~pins (learned : Learn.t) =
  let base =
    { Program_config.default with
      out_shift = Right
    ; pull_threshold = 16
    ; autopull = false
    ; out_count = 1
    }
  in
  match pins, learned.coding with
  | Pins.Line pin, (Pulse _ | Manchester _ | Uart _) ->
    Ok { base with set_base = pin; set_count = 1; out_base = pin }
  | Clocked { clock; data; deselect }, Clocked _ ->
    Ok
      { base with
        set_base = clock
      ; set_count = (if deselect then 2 else 1)
      ; out_base = data
      }
  | _ -> Or_error.error_s [%message "the pins do not suit the coding" (pins : Pins.t)]
;;

let source ~ticks ~deselect (learned : Learn.t) =
  let w = Writer.create () in
  let active = not learned.idle in
  let set level = Writer.line w (sprintf "set pins, %d" (level_value level)) in
  let set_clock level =
    Writer.line w (sprintf "set pins, %d" (level_value level + if deselect then 2 else 0))
  in
  (* a run: its level at a deadline, held [units] *)
  let run ~y_free level units =
    Writer.line w "wait t+";
    set level;
    Writer.waits w ((units * ticks) - 1) ~y_free
  in
  let runs ~y_free l =
    List.iter l ~f:(fun (r : Learn.Run.t) ->
      run ~y_free (Bool.equal r.active active) r.units)
  in
  let next_bit ~loop =
    let have = Writer.fresh w "have" in
    Writer.label w loop;
    Writer.line w (sprintf "jmp !osre, %s" have);
    Writer.line w "pull";
    Writer.label w have
  in
  Writer.comment
    w
    (sprintf
       "learned from a recording, unit %.2f us, %d ticks of the period a unit"
       (learned.unit_s *. 1e6)
       ticks);
  (match learned.coding with
   | Clocked { clock_idle; _ } -> set_clock clock_idle
   | _ -> set learned.idle);
  Writer.line w "wait tx";
  Writer.line w "pull";
  Writer.line w "mov p, osr               ; the period";
  Writer.label w "frame";
  Writer.line w "wait tx";
  let kinds = List.length learned.kinds in
  let kind_label i = sprintf "kind%d" i in
  if kinds > 1
  then (
    Writer.line w "pull";
    Writer.line w "mov x, osr               ; the kind";
    List.iteri learned.kinds ~f:(fun i _ ->
      if i < kinds - 1
      then (
        let not_this = Writer.fresh w "not" in
        Writer.line w (sprintf "jmp x--, %s" not_this);
        Writer.line w (sprintf "jmp %s" (kind_label i));
        Writer.label w not_this)
      else Writer.line w (sprintf "jmp %s" (kind_label i))));
  List.iteri learned.kinds ~f:(fun i (kind : Learn.Kind.t) ->
    Writer.label w (kind_label i);
    if kind.bits > 0
    then (
      if kinds > 1 then Writer.line w "wait tx";
      Writer.line w "pull                     ; the first word");
    Writer.line w "mov t, now";
    Writer.line w "add t, p";
    runs ~y_free:true kind.leader;
    let bit_loop ~count ~zero ~one =
      if count > 0
      then (
        Writer.load w "y" (count - 1);
        let loop = Writer.fresh w "bit" in
        let one_label = Writer.fresh w "one" in
        let after = Writer.fresh w "after" in
        next_bit ~loop;
        Writer.line w "out x, 1";
        Writer.line w (sprintf "jmp x--, %s" one_label);
        zero ();
        Writer.line w (sprintf "jmp y--, %s" loop);
        Writer.line w (sprintf "jmp %s" after);
        Writer.label w one_label;
        one ();
        Writer.line w (sprintf "jmp y--, %s" loop);
        Writer.label w after)
    in
    (match learned.coding with
     | Pulse { zero = m0, s0; one = m1, s1; _ } ->
       bit_loop
         ~count:kind.bits
         ~zero:(fun () ->
           run ~y_free:false active m0;
           run ~y_free:false learned.idle s0)
         ~one:(fun () ->
           run ~y_free:false active m1;
           run ~y_free:false learned.idle s1)
     | Manchester { one_starts_active; wide; _ } ->
       let segments =
         match wide with
         | Some j when j < kind.bits -> [ j, 1; 1, 2; kind.bits - j - 1, 1 ]
         | _ -> [ kind.bits, 1 ]
       in
       List.iter segments ~f:(fun (count, width) ->
         let halves value =
           (* the first half is active for a one that starts so *)
           let first = Bool.equal value one_starts_active in
           let level a = if a then active else learned.idle in
           run ~y_free:false (level first) width;
           run ~y_free:false (level (not first)) width
         in
         bit_loop ~count ~zero:(fun () -> halves false) ~one:(fun () -> halves true))
     | Uart { data_bits; parity; stop_bits } ->
       let chars = kind.bits / data_bits in
       let per_char = data_bits + Bool.to_int (Option.is_some parity) in
       Writer.load w "y" (chars - 1);
       let char = Writer.fresh w "char" in
       let bits = Writer.fresh w "bits" in
       let next = Writer.fresh w "next" in
       let after = Writer.fresh w "after" in
       Writer.label w char;
       run ~y_free:false active 1;
       Writer.line w (sprintf "set x, %d" (per_char - 1));
       Writer.label w bits;
       Writer.line w "wait t+";
       Writer.line w "out pins, 1";
       Writer.waits w (ticks - 1) ~y_free:false;
       Writer.line w (sprintf "jmp x--, %s" bits);
       run ~y_free:false learned.idle stop_bits;
       Writer.line w (sprintf "jmp y--, %s" next);
       Writer.line w (sprintf "jmp %s" after);
       Writer.label w next;
       Writer.line w "pull";
       Writer.line w (sprintf "jmp %s" char);
       Writer.label w after
     | Clocked { sample_rising; clock_idle; _ } ->
       Writer.load w "y" (kind.bits - 1);
       let loop = Writer.fresh w "bit" in
       next_bit ~loop;
       Writer.line w "wait t+";
       set_clock (not sample_rising);
       Writer.line w "out pins, 1";
       Writer.waits w (ticks - 1) ~y_free:false;
       Writer.line w "wait t+";
       set_clock sample_rising;
       Writer.waits w (ticks - 1) ~y_free:false;
       Writer.line w (sprintf "jmp y--, %s" loop);
       Writer.line w "wait t+";
       set_clock clock_idle;
       Writer.line w (sprintf "set x, %d" (level_value learned.idle));
       Writer.line w "mov pins, x");
    runs ~y_free:true kind.trailer;
    (* the gap, idle *)
    Writer.line w "wait t+";
    (match learned.coding with
     | Clocked _ -> ()
     | _ -> set learned.idle);
    Writer.waits w ((Int.max learned.gap 4 * ticks) - 1) ~y_free:true;
    Writer.line w "jmp frame");
  Writer.to_string w
;;

let generate ~clock_hz ~pins (learned : Learn.t) =
  let%bind.Or_error config = config_of ~pins learned in
  let cycles = learned.unit_s *. clock_hz in
  let ticks = Float.iround_up_exn (cycles /. 65535.) in
  let period = Float.iround_nearest_exn (cycles /. Float.of_int ticks) in
  let deselect =
    match pins with
    | Clocked { deselect; _ } -> deselect
    | Line _ -> false
  in
  let%bind.Or_error source =
    Or_error.try_with (fun () -> source ~ticks ~deselect learned)
  in
  match Timed_program.check ~period ~config source with
  | Ok timed -> Ok { source; period; ticks; timed }
  | Error refusal ->
    Or_error.error_s
      [%message "the kernel refused the firmware" ~_:(refusal.error : Error.t) source]
;;

let pack bits =
  List.chunks_of (Array.to_list bits) ~length:16
  |> List.map ~f:(fun chunk ->
    List.foldi chunk ~init:0 ~f:(fun i acc b -> if b then acc lor (1 lsl i) else acc))
;;

let words _t (learned : Learn.t) ~kind bits =
  let kind_word = if List.length learned.kinds > 1 then [ kind ] else [] in
  let data =
    match learned.coding with
    | Uart { data_bits; parity; _ } ->
      let bits = Learn.with_checks learned ~kind bits in
      List.chunks_of (Array.to_list bits) ~length:data_bits
      |> List.map ~f:(fun data ->
        let parity =
          match parity with
          | None -> []
          | Some Even -> [ List.count data ~f:Fn.id % 2 = 1 ]
          | Some Odd -> [ List.count data ~f:Fn.id % 2 = 0 ]
        in
        (* the levels sent: a 1 is the idle level *)
        List.map (data @ parity) ~f:(fun b -> Bool.equal b learned.idle)
        |> List.foldi ~init:0 ~f:(fun i acc b -> if b then acc lor (1 lsl i) else acc))
    | Pulse _ | Manchester _ | Clocked _ -> pack (Learn.with_checks learned ~kind bits)
  in
  kind_word @ data
;;

let simulate ~clock_hz ~pins t (learned : Learn.t) frames =
  let%bind.Or_error machine =
    Machine.create
      ~config:(Timed_program.config t.timed)
      ~program:(Timed_program.words t.timed)
  in
  let words =
    t.period :: List.concat_map frames ~f:(fun (kind, bits) -> words t learned ~kind bits)
  in
  let watched =
    match pins, learned.coding with
    | Pins.Line pin, _ -> [ learned.line, pin ]
    | Clocked { clock; data; _ }, Clocked { clock = name; _ } ->
      [ name, clock; learned.line, data ]
    | Clocked _, _ -> []
  in
  let units_of (kind, bits) =
    match learned.coding with
    | Clocked _ -> (2 * Array.length bits) + 8
    | _ -> List.sum (module Int) (Learn.runs learned ~kind bits) ~f:(fun r -> r.units)
  in
  let cycles =
    (List.sum (module Int) frames ~f:(fun f -> units_of f + Int.max learned.gap 4 + 4)
     * t.ticks
     * t.period)
    + 1000
  in
  let edges = List.map watched ~f:(fun _ -> Queue.create ()) in
  let level machine pin = (Machine.pins machine ~inputs:0 lsr pin) land 1 = 1 in
  let first = List.map watched ~f:(fun (_, pin) -> level machine pin) in
  let rec go machine words cycle last =
    if cycle >= cycles
    then Ok ()
    else if not (Machine.Fault.equal machine.Machine.fault Machine.Fault.none)
    then
      Or_error.error_s
        [%message "the model faulted" (cycle : int) (machine.fault : Machine.Fault.t)]
    else (
      let machine, words =
        match words with
        | w :: rest when List.length machine.Machine.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx machine w |> Or_error.ok_exn, rest
        | _ -> machine, words
      in
      let machine = Machine.step machine ~inputs:0 in
      let now = List.map watched ~f:(fun (_, pin) -> level machine pin) in
      List.iter2_exn (List.zip_exn now last) edges ~f:(fun (a, b) q ->
        if Bool.( <> ) a b then Queue.enqueue q (cycle + 1));
      go machine words (cycle + 1) now)
  in
  let%map.Or_error () = go machine words 0 first in
  (* the levels once the firmware has set them, before any frame's first deadline *)
  let settle = 8 in
  let lines =
    List.map3_exn watched first edges ~f:(fun (name, _) first q ->
      let edges = Queue.to_list q in
      let early, late = List.partition_tf edges ~f:(fun e -> e <= settle) in
      let first = Bool.( <> ) first (List.length early % 2 = 1) in
      { Recording.Line.name; first; edges = Array.of_list late })
  in
  { Recording.rate_hz = clock_hz; length = cycles + 1; lines; notes = [] }
;;
