open! Core
open Protocol_emulator
open Dali

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Dali.firmware));
  [%expect {| 34 words, 8 deadline waits, worst slack 1 |}]
;;

(* 100 cycles a half bit, as a 240 kHz clock gives: a query and its answer, then a forward
   frame of all ones and a backward frame of all zeros *)
let clock_hz = trace_clock_hz
let unit = trace_half_bit

let frames =
  [ query; answer; Frame.Forward { address = 0xff; opcode = 0xff }; Frame.Backward 0x00 ]
;;

let host_words = unit :: List.concat_map frames ~f:words
let cycles = (4 * 62 * unit) + 100
let line (m : Machine.t) = (m.pin_out lsr pin) land 1 = 1

let print_read levels =
  match read ~clock_hz levels with
  | Ok (reads, measured) ->
    let read = List.map reads ~f:(fun r -> r.frame) in
    print_s
      [%message
        ""
          (read : Frame.t list)
          ~as_sent:([%equal: Frame.t list] read frames : bool)
          ~forward_starts_apart:(gaps (forward_starts reads) : int list)
          ~measured_ns:(measured : Measured.t)]
  | Error error -> print_s [%message "refused" (error : Error.t)]
;;

(* the firmware on the model, the host writing each word once the fifo has room *)
let tx_levels source =
  let machine =
    Machine.create
      ~config:(Timed_program.config firmware)
      ~program:(Firmware.assemble source)
    |> ok_exn
  in
  List.folding_map
    (List.range 0 cycles)
    ~init:(machine, host_words)
    ~f:(fun (machine, pending) _ ->
      let machine, pending =
        match pending with
        | w :: rest when List.length machine.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx machine w |> ok_exn, rest
        | pending -> machine, pending
      in
      let machine = Machine.step machine ~inputs:0 in
      (machine, pending), line machine)
;;

let runs levels =
  List.group levels ~break:Bool.( <> )
  |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
;;

let%expect_test "the far end reads every frame, each half bit and idle measured" =
  let levels = runs (tx_levels (Timed_program.source firmware)) in
  print_s [%message (levels : (bool * int) list)];
  print_read levels;
  [%expect
    {|
    (levels
     ((true 110) (false 100) (true 200) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 100) (false 200) (true 100) (false 100) (true 100) (false 100)
      (true 200) (false 200) (true 200) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 2710) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 200) (false 100)
      (true 2710) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 2810) (false 100)
      (true 200) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 100) (false 100)
      (true 100) (false 100) (true 100) (false 100) (true 6260)))
    ((read
      ((Forward (address 3) (opcode 160)) (Backward 254)
       (Forward (address 255) (opcode 255)) (Backward 0)))
     (as_sent true) (forward_starts_apart (10620))
     (measured_ns
      (("half bit" (416667 416667)) ("2 half bits" (833333 833333))
       (idle (11291667 11291667)))))
    |}]
;;

(* Four half bits of idle, 1.7 ms, are short of 2.45 ms. *)
let%expect_test "the far end refuses an idle short of 2.45 ms" =
  let source =
    Bench.patch
      (Timed_program.source firmware)
      ~pattern:"set x, 25\nidle:"
      ~with_:"set x, 2\nidle:"
  in
  print_read (runs (tx_levels source));
  [%expect {| (refused (error ("idle too short" (ns 1708333)))) |}]
;;

(* A zero whose second half stays high: three half bits high end the frame early. *)
let%expect_test "the far end refuses a bit with no edge in its middle" =
  let source =
    Bench.patch
      (Timed_program.source firmware)
      ~pattern:
        "set pins, 1              ; a zero: high, then low\n    wait t+\n    set pins, 0"
      ~with_:
        "set pins, 1              ; a zero: high, then low\n    wait t+\n    set pins, 1"
  in
  print_read (runs (tx_levels source));
  [%expect {| (refused (error ("a frame of neither 8 nor 16 bits" (n 0)))) |}]
;;

let%expect_test "dali in lockstep" =
  let levels = ref [] in
  let pending = ref host_words in
  let room = ref Machine.fifo_depth in
  let model =
    Lockstep.lockstep
      ~cycles
      ~config:(Timed_program.config firmware)
      ~program:(Timed_program.words firmware)
      ~inputs:(fun _ -> 0)
      ~host:(fun _ ->
        let tx =
          match !pending with
          | w :: rest when !room > 0 ->
            pending := rest;
            Some w
          | _ -> None
        in
        { Lockstep.Host.idle with tx })
      ~react:(fun m ->
        room := Machine.fifo_depth - List.length m.tx_fifo;
        levels := line m :: !levels)
      ()
  in
  print_s [%message "" ~fault:(model.fault : Machine.Fault.t)];
  print_read (runs (List.rev !levels));
  [%expect
    {|
    ("lockstep held" (cycles 24900))
    (fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    ((read
      ((Forward (address 3) (opcode 160)) (Backward 254)
       (Forward (address 255) (opcode 255)) (Backward 0)))
     (as_sent true) (forward_starts_apart (10620))
     (measured_ns
      (("half bit" (416667 416667)) ("2 half bits" (833333 833333))
       (idle (11291667 11291667)))))
    |}]
;;
