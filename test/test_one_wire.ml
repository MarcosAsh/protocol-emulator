open! Core
open Protocol_emulator
open One_wire

let device_rom = rom ~family:0x28 ~serial:0x0123_4567_89ab
let read_rom = [ reset; byte 0x33 ] @ List.init 8 ~f:(fun _ -> byte 0xff)
let master_low (m : Machine.t) = (m.pin_dir lsr pin) land 1 = 1

let bus (m : Machine.t) slave =
  if master_low m || Slave.drive_low slave then 0 else 1 lsl pin
;;

(* the answers: presence, the echo of the command, then what was read *)
let print_answers answers slave (fault : Machine.Fault.t) =
  let presence, read =
    match answers with
    | presence :: _command :: read -> Some presence, read
    | _ -> None, []
  in
  print_s
    [%message
      ""
        (presence : int option)
        ~rom:(List.map read ~f:(sprintf "%02x") : string list)
        ~crc8:(crc8 read : int)
        ~matches:(List.equal Int.equal read device_rom : bool)
        ~log:(Slave.log slave : string list)
        ~measured_ns:(Slave.measured slave : Measured.t)
        ~violations:
          (Slave.violations slave |> List.dedup_and_sort ~compare:String.compare
           : string list)
        (fault : Machine.Fault.t)]
;;

let run ?(words = read_rom) ~unit ~cycles () =
  let t = Machine.create ~config ~program:(Firmware.assemble firmware) |> ok_exn in
  let rec loop (t : Machine.t) slave pending n answers =
    if n = 0
    then t, slave, List.rev answers
    else (
      let t, pending =
        match pending with
        | w :: rest when List.length t.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx t w |> ok_exn, rest
        | pending -> t, pending
      in
      let t' = Machine.step t ~inputs:(bus t slave) in
      let slave = Slave.step slave ~master_low:(master_low t) in
      let answers, t' =
        match Machine.read_rx t' with
        | Some (a, t') -> a :: answers, t'
        | None -> answers, t'
      in
      loop t' slave pending (n - 1) answers)
  in
  let t, slave, answers =
    loop t (Slave.create ~cycle_ns ~rom:device_rom) (unit :: words) cycles []
  in
  print_answers answers slave t.fault
;;

let%expect_test "the rom is as the device has it" =
  print_s [%message (List.map device_rom ~f:(sprintf "%02x") : string list)];
  [%expect {| ("List.map device_rom ~f:(sprintf \"%02x\")" (28 ab 89 67 45 23 01 5a)) |}]
;;

let%expect_test "reset, read rom, eight bytes and a good crc" =
  run ~unit:standard_unit ~cycles:290_000 ();
  [%expect
    {|
    ((presence (0)) (rom (28 ab 89 67 45 23 01 5a)) (crc8 0) (matches true)
     (log (reset presence "command 0x33" "rom sent"))
     (measured_ns
      (("reset low" (480040 480040)) ("one low" (6000 6000)) (slot (66000 66220))
       (high (6000 60220)) ("zero low" (60000 60000))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* the same program with a unit of 20 cycles, as if the clock were 3.3 MHz, so that the
   hardware simulation stays short; the slave is told that a cycle is 300 ns *)
let%expect_test "one wire in lockstep" =
  let slave = ref (Slave.create ~cycle_ns:300 ~rom:device_rom) in
  let pending = ref (20 :: read_rom) in
  let answers = ref [] in
  let last = ref None in
  let model =
    Lockstep.lockstep
      ~cycles:20_000
      ~config
      ~program:(Firmware.assemble firmware)
      ~inputs:(fun _ ->
        Option.value_map !last ~default:(1 lsl pin) ~f:(fun m -> bus m !slave))
      ~host:(fun _ ->
        let tx_level, rx_head =
          Option.value_map !last ~default:(0, None) ~f:(fun (m : Machine.t) ->
            List.length m.tx_fifo, List.hd m.rx_fifo)
        in
        Option.iter rx_head ~f:(fun a -> answers := a :: !answers);
        let tx =
          match !pending with
          | w :: rest when tx_level < Machine.fifo_depth ->
            pending := rest;
            Some w
          | _ -> None
        in
        { Lockstep.Host.idle with tx; pop_rx = Option.is_some rx_head })
      ~react:(fun m ->
        Option.iter !last ~f:(fun before ->
          slave := Slave.step !slave ~master_low:(master_low before));
        last := Some m)
      ()
  in
  print_answers (List.rev !answers) !slave model.fault;
  [%expect
    {|
    ("lockstep held" (cycles 20000))
    ((presence (0)) (rom (28 ab 89 67 45 23 01 5a)) (crc8 0) (matches true)
     (log (reset presence "command 0x33" "rom sent"))
     (measured_ns
      (("reset low" (480600 480600)) ("one low" (6000 6000)) (slot (66000 69300))
       (high (6000 63300)) ("zero low" (60000 60000))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "every edge and every sample is placed by a deadline" =
  Timing_report.print ~config ~period:standard_unit firmware;
  [%expect
    {|
     11  set pindirs, 1               phase -299  edge -298
     14  mov pindirs, !y              phase -299  edge -298
     16  in pins, 1                   phase -299  sample -299
     21  set pindirs, 0               phase -299  edge -298
     27  set pindirs, 1               phase -299  edge -298
     34  set pindirs, 0               phase -297  edge -296
     38  in pins, 1                   phase -297  sample -297
    ((words 48) (edge_jitter 0) (sample_jitter 0) (may_miss 0))
    |}]
;;

let%expect_test "the shortest unit the program keeps up with" =
  Timing_report.print ~config ~period:5 firmware;
  [%expect
    {|
     11  set pindirs, 1               phase -4  edge -3
     14  mov pindirs, !y              phase -4  edge -3
     16  in pins, 1                   phase -4  sample -4
     21  set pindirs, 0               phase -4  edge -3
     27  set pindirs, 1               phase -4  edge -3
     34  set pindirs, 0               phase -2  edge -1
     38  in pins, 1                   phase -2  sample -2
    ((words 48) (edge_jitter 0) (sample_jitter 0) (may_miss 0))
    |}]
;;

let%expect_test "a unit of four cycles is too short" =
  Timing_report.print ~config ~period:4 firmware;
  [%expect
    {|
     10  wait t+                      phase 0..1  slack -1..0  MAY MISS
     11  set pindirs, 1               phase -3..-2  edge -2..-1  jitter 1
     14  mov pindirs, !y              phase -3  edge -2
     16  in pins, 1                   phase -3  sample -3
     21  set pindirs, 0               phase -3  edge -2
     27  set pindirs, 1               phase -3  edge -2
     34  set pindirs, 0               phase -1  edge 0
     36  wait t+                      phase -1..1  slack -1..1  MAY MISS
     38  in pins, 1                   phase -1..0  sample -1..0  jitter 1
     40  wait t+                      phase -1..2  slack -2..1  MAY MISS
    ((words 48) (edge_jitter 1) (sample_jitter 1) (may_miss 3))
    |}]
;;

(* with a unit of 8 us every time the master drives is still legal, but the sample is at
   16 us and the slave lets go of a zero after 15: the rom reads as ones *)
let%expect_test "a sample after 15 us misses the zeros" =
  run
    ~words:[ reset; byte 0x33; byte 0xff; byte 0xff ]
    ~unit:(8_000 / cycle_ns)
    ~cycles:180_000
    ();
  [%expect
    {|
    ((presence (0)) (rom (ff ff)) (crc8 180) (matches false)
     (log (reset presence "command 0x33"))
     (measured_ns
      (("reset low" (640040 640040)) ("one low" (8000 8000)) (slot (88000 88220))
       (high (8000 80220)) ("zero low" (80000 80000))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* and with 5 us the reset is 400 us and a zero 50 us, which the slave will not have *)
let%expect_test "a unit of 5 us is out of the standard" =
  run ~words:[ reset; byte 0x33 ] ~unit:(5_000 / cycle_ns) ~cycles:80_000 ();
  [%expect
    {|
    ((presence (1)) (rom ()) (crc8 0) (matches false) (log ())
     (measured_ns
      ((slot (55000 805200)) (high (5000 405160)) ("one low" (5000 5000))))
     (violations ("low of 400040 ns" "low of 50000 ns" "slot of 55000 ns"))
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
