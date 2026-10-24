open! Core
open Protocol_emulator
open Ir_rc6

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Ir_rc6.firmware));
  [%expect {| 64 words, 22 deadline waits, worst slack 6 |}]
;;

(* 200 cycles a unit, as a 450 kHz clock gives: three frames, the trailer bit low, high,
   then low again, the last at the extremes of the address and the command. *)
let unit = 200
let clock_hz = 450_000

let frames =
  [ { Message.toggle = false; address = 0x1a; command = 0x35 }
  ; { toggle = true; address = 0x00; command = 0xff }
  ; { toggle = false; address = 0xff; command = 0x00 }
  ]
;;

let host_words =
  unit
  :: List.concat_map frames ~f:(fun { toggle; address; command } ->
    words ~toggle ~address ~command)
;;

let cycles = (3 * 70 * unit) + 100
let line (m : Machine.t) = (m.pin_out lsr pin) land 1 = 1

let print_decoded levels =
  match decode ~clock_hz levels with
  | Ok (messages, measured) ->
    print_s
      [%message
        ""
          (messages : Message.t list)
          ~as_sent:([%equal: Message.t list] messages frames : bool)
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

let%expect_test "every mark and space to the nominal, and the signal free time" =
  print_decoded (tx_levels (Timed_program.source firmware));
  [%expect
    {|
    ((messages
      (((toggle false) (address 26) (command 53))
       ((toggle true) (address 0) (command 255))
       ((toggle false) (address 255) (command 0))))
     (as_sent true)
     (measured_ns
      (("leader mark" (2666667 2666667)) ("leader space" (888889 888889))
       ("mark 1t" (433333 455556)) ("space 2t" (880000 888889))
       ("space 1t" (431111 455556)) ("mark 2t" (888889 902222))
       ("signal free" (3133333 17477777)) ("mark 3t" (1333333 1333333))
       ("space 3t" (1333333 1333333)))))
    |}]
;;

(* A leader a unit short, 5 units, is 17% off. *)
let%expect_test "the decoder refuses a leader a unit short" =
  let source =
    Bench.patch
      (Timed_program.source firmware)
      ~pattern:"set x, 4\nl0:"
      ~with_:"set x, 3\nl0:"
  in
  print_decoded (tx_levels source);
  [%expect {| (refused (error ("out of spec" "leader mark" (ns 2222222)))) |}]
;;

(* A signal free time of 5 units is 17% short. *)
let%expect_test "the decoder refuses a signal free time a unit short" =
  let source =
    Bench.patch
      (Timed_program.source firmware)
      ~pattern:"set x, 5\nf0:"
      ~with_:"set x, 3\nf0:"
  in
  print_decoded (tx_levels source);
  [%expect {| (refused (error ("signal free time too short" (ns 2244444)))) |}]
;;

let%expect_test "ir_rc6 in lockstep" =
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
  print_decoded (List.rev !levels);
  [%expect
    {|
    ("lockstep held" (cycles 42100))
    (fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    ((messages
      (((toggle false) (address 26) (command 53))
       ((toggle true) (address 0) (command 255))
       ((toggle false) (address 255) (command 0))))
     (as_sent true)
     (measured_ns
      (("leader mark" (2666667 2666667)) ("leader space" (888889 888889))
       ("mark 1t" (433333 455556)) ("space 2t" (880000 888889))
       ("space 1t" (431111 455556)) ("mark 2t" (888889 902222))
       ("signal free" (3133333 17477777)) ("mark 3t" (1333333 1333333))
       ("space 3t" (1333333 1333333)))))
    |}]
;;
