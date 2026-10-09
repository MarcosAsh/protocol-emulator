open! Core
open Protocol_emulator
open Ethernet

let%expect_test "the frame check sequence is the standard CRC-32" =
  let crc = Frame.crc32 (String.to_list "123456789" |> List.map ~f:Char.to_int) in
  print_s [%message (crc : Int.Hex.t)];
  [%expect {| (crc 0xcbf43926) |}]
;;

(* The model with the far end on TD+ and TD-; an undriven pin reads idle. *)
let run ~cycles ~host ~data =
  let t =
    Machine.create ~config ~program:(Timed_program.words firmware)
    |> Or_error.bind ~f:(fun m -> Machine.load_data m data)
    |> ok_exn
  in
  let t = List.fold host ~init:t ~f:(fun t word -> Machine.write_tx t word |> ok_exn) in
  let rec loop t receiver n =
    if n = 0
    then t, receiver
    else (
      let t = Machine.step t ~inputs:0 in
      let driven pin = ((t.pin_out land t.pin_dir) lsr pin) land 1 in
      let receiver =
        Receiver.step receiver ~td_plus:(driven td_plus) ~td_minus:(driven (td_plus + 1))
      in
      loop t receiver (n - 1))
  in
  loop t (Receiver.create ()) cycles
;;

let frame = Frame.udp ~payload:"hello from the chip"
let sent = Frame.with_fcs frame

let%expect_test "a UDP datagram goes out in 10BASE-T" =
  let bits = 8 * List.length sent in
  let t, receiver =
    run
      ~cycles:(link_tenth + (4 * (64 + bits)) + 100)
      ~host:[ link_tenth; bits - 1 ]
      ~data:(Frame.words sent)
  in
  List.iter (Receiver.frames receiver) ~f:(fun received ->
    let #(body, fcs) = List.split_n received (List.length received - 4) in
    let fcs = List.foldi fcs ~init:0 ~f:(fun n acc byte -> acc lor (byte lsl (8 * n))) in
    let payload =
      List.sub body ~pos:42 ~len:19 |> List.map ~f:Char.of_int_exn |> String.of_list
    in
    print_s
      [%message
        ""
          ~bytes:(List.length received : int)
          ~as_sent:([%equal: int list] body frame : bool)
          ~fcs_ok:(fcs = Frame.crc32 body : bool)
          (payload : string)]);
  print_s
    [%message
      ""
        ~violations:(Receiver.violations receiver : string list)
        (t.fault : Machine.Fault.t)];
  [%expect
    {|
    ((bytes 66) (as_sent true) (fcs_ok true) (payload "hello from the chip"))
    ((violations ())
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* Idle for 50 ms: a link pulse every 16 ms keeps the link up. *)
let%expect_test "link pulses while idle" =
  let t, receiver = run ~cycles:2_000_000 ~host:[ link_tenth ] ~data:[] in
  let us =
    List.map (Receiver.link_intervals receiver) ~f:(fun c -> c * cycle_ns / 1000)
  in
  print_s
    [%message
      ""
        ~link_intervals_us:(us : int list)
        ~violations:(Receiver.violations receiver : string list)
        (t.fault : Machine.Fault.t)];
  [%expect
    {|
    ((link_intervals_us (16000 16000)) (violations ())
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* The frame in lockstep, with a short link interval so the frame starts soon. *)
let%expect_test "the frame in lockstep with the hardware" =
  let bits = 8 * List.length sent in
  let receiver = ref (Receiver.create ()) in
  let react (m : Machine.t) =
    let driven pin = ((m.pin_out land m.pin_dir) lsr pin) land 1 in
    receiver
    := Receiver.step !receiver ~td_plus:(driven td_plus) ~td_minus:(driven (td_plus + 1))
  in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:((4 * (64 + bits)) + 200)
      ~preload:[ 50; bits - 1 ]
      ~data:(Frame.words sent)
      ~config
      ~program:(Timed_program.words firmware)
      ~inputs:(fun _ -> 0)
      ~react
      ()
  in
  print_s
    [%message
      ""
        ~frames:(List.length (Receiver.frames !receiver) : int)
        ~as_sent:
          (List.for_all (Receiver.frames !receiver) ~f:(fun f ->
             [%equal: int list] (List.take f (List.length frame)) frame)
           : bool)
        ~violations:(Receiver.violations !receiver : string list)];
  [%expect
    {|
    ("lockstep held" (cycles 2568))
    ((frames 1) (as_sent true) (violations ()))
    |}]
;;

(* The link pulse and TP_IDL sit a fixed distance from deadlines. A frame's bits have no
   deadline, so their phase is only bounded from the frame start, but each edge is exactly
   two cycles after the last. A short link interval lets random host words start frames. *)
let%expect_test "the certificate" =
  Timing_report.print ~config ~period:link_tenth (Timed_program.source firmware);
  let { Soundness.issues; flips; gaps; violations; _ } =
    Soundness.check
      ~period:50
      ~preload:[ 50 ]
      ~config
      (List.init 4 ~f:(fun n -> Soundness.Stimulus.random ~seed:(n + 1) ~cycles:3000))
      (Timed_program.words firmware)
  in
  print_s
    [%message
      (issues : int)
        (flips : int)
        (gaps : int)
        (violations : (int * int * int * int) list)];
  [%expect
    {|
      2  set pindirs, 3               phase ?..?  edge ?..?  jitter ?  gap ?..?
      9  set pins, 1 [3]              phase -63995  edge -63994  gap 63996..?
     10  set pins, 0                  phase -63991  edge -63990  gap 4
     18  set pins, 2 [1]              phase -63991  edge -63990  gap 64000..?
     19  set pins, 1 [3]              phase -63989..?  edge -63988..?  jitter ?  gap 4 from 21, 2 from 18
     20  set pins, 2 [1]              phase -63985..?  edge -63984..?  jitter ?  gap 4
     22  set pins, 1 [1]              phase -63981..?  edge -63980..?  jitter ?  gap 4
     23  set pins, 2 [1]              phase -63979..?  edge -63978..?  jitter ?  gap 2
     24  set pins, 1 [1]              phase -63977..?  edge -63976..?  jitter ?  gap 2
     25  out pins, 1 [1]              phase -63975..?  edge -63974..?  jitter ?  gap 2
     26  jmp y--, 25                  phase -63973..?  flip -63972..?  jitter ?  gap 2
     27  set pins, 1 [10]             phase -63971..?  edge -63970..?  jitter ?  gap 2
     28  set pins, 0                  phase -63960..?  edge -63959..?  jitter ?  gap 11
    ((words 32) (edge_jitter unbounded) (sample_jitter 0) (side_jitter 0)
     (may_miss 0))
    ((issues 5808) (flips 2680) (gaps 5628) (violations ()))
    |}]
;;
