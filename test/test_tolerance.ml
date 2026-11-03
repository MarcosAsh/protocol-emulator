open! Core
open Protocol_emulator
open Tolerance

let percent ppm = sprintf "%d.%03d%%" (ppm / 10_000) (ppm % 10_000 / 10)

(* The bounds, then the model at each bound for a few phases, and one step past each at
   the phase the bound says fails there. *)
let show name (r : Receiver.t) =
  let b = bounds r in
  let fast, slow = Bounds.ppm b ~nominal:r.nominal in
  let phases = [ 0; unit / 3; unit / 2; unit - 1; b.fast_witness; b.slow_witness ] in
  let holds m = List.for_all phases ~f:(fun phase -> receives r ~m ~phase) in
  print_s
    [%message
      name
        ~fast:(percent fast)
        ~slow:(percent slow)
        ~least:(b.least : int)
        ~most:(b.most : int)
        ~fastest:(b.fastest_read : Read.t)
        ~slowest:(b.slowest_read : Read.t)
        ~holds_at_both:(holds b.least && holds b.most : bool)
        ~fails_one_faster:(not (receives r ~m:(b.least - 1) ~phase:b.fast_witness) : bool)
        ~fails_one_slower:(not (receives r ~m:(b.most + 1) ~phase:b.slow_witness) : bool)]
;;

let%expect_test "each receiver's tolerance, from its certificate" =
  show "uart_rx" (Receiver.uart_rx ~period:16 ());
  show "uart_rx_host_rate" (Receiver.uart_rx_host_rate ~half:208 ());
  print_s [%sexp (applies (Receiver.usb_rx ()) : unit Or_error.t)];
  show "can_rx" (Receiver.can_rx ~period:96 ~sample:72 ());
  [%expect
    {|
    (uart_rx (fast 4.374%) (slow 4.166%) (least 1002701) (most 1092266)
     (fastest ((pc 3) (d (152 152)) (since 9) (until (10))))
     (slowest ((pc 16) (d (150 150)) (since 9) (until (10))))
     (holds_at_both true) (fails_one_faster true) (fails_one_slower true))
    (uart_rx_host_rate (fast 4.927%) (slow 5.555%) (least 25919488)
     (most 28777585) (fastest ((pc 4) (d (3954 3954)) (since 9) (until (10))))
     (slowest ((pc 19) (d (3952 3952)) (since 9) (until (10))))
     (holds_at_both true) (fails_one_faster true) (fails_one_slower true))
    (Error
     ("formula does not apply: re-anchors on every edge, from [now] where it saw one late"
      usb_rx (arms 4)))
    (can_rx (fast 1.041%) (slow 7.499%) (least 6225920) (most 6763315)
     (fastest ((pc 240) (d (1994 1994)) (since 5) (until (21))))
     (slowest ((pc 191) (d (1032 1032)) (since 10) (until (11))))
     (holds_at_both true) (fails_one_faster true) (fails_one_slower true))
    |}]
;;

(* The CAN receiver's window with its own ACK back on CRX [echo] cycles later, the
   transceiver's loop and the synchroniser *)
let%expect_test "the CAN receiver's window by the transceiver's loop" =
  let longest = Can_node.Receiver.longest_loop in
  List.iter
    (List.range 0 11 @ [ longest; longest + 1 ])
    ~f:(fun echo ->
      let r = Receiver.can_rx ~echo ~period:96 ~sample:72 () in
      match bounds r with
      | b ->
        let fast, slow = Bounds.ppm b ~nominal:r.nominal in
        print_s
          [%message
            ""
              (echo : int)
              ~fast:(percent fast)
              ~slow:(percent slow)
              ~fast_read:(b.fastest_read.pc : int)]
      | exception exn -> print_s [%message "" (echo : int) (exn : exn)]);
  [%expect
    {|
    ((echo 0) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 1) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 2) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 3) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 4) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 5) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 6) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 7) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 8) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 9) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 10) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 72) (fast 1.041%) (slow 7.499%) (fast_read 240))
    ((echo 73) (exn ("BUG: the receiver fails at its own rate" can_rx)))
    |}]
;;

(* As the chip runs it, watching the premises the certificate was checked under: the
   phases, of 64, at which a frame is lost or a premise fails at each end of the window *)
let%expect_test "the CAN receiver's window with its premises watched" =
  let r = Receiver.can_rx ~period:96 ~sample:72 () in
  let b = bounds r in
  let watched =
    { r with
      premises = System_lockstep.Assumptions.premises (Certified.assumptions r.firmware)
    }
  in
  let fails m =
    List.count
      (List.init 64 ~f:(fun i -> i * unit / 64))
      ~f:(fun phase -> not (receives watched ~m ~phase))
  in
  print_s
    [%message "" ~at_fast_end:(fails b.least : int) ~at_slow_end:(fails b.most : int)];
  [%expect {| ((at_fast_end 0) (at_slow_end 0)) |}]
;;

(* The UART receivers as the chip runs them, the single edge watched: a frame lost one
   step past the fast bound is the next start edge before the arm, which faults the
   premise as well as the deadline the stale capture misses *)
let%expect_test "the UART receivers past the fast bound, premises watched" =
  List.iter
    [ "uart_rx", Receiver.uart_rx ~period:16 ()
    ; "uart_rx_host_rate", Receiver.uart_rx_host_rate ~half:208 ()
    ]
    ~f:(fun (name, r) ->
      let b = bounds r in
      print_s
        [%message
          name
            ~premises:(r.premises : Machine.Premises.t)
            ~fault:(fault r ~m:(b.least - 1) ~phase:b.fast_witness : Machine.Fault.t)]);
  [%expect
    {|
    (uart_rx (premises ((period ()) (floor false) (single_edge true)))
     (fault
      ((underflow false) (overflow false) (missed_deadline true) (decode false)
       (assumption true))))
    (uart_rx_host_rate
     (premises ((period (208)) (floor false) (single_edge true)))
     (fault
      ((underflow false) (overflow false) (missed_deadline true) (decode false)
       (assumption true))))
    |}]
;;

(* usb_rx as the chip runs it, its certificate's premises watched: from every phase at the
   nominal rate the run ends clean *)
let%expect_test "usb_rx at the nominal rate, premises watched" =
  let r = Receiver.usb_rx () in
  let phases = List.init 16 ~f:(fun i -> i * unit / 16) in
  print_s
    [%message
      ""
        ~premises:(r.premises : Machine.Premises.t)
        ~faults:
          (List.map phases ~f:(fun phase -> fault r ~m:(r.nominal * unit) ~phase)
           |> List.dedup_and_sort ~compare:Machine.Fault.compare
           : Machine.Fault.t list)
        ~received:
          (List.for_all phases ~f:(fun phase -> receives r ~m:(r.nominal * unit) ~phase)
           : bool)];
  [%expect
    {|
    ((premises ((period (32)) (floor false) (single_edge true)))
     (faults
      (((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false))))
     (received true))
    |}]
;;

(* the CAN frames hold the longest runs: ten bits between falling edges inside a frame,
   five dominant and five recessive, and from the CRC's last fall to the next SOF *)
(* Not certified: where the formula does not apply, the model from 16 phases, walked out
   from the nominal rate in steps of 1/8%, to the first step that loses a frame. *)
let%expect_test "usb_rx by model search, not certified" =
  let r = Receiver.usb_rx () in
  let nominal = r.nominal * unit in
  let phases = List.init 16 ~f:(fun i -> i * unit / 16) in
  let holds m = List.for_all phases ~f:(fun phase -> receives r ~m ~phase) in
  let step = nominal / 800 in
  let rec walk m ~by = if holds m then walk (m + by) ~by else m in
  let ppm m = (m - nominal) * 1_000_000 / nominal in
  print_s
    [%message
      "model search, not certified"
        ~first_loss_faster:(percent (-ppm (walk nominal ~by:(-step))))
        ~first_loss_slower:(percent (ppm (walk nominal ~by:step)))];
  [%expect
    {|
    ("model search, not certified" (first_loss_faster 2.249%)
     (first_loss_slower 3.374%))
    |}]
;;

let%expect_test "the CAN receiver's frames" =
  List.iter Receiver.can_frames ~f:(fun frame ->
    let segments = Receiver.can_segments frame in
    print_s
      [%message
        ""
          ~inside:(List.drop_last_exn segments |> List.fold ~init:0 ~f:Int.max : int)
          ~to_next_sof:(List.last_exn segments : int)]);
  [%expect
    {|
    ((inside 7) (to_next_sof 13))
    ((inside 8) (to_next_sof 14))
    ((inside 8) (to_next_sof 15))
    ((inside 7) (to_next_sof 15))
    ((inside 8) (to_next_sof 15))
    ((inside 10) (to_next_sof 13))
    ((inside 6) (to_next_sof 21))
    |}]
;;

(* The fast bound is the arm after the stop bit's middle, 19 half periods and 2 cycles
   from the start edge, before the next start bit ten bits in; the slow, the stop bit's
   middle at 19 half periods, after its start nine bits in. *)
let%expect_test "uart_rx_host_rate by its half period" =
  let bytes = [ 0x55; 0xaa; 0x00; 0xff; 0x0f; 0xf0 ] in
  List.iter [ 4; 8; 13; 26; 52; 104; 208; 2500 ] ~f:(fun half ->
    let r = Receiver.uart_rx_host_rate ~bytes ~half () in
    let b = bounds r in
    let fast, slow = Bounds.ppm b ~nominal:r.nominal in
    print_s
      [%message
        ""
          (half : int)
          ~fast:(percent fast)
          ~slow:(percent slow)
          ~arm:(fst b.fastest_read.d - (19 * half) : int)
          ~stop:(fst b.slowest_read.d - (19 * half) : int)]);
  [%expect
    {|
    ((half 4) (fast 1.249%) (slow 5.555%) (arm 2) (stop 0))
    ((half 8) (fast 3.125%) (slow 5.555%) (arm 2) (stop 0))
    ((half 13) (fast 3.846%) (slow 5.555%) (arm 2) (stop 0))
    ((half 26) (fast 4.423%) (slow 5.555%) (arm 2) (stop 0))
    ((half 52) (fast 4.711%) (slow 5.555%) (arm 2) (stop 0))
    ((half 104) (fast 4.855%) (slow 5.555%) (arm 2) (stop 0))
    ((half 208) (fast 4.927%) (slow 5.555%) (arm 2) (stop 0))
    ((half 2500) (fast 4.993%) (slow 5.555%) (arm 2) (stop 0))
    |}]
;;

(* what the bench sweep rests on: [predicts] and [faults] against the model, from phase 0,
   near each bound and every half percent out to 7% *)
let%expect_test "predicts matches the model" =
  let r = Receiver.uart_rx_host_rate ~bytes:(List.init 64 ~f:Fn.id) ~half:16 () in
  let b = bounds r in
  let nominal = r.nominal * unit in
  let ms =
    List.concat_map [ b.least; b.most ] ~f:(fun m ->
      List.range (m - 300) (m + 300) ~stride:25)
    @ List.map (List.range (-14) 15) ~f:(fun h -> nominal + (h * nominal / 200))
  in
  let predicts = predicts r in
  let faults = faults r in
  let agree, disagree =
    List.partition_tf ms ~f:(fun m ->
      Bool.equal (predicts ~m) (receives r ~m ~phase:0)
      && Bool.equal (faults ~m) (faulted r ~m ~phase:0))
  in
  print_s
    [%message
      ""
        ~agree:(List.length agree : int)
        ~disagree:(disagree : int list)
        ~fail:(List.count ms ~f:(fun m -> not (predicts ~m)) : int)
        ~fault:(List.count ms ~f:(fun m -> faults ~m) : int)];
  [%expect {| ((agree 77) (disagree ()) (fail 30) (fault 13)) |}]
;;

let%expect_test "the bench sweep" =
  let b = bounds Bench.receiver in
  let steps = Bench.steps () in
  let first_fail l = List.find l ~f:(fun (_, ok) -> not ok) |> Option.map ~f:fst in
  print_s
    [%message
      ""
        ~least:(b.least : int)
        ~most:(b.most : int)
        ~steps:(List.length steps : int)
        ~first_faster:
          (first_fail (List.rev (List.filter steps ~f:(fun (m, _) -> m < b.least)))
           : int option)
        ~first_slower:
          (first_fail (List.filter steps ~f:(fun (m, _) -> m > b.most)) : int option)
        ~all_inside_pass:
          (List.for_all steps ~f:(fun (m, ok) -> ok || m < b.least || m > b.most) : bool)
        ~faults:(Bench.faults () : int list)];
  [%expect
    {|
    ((least 311315661) (most 345884444) (steps 95) (first_faster (311315660))
     (first_slower (345884476)) (all_inside_pass true)
     (faults
      (311314637 311315149 311315405 311315533 311315597 311315613 311315629
       311315637 311315645 311315649 311315653 311315655 311315657 311315658
       311315659 311315660)))
    |}]
;;
