open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Snorble.firmware));
  [%expect {| 78 words, 5 deadline waits, worst slack 0 |}]
;;

(* SIG each cycle, the host writing every byte before the start *)
let levels ~cycles bytes =
  let machine =
    Machine.create
      ~config:(Timed_program.config Snorble.firmware)
      ~program:(Timed_program.words Snorble.firmware)
    |> ok_exn
  in
  let machine =
    List.fold bytes ~init:machine ~f:(fun m b -> Machine.write_tx m b |> ok_exn)
  in
  let machine, levels =
    List.fold_map (List.range 0 cycles) ~init:machine ~f:(fun machine _ ->
      let machine = Machine.step machine ~inputs:0 in
      machine, (machine.pin_out lsr Snorble.pin) land 1 = 1)
  in
  machine, levels
;;

let runs levels =
  List.group levels ~break:Bool.( <> )
  |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
;;

(* The example of section 6, p.2: 0xa5 has four ones, so parity 1, and the lows are 1, 0,
   1, 0, 0, 1, 0, 1 and 1 after a sync of 8.0 us, every gap 2.0 us. *)
let%expect_test "the line for 0xa5, as section 6 draws it" =
  let _, levels = levels ~cycles:11_000 [ 0xa5 ] in
  let frame =
    List.drop_while (runs levels) ~f:(fun (high, n) -> high || n < 300)
    |> Fn.flip List.take 19
  in
  List.iter frame ~f:(fun (high, n) ->
    printf "%s %4d cycles %s\n" (if high then "high" else "low ") n (Bench.time n));
  [%expect {|
    low   384 cycles 8 us
    high   96 cycles 2 us
    low   144 cycles 3 us
    high   96 cycles 2 us
    low    58 cycles 1.208 us
    high   96 cycles 2 us
    low   144 cycles 3 us
    high   96 cycles 2 us
    low    58 cycles 1.208 us
    high   96 cycles 2 us
    low    58 cycles 1.208 us
    high   96 cycles 2 us
    low   144 cycles 3 us
    high   96 cycles 2 us
    low    58 cycles 1.208 us
    high   96 cycles 2 us
    low   144 cycles 3 us
    high   96 cycles 2 us
    low   144 cycles 3 us
    |}]
;;

(* a receiver's view of the line: the bytes, each with odd parity, and the fault bits *)
let%expect_test "a receiver reads every byte" =
  let machine, levels = levels ~cycles:60_000 Snorble.bytes in
  let decoded = Snorble.decode ~clock_hz:Bench.clock_hz (runs levels) in
  [%test_result: (int * bool) list]
    decoded
    ~expect:(List.map Snorble.bytes ~f:(fun b -> b, true));
  print_s [%message (decoded : (Int.Hex.t * bool) list) (machine.fault : Machine.Fault.t)];
  [%expect {|
    ((decoded ((0xa5 true) (0x0 true) (0xff true) (0x3c true)))
     (machine.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "every byte, against the golden decoder" =
  Quickcheck.test ~trials:20 (Int.gen_incl 0 255) ~sexp_of:Int.sexp_of_t ~f:(fun byte ->
    let _, levels = levels ~cycles:11_000 [ byte ] in
    [%test_result: (int * bool) list]
      ~message:"decoded"
      (Snorble.decode ~clock_hz:Bench.clock_hz (runs levels))
      ~expect:[ byte, true ])
;;

let%expect_test "the bench's run against section 4's limits" =
  print_string
    (Datasheet.to_string Snorble.bench (Datasheet.check Snorble.limits Snorble.bench));
  [%expect {|
    snorble            tSYN           >=     7500 ns  run    384 (8000.0 ns)   needs  361       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tSYN           <=     8500 ns  run    384 (8000.0 ns)   needs  407       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tL0            >=     1100 ns  kernel 58 (1208.3 ns)    needs   54       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tL0            <=     1300 ns  run    58 (1208.3 ns)    needs   61       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tL1            >=     2900 ns  run    144 (3000.0 ns)   needs  141       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tL1            <=     3100 ns  run    144 (3000.0 ns)   needs  147       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tH             >=     1800 ns  kernel 96 (2000.0 ns)    needs   88       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tH             <=     4000 ns  run    96 (2000.0 ns)    needs  191       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1, and note 1, p.2: inside a frame; margin a cycle
    snorble            tIFG           >=    20000 ns  run    8583 (178812.5 ns) needs  961       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1, and note 3, p.2; margin a cycle
    snorble            frame rate     >=   200000 ns  run    10439 (217479.2 ns) needs 9601       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 1, p.1: about 5 kframes/s at most; margin a cycle
    |}]
;;
