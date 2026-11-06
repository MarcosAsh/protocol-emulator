open! Core
open Protocol_emulator
open Ir_nec

(* The analyser and kernel verdicts on the firmware (it already compiles). *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Ir_nec.firmware));
  [%expect {| 107 words, 34 deadline waits, worst slack 3 |}]
;;

(* The frame plus two repeat codes, at [shortest_third] cycles per third and the trace's
   clock, so both message periods show. *)
let third = shortest_third
let clock_hz = trace_clock_hz
let host_words = third :: List.concat_map sent ~f:words
let cycles = ((2 * 12_600) + 1_500) * third
let line (m : Machine.t) = (m.pin_out lsr pin) land 1 = 1

let print_decoded levels =
  match decode ~clock_hz levels with
  | Ok (messages, measured) ->
    print_s
      [%message
        ""
          (messages : Message.t list)
          ~as_sent:([%equal: Message.t list] messages sent : bool)
          ~measured_ns:(measured : Measured.t)]
  | Error error -> print_s [%message "refused" (error : Error.t)]
;;

(* the firmware on the model, with the host writing each word once the fifo has room *)
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

let%expect_test "every carrier period, burst, space, bit and message period" =
  print_decoded (tx_levels (Timed_program.source firmware));
  [%expect
    {|
    ((messages ((Frame (address 89) (command 22)) Repeat_code Repeat_code))
     (as_sent true)
     (measured_ns
      (("message period" (110226425 110366776)) ("carrier period" (26316 26316))
       ("carrier high" (8772 8772)) ("AGC burst" (9008772 9008772))
       ("frame space" (4500000 4500000)) (burst (561404 561404))
       (one (2254386 2254386)) (zero (1131579 1131579))
       ("repeat space" (2254386 2254386)) ("repeat burst" (561404 561404)))))
    |}]
;;

(* 18 rows of 18 carrier periods plus a pulse is 8.54 ms, 5.2% short. *)
let%expect_test "the decoder refuses an AGC burst 18 periods short" =
  let source =
    Bench.patch
      (Timed_program.source firmware)
      ~pattern:"set x, 18\nagc:"
      ~with_:"set x, 17\nagc:"
  in
  print_decoded (tx_levels source);
  [%expect {| (refused (error ("out of spec" "AGC burst" (ns 8535088)))) |}]
;;

(* A zero's space 8 thirds short is 121 thirds (1.06 ms), 5.6% short. *)
let%expect_test "the decoder refuses a zero 8 thirds short" =
  let source =
    Bench.patch
      (Timed_program.source firmware)
      ~pattern:"set x, 31\nzero_space:"
      ~with_:"set x, 27\nzero_space:"
  in
  print_decoded (tx_levels source);
  [%expect {| (refused (error ("out of spec" zero (ns 1061404)))) |}]
;;

let%expect_test "ir_nec in lockstep" =
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
    ("lockstep held" (cycles 427200))
    (fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)
      (assumption false)))
    ((messages ((Frame (address 89) (command 22)) Repeat_code Repeat_code))
     (as_sent true)
     (measured_ns
      (("message period" (110226425 110366776)) ("carrier period" (26316 26316))
       ("carrier high" (8772 8772)) ("AGC burst" (9008772 9008772))
       ("frame space" (4500000 4500000)) (burst (561404 561404))
       (one (2254386 2254386)) (zero (1131579 1131579))
       ("repeat space" (2254386 2254386)) ("repeat burst" (561404 561404)))))
    |}]
;;
