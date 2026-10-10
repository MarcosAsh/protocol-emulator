open! Core
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
  show "usb_rx" (Receiver.usb_rx ());
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
    (usb_rx (fast 3.125%) (slow 3.348%) (least 2031616) (most 2167369)
     (fastest ((pc 44) (d (433 433)) (since 7) (until (14))))
     (slowest ((pc 54) (d (463 463)) (since 14) (until (18))))
     (holds_at_both false) (fails_one_faster true) (fails_one_slower true))
    (can_rx (fast 1.140%) (slow 7.499%) (least 6219679) (most 6763315)
     (fastest ((pc 8) (d (1992 1992)) (since 5) (until (21))))
     (slowest ((pc 194) (d (1032 1032)) (since 10) (until (11))))
     (holds_at_both true) (fails_one_faster true) (fails_one_slower true))
    |}]
;;

(* the CAN frames hold the longest runs: ten bits between falling edges inside a frame,
   five dominant and five recessive, and from the CRC's last fall to the next SOF *)
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

(* what the bench sweep rests on: [predicts] against the model, from phase 0 *)
let%expect_test "predicts matches the model" =
  let r = Receiver.uart_rx_host_rate ~bytes:(List.init 64 ~f:Fn.id) ~half:16 () in
  let b = bounds r in
  let ms =
    List.concat_map [ b.least; b.most ] ~f:(fun m ->
      List.range (m - 300) (m + 300) ~stride:25)
  in
  let predicts = predicts r in
  let agree, disagree =
    List.partition_tf ms ~f:(fun m -> Bool.equal (predicts ~m) (receives r ~m ~phase:0))
  in
  print_s
    [%message
      ""
        ~agree:(List.length agree : int)
        ~disagree:(disagree : int list)
        ~fail:(List.count ms ~f:(fun m -> not (predicts ~m)) : int)];
  [%expect {| ((agree 48) (disagree ()) (fail 21)) |}]
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
          (List.for_all steps ~f:(fun (m, ok) -> ok || m < b.least || m > b.most) : bool)];
  [%expect
    {|
    ((least 311315661) (most 345884444) (steps 95) (first_faster (311315660))
     (first_slower (345884476)) (all_inside_pass true))
    |}]
;;
