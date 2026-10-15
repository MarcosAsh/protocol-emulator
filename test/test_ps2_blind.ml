open! Core
open Protocol_emulator
open Ps2_blind

(* The system end of IBM's Figure 8: it reads a bit on each fall of the clock, checks the
   start, odd parity and stop of each eleven, and times T1 to T5 against the table. It
   holds the clock low over [inhibit], and [after_frame] past each 11th clock, as a PC
   does to take the byte. *)
module Host = struct
  type t =
    { clock_hz : int
    ; inhibit : (int * int) list (* from, until, in cycles *)
    ; after_frame : (int * int) option (* from the 11th clock's rise, and for how long *)
    ; now : int
    ; clock : bool
    ; data : bool
    ; held : bool
    ; clock_edge : int
    ; data_edge : int option (* since the clock last rose *)
    ; bits : bool list (* this frame's, last first *)
    ; eleventh : int option (* when the last frame's 11th clock rose *)
    ; held_since : int option
    ; bytes : int list
    ; log : string list
    ; measured : Measured.t
    ; violations : string list
    }

  let create ?(inhibit = []) ?after_frame ~clock_hz () =
    { clock_hz
    ; inhibit
    ; after_frame
    ; now = 0
    ; clock = true
    ; data = true
    ; held = false
    ; clock_edge = 0
    ; data_edge = None
    ; bits = []
    ; eleventh = None
    ; held_since = None
    ; bytes = []
    ; log = []
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let us = 1_000

  let holds_clock t =
    List.exists t.inhibit ~f:(fun (from, until) -> from <= t.now && t.now < until)
    || Option.exists t.after_frame ~f:(fun (after, hold) ->
      Option.exists t.eleventh ~f:(fun rose ->
        rose + after <= t.now && t.now < rose + after + hold))
  ;;

  let ns t cycles = cycles * 1_000_000_000 / t.clock_hz
  let log_line t line = { t with log = line :: t.log }

  let checked t ~name ~ns ~lo ~hi =
    let t = { t with measured = Measured.add t.measured ~name ~ns } in
    if ns >= lo && ns <= hi
    then t
    else { t with violations = [%string "%{name} of %{ns#Int} ns"] :: t.violations }
  ;;

  let byte bits =
    List.foldi bits ~init:0 ~f:(fun i byte bit -> byte lor (Bool.to_int bit lsl i))
  ;;

  (* the frame, first bit first: start, eight data bits LSB first, parity, stop *)
  let frame t bits =
    match bits with
    | [ start; b0; b1; b2; b3; b4; b5; b6; b7; parity; stop ] ->
      let data = [ b0; b1; b2; b3; b4; b5; b6; b7 ] in
      let ones = List.count (parity :: data) ~f:Fn.id in
      let byte = byte data in
      let t =
        if start || (not stop) || ones % 2 = 0
        then
          { t with
            violations =
              [%string
                "frame 0x%{byte#Int.Hex}: start %{start#Bool}, parity ones %{ones#Int}, \
                 stop %{stop#Bool}"]
              :: t.violations
          }
        else t
      in
      log_line { t with bytes = byte :: t.bytes } (sprintf "byte 0x%02x" byte)
    | _ -> raise_s [%message "BUG: a frame is eleven bits"]
  ;;

  (* the clock falls: the host reads the data *)
  let fell t =
    let t =
      match t.bits, t.data_edge with
      | [], _ -> t
      | _ :: _, edge ->
        let t =
          checked
            t
            ~name:"T4"
            ~ns:(ns t (t.now - t.clock_edge))
            ~lo:(30 * us)
            ~hi:(50 * us)
        in
        Option.value_map edge ~default:t ~f:(fun edge ->
          checked t ~name:"T1" ~ns:(ns t (t.now - edge)) ~lo:(5 * us) ~hi:(25 * us))
    in
    let t =
      match t.bits, t.data_edge with
      | [], Some edge ->
        checked t ~name:"T1" ~ns:(ns t (t.now - edge)) ~lo:(5 * us) ~hi:(25 * us)
      | _ -> t
    in
    let bits = t.data :: t.bits in
    if List.length bits = 11
    then frame { t with bits } (List.rev bits)
    else { t with bits }
  ;;

  let rose t =
    let t =
      checked t ~name:"T3" ~ns:(ns t (t.now - t.clock_edge)) ~lo:(30 * us) ~hi:(50 * us)
    in
    if List.length t.bits = 11 then { t with bits = []; eleventh = Some t.now } else t
  ;;

  (* the data moves while the clock is high: T2 from its rise, and a start bit at least T5
     after the last frame's 11th clock *)
  let data_moved t =
    let t = { t with data_edge = Some t.now } in
    if not t.clock
    then { t with violations = "data moved while the clock was low" :: t.violations }
    else if List.is_empty t.bits && not t.data
    then (
      let t =
        checked
          t
          ~name:"clock high before a start"
          ~ns:(ns t (t.now - t.clock_edge))
          ~lo:(50 * us)
          ~hi:Int.max_value
      in
      Option.value_map t.eleventh ~default:t ~f:(fun eleventh ->
        checked t ~name:"T5" ~ns:(ns t (t.now - eleventh)) ~lo:(50 * us) ~hi:Int.max_value))
    else if List.is_empty t.bits
    then t
    else checked t ~name:"T2" ~ns:(ns t (t.now - t.clock_edge)) ~lo:(5 * us) ~hi:(45 * us)
  ;;

  (* the host takes the clock: a frame before its 11th clock is dropped, and the device
     has to let the data go *)
  let took t =
    let t = { t with held_since = Some t.now } in
    match List.length t.bits with
    | 0 | 11 -> t
    | n -> log_line { t with bits = [] } [%string "inhibited after %{n#Int} clocks"]
  ;;

  (* the lines after an edge, the device's open drains and the host's *)
  let step t ~clock ~data =
    let held = holds_clock t in
    let t =
      match t.held, held with
      | false, true -> took t
      | true, false -> { t with held_since = None }
      | _ -> t
    in
    let t =
      if Bool.equal data t.data
      then t
      else (
        let t = { t with data } in
        match t.held_since with
        | Some since when data ->
          checked
            t
            ~name:"data let go after an inhibit"
            ~ns:(ns t (t.now - since))
            ~lo:0
            ~hi:(100 * us)
        | Some _ -> { t with violations = "data pulled while inhibited" :: t.violations }
        | None -> data_moved { t with data })
    in
    let t =
      if Bool.equal clock t.clock
      then t
      else (
        let t =
          match t.held, held with
          | false, false -> if clock then rose t else fell t
          | _ -> t
        in
        { t with clock; clock_edge = t.now; data_edge = None })
    in
    { t with held; now = t.now + 1 }
  ;;

  let bytes t = List.rev t.bytes
  let log t = List.rev t.log
  let measured t = t.measured
  let violations t = List.rev t.violations
end

let released (m : Machine.t) pin = (m.pin_dir lsr pin) land 1 = 0

(* the lines as both ends leave them *)
let inputs (m : Machine.t) host =
  let clock_high = released m clock && not (Host.holds_clock host) in
  (Bool.to_int (released m data) lsl data) lor (Bool.to_int clock_high lsl clock)
;;

let run ?inhibit ?after_frame ~unit ~cycles bytes =
  let words = unit :: List.map bytes ~f:word in
  let host = Host.create ?inhibit ?after_frame ~clock_hz:Bench.clock_hz () in
  let rec loop (m : Machine.t) host pending n =
    if n = 0
    then m, host
    else (
      let m, pending =
        match pending with
        | w :: rest when List.length m.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx m w |> ok_exn, rest
        | pending -> m, pending
      in
      let m = Machine.step m ~inputs:(inputs m host) in
      let lines = inputs m host in
      let host =
        Host.step
          host
          ~clock:((lines lsr clock) land 1 = 1)
          ~data:((lines lsr data) land 1 = 1)
      in
      loop m host pending (n - 1))
  in
  let m =
    Machine.create
      ~config:(Timed_program.config firmware)
      ~program:(Timed_program.words firmware)
    |> ok_exn
  in
  let m, host = loop m host words cycles in
  print_s
    [%message
      ""
        ~bytes:(List.map (Host.bytes host) ~f:(sprintf "%02x") : string list)
        ~matches:(List.equal Int.equal (Host.bytes host) bytes : bool)
        ~log:(Host.log host : string list)
        ~measured_ns:(Host.measured host : Measured.t)
        ~violations:(Host.violations host : string list)
        ~fault:(m.fault : Machine.Fault.t)]
;;

(* 48 MHz, a unit of 20 us *)
let unit = Bench.cycles_in ~us:20

(* the Q key's make and break codes, as in Chapweske's figure 3 *)
let q = [ 0x15; 0xf0; 0x15 ]

let%expect_test "host words" =
  print_s [%message (List.map q ~f:(fun b -> sprintf "%03x" (word b)) : string list)];
  [%expect {| ("List.map q ~f:(fun b -> sprintf \"%03x\" (word b))" (015 1f0 015)) |}]
;;

let%expect_test "three frames, back to back" =
  run ~unit ~cycles:200_000 q;
  [%expect
    {|
    ((bytes (15 f0 15)) (matches true)
     (log ("byte 0x15" "byte 0xf0" "byte 0x15"))
     (measured_ns
      (("clock high before a start" (60458 80479)) (T1 (19895 19916))
       (T3 (40000 40000)) (T2 (20083 20083)) (T4 (40000 40000))
       (T5 (80479 80479))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "a PC holds the clock low after each frame to take it" =
  run
    ~unit
    ~cycles:200_000
    ~after_frame:(Bench.cycles_in ~us:10, Bench.cycles_in ~us:150)
    q;
  [%expect
    {|
    ((bytes (15 f0 15)) (matches true)
     (log ("byte 0x15" "byte 0xf0" "byte 0x15"))
     (measured_ns
      (("clock high before a start" (60145 60458)) (T1 (19895 19916))
       (T3 (40000 40000)) (T2 (20083 20083)) (T4 (40000 40000))
       (T5 (220145 220145))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* held low from the 5th clock of the first frame: the frame comes again whole once the
   clock is let go *)
let%expect_test "an inhibit mid frame sends the frame again" =
  let fifth = (5 * unit) + (4 * unit * 4) in
  run ~unit ~cycles:240_000 ~inhibit:[ fifth, fifth + Bench.cycles_in ~us:200 ] q;
  [%expect
    {|
    ((bytes (15 f0 15)) (matches true)
     (log ("inhibited after 5 clocks" "byte 0x15" "byte 0xf0" "byte 0x15"))
     (measured_ns
      (("clock high before a start" (60145 80479)) (T1 (19895 19916))
       (T3 (40000 40000)) (T2 (20083 20083)) (T4 (40000 40000))
       ("data let go after an inhibit" (40437 40437)) (T5 (80479 80479))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "the clock held low before a frame holds it back" =
  run ~unit ~cycles:240_000 ~inhibit:[ 0, Bench.cycles_in ~us:500 ] q;
  [%expect
    {|
    ((bytes (15 f0 15)) (matches true)
     (log ("byte 0x15" "byte 0xf0" "byte 0x15"))
     (measured_ns
      (("clock high before a start" (60145 80479)) (T1 (19895 19916))
       (T3 (40000 40000)) (T2 (20083 20083)) (T4 (40000 40000))
       (T5 (80479 80479))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "every edge and every sample is placed by a deadline" =
  Timing_report.print ~config ~period:unit (Timed_program.source firmware);
  [%expect
    {|
      3  set pins, 0                  phase ?..?  edge ?..?  jitter ?  gap ?..?
      4  mov pins, null               phase ?..?  edge ?..?  jitter ?  gap 1
      8  mov pindirs, null            phase ?..?  edge ?..?  jitter ?  gap 964 from 33, 969..? from 20, 4..? from 7
     23  out pindirs, 1               phase -955..-954  edge -954..-953  jitter 1  gap 964 from 31, 972..? from 22
     25  set pindirs, 1               phase -959  edge -958  gap 955..956
     28  set pindirs, 0               phase -959  edge -958  gap 1920
    ((words 35) (edge_jitter unbounded) (sample_jitter 0) (side_jitter 0)
     (may_miss 0))
    |}]
;;

let%expect_test "the shortest unit the program keeps up with" =
  Timing_report.print ~config ~period:8 (Timed_program.source firmware);
  [%expect
    {|
      3  set pins, 0                  phase ?..?  edge ?..?  jitter ?  gap ?..?
      4  mov pins, null               phase ?..?  edge ?..?  jitter ?  gap 1
      8  mov pindirs, null            phase ?..?  edge ?..?  jitter ?  gap 12 from 33, 17..? from 20, 4..? from 7
     23  out pindirs, 1               phase -3..-2  edge -2..-1  jitter 1  gap 12 from 31, 20..? from 22
     25  set pindirs, 1               phase -7  edge -6  gap 3..4
     28  set pindirs, 0               phase -7  edge -6  gap 16
    ((words 35) (edge_jitter unbounded) (sample_jitter 0) (side_jitter 0)
     (may_miss 0))
    |}]
;;
