open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Lin.firmware));
  [%expect {| 60 words, 17 deadline waits, worst slack 13 |}]
;;

(* Table 2.4 (p. 54): 0x16 is 0xD6, 0x3B 0xFB. Table 2.5 (p. 55): 0x4A, 0x55, 0x93, 0xE5
   sum to 0x19, checksum 0xE6; the same with the first byte a PID. *)
let%expect_test "pid and enhanced checksum" =
  let pids = List.map [ 0x16; 0x3b ] ~f:Lin.pid in
  [%test_result: int list] pids ~expect:[ 0xd6; 0xfb ];
  [%test_result: int] (Lin.enhanced ~pid:0x4a [ 0x55; 0x93; 0xe5 ]) ~expect:0xe6;
  [%expect {| |}]
;;

(* The master against the slave model, a cycle at a time at [bit] cycles a bit and the
   slave at [slave_bit], the host taking each word as it comes: what the slave read,
   measured and found wrong. *)
let run ?(slave_bit = Fn.id) ~bit ~id ~data () =
  let pin = Lin.pin in
  let machine =
    Machine.create
      ~config:(Timed_program.config Lin.firmware)
      ~program:(Timed_program.words Lin.firmware)
    |> ok_exn
  in
  let machine =
    List.fold ((bit / 2) :: Lin.words ~id ~data) ~init:machine ~f:(fun machine word ->
      Machine.write_tx machine word |> ok_exn)
  in
  let slave =
    Lin.Slave.create ~clock_hz:(bit * 19_200) ~bit:(slave_bit bit) ~publishes:[ id, data ]
  in
  let machine, slave, _, pushed =
    List.fold
      (List.range 0 ((40 + (10 * (List.length data + 1))) * slave_bit bit))
      ~init:(machine, slave, false, [])
      ~f:(fun (machine, slave, low, pushed) _ ->
        let machine = Machine.step machine ~inputs:(if low then 0 else 1 lsl pin) in
        let low =
          Pin_trace.Peer.bit machine.pin_dir pin = 1 || Lin.Slave.drive_low slave
        in
        let machine, pushed =
          match Machine.read_rx machine with
          | Some (word, machine) -> machine, (word land 0xff) :: pushed
          | None -> machine, pushed
        in
        machine, Lin.Slave.step slave ~low, low, pushed)
  in
  [%test_result: int list]
    ~message:"the response read back"
    (List.rev pushed)
    ~expect:(data @ [ Lin.enhanced ~pid:(Lin.pid id) data ]);
  print_s
    [%message
      ""
        ~headers:(Lin.Slave.headers slave : Int.Hex.t list)
        ~irq:(machine.irq : bool)
        ~fault:(machine.fault : Machine.Fault.t)
        ~measured:(Lin.Slave.measured slave : Measured.t)
        ~violations:(Lin.Slave.violations slave : string list)]
;;

let%expect_test "a header, and the slave's response read back" =
  run ~bit:32 ~id:0x16 ~data:[ 0x4c; 0x49; 0x4e ] ();
  [%expect
    {|
    ((headers (0xd6)) (irq false)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false)))
     (measured
      ((break (703125 703125)) (delimiter (78125 78125))
       (dominant (52083 156250)) (recessive (52083 208333))))
     (violations ()))
    |}]
;;

(* eight bytes, the most a frame carries, at the shortest half bit the kernel checked *)
let%expect_test "eight bytes at the floor" =
  run ~bit:32 ~id:0x3b ~data:[ 0x00; 0xff; 0x01; 0x80; 0x55; 0xaa; 0x0f; 0xf0 ] ();
  [%expect
    {|
    ((headers (0xfb)) (irq false)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false)))
     (measured
      ((break (703125 703125)) (delimiter (78125 78125))
       (dominant (52083 468750)) (recessive (52083 468750))))
     (violations ()))
    |}]
;;

(* 19200 baud on the bench's 48 MHz *)
let%expect_test "at the bench's rate" =
  run ~bit:(2 * Bench.half ~hz:19_200) ~id:0x16 ~data:[ 0x4c; 0x49; 0x4e ] ();
  [%expect
    {|
    ((headers (0xd6)) (irq false)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false)))
     (measured
      ((break (703125 703125)) (delimiter (78125 78125))
       (dominant (52083 156250)) (recessive (52083 208333))))
     (violations ()))
    |}]
;;

(* FTOL_SYNC, Table 6.2 (p. 113): a slave within 2% of the master, either way, over a
   frame of eight bytes *)
let%expect_test "a slave 2% off the master" =
  List.iter [ 49; -49 ] ~f:(fun off ->
    run
      ~slave_bit:(fun bit -> bit + off)
      ~bit:(2 * Bench.half ~hz:19_200)
      ~id:0x3b
      ~data:[ 0x00; 0xff; 0x01; 0x80; 0x55; 0xaa; 0x0f; 0xf0 ]
      ());
  [%expect
    {|
    ((headers (0xfb)) (irq false)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false)))
     (measured
      ((break (703125 703125)) (delimiter (78125 78125))
       (dominant (52083 477938)) (recessive (52083 477938))))
     (violations ()))
    ((headers (0xfb)) (irq false)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false)))
     (measured
      ((break (703125 703125)) (delimiter (78125 78125))
       (dominant (51063 459563)) (recessive (51063 459563))))
     (violations ()))
    |}]
;;
