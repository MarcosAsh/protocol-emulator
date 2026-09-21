open! Core
open Protocol_emulator
open Ps2

(* The host of the core. It answers the byte 0xed from the PS/2 host with 0xfa, as a
   keyboard does, and when the interrupt says a frame was dropped it writes the last byte
   again, which is enough for tests that have one byte in flight. *)
module Driver = struct
  type t =
    { pending : int list
    ; last : int option
    ; received : int list
    ; resent : int
    }

  let create ~quarter bytes =
    { pending = quarter :: bytes; last = None; received = []; resent = 0 }
  ;;

  let decide t (m : Machine.t) =
    let t =
      match List.hd m.rx_fifo with
      | None -> t
      | Some word ->
        let pending = if word land 0xff = 0xed then t.pending @ [ 0xfa ] else t.pending in
        { t with pending; received = word :: t.received }
    in
    let t =
      if m.irq
      then { t with pending = Option.to_list t.last @ t.pending; resent = t.resent + 1 }
      else t
    in
    let tx, t =
      match t.pending with
      | word :: pending when List.length m.tx_fifo < Machine.fifo_depth ->
        Some word, { t with pending; last = Some word }
      | _ -> None, t
    in
    ( t
    , { Lockstep.Host.idle with
        tx
      ; pop_rx = not (List.is_empty m.rx_fifo)
      ; clear_irq = m.irq
      } )
  ;;
end

let bus (m : Machine.t) host =
  let released pin low = if low || (m.pin_dir lsr pin) land 1 = 1 then 0 else 1 in
  released clock_pin (Host.clock_low host), released data_pin (Host.data_low host)
;;

let inputs ~clock ~data = (clock lsl clock_pin) lor (data lsl data_pin)

let print_run host (driver : Driver.t) (fault : Machine.Fault.t) =
  print_s
    [%message
      ""
        ~host:(Host.log host : string list)
        ~core_received:(List.rev_map driver.received ~f:(sprintf "0x%03x") : string list)
        ~resent:(driver.resent : int)
        ~measured_ns:(Host.measured host : Measured.t)
        ~violations:
          (Host.violations host |> List.dedup_and_sort ~compare:String.compare
           : string list)
        (fault : Machine.Fault.t)]
;;

(* the host of the core acts on the model as the last cycle left it, in the order the
   lockstep harness does *)
let run ?(script = []) ~quarter ~bytes ~cycles () =
  let rec loop (m : Machine.t) host driver n =
    if n = 0
    then m, host, driver
    else (
      let driver, (action : Lockstep.Host.t) = Driver.decide driver m in
      let clock, data = bus m host in
      let m = if action.clear_irq then Machine.clear_irq m else m in
      let m =
        match Machine.read_rx m with
        | Some (_, popped) when action.pop_rx -> popped
        | _ -> m
      in
      let m = Machine.step m ~inputs:(inputs ~clock ~data) in
      let m =
        Option.fold action.tx ~init:m ~f:(fun m w -> Machine.write_tx m w |> ok_exn)
      in
      loop m (Host.step host ~clock ~data) driver (n - 1))
  in
  let m, host, driver =
    loop
      (Machine.create ~config ~program:(Firmware.assemble firmware) |> ok_exn)
      (Host.create ~cycle_ns script)
      (Driver.create ~quarter bytes)
      cycles
  in
  print_run host driver m.fault
;;

let%expect_test "a key goes to the host, the host sends a command and gets its answer" =
  run
    ~quarter:standard_quarter
    ~bytes:[ 0x1c ]
    ~script:[ 52_000, Send 0xed ]
    ~cycles:152_000
    ();
  [%expect
    {|
    ((host ("byte 0x1c" "sent 0xed, acknowledged" "byte 0xfa"))
     (core_received (0x3ed)) (resent 0)
     (measured_ns
      ((setup (19960 19960)) ("clock low" (40000 40000))
       ("clock high" (40000 40000)) (hold (20040 20040))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "the host takes the clock in the middle of a frame" =
  run
    ~quarter:standard_quarter
    ~bytes:[ 0x1c ]
    ~script:[ 20_000, Inhibit ]
    ~cycles:76_000
    ();
  [%expect
    {|
    ((host ("gave up a frame after 4 bits" inhibited "byte 0x1c"))
     (core_received ()) (resent 1)
     (measured_ns
      ((setup (19960 19960)) ("clock low" (40000 40000))
       ("clock high" (40000 40000)) (hold (20040 20040))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* the same program with a quarter of 40 cycles, as if the clock were 2 MHz, so that the
   hardware simulation stays short; the host is told that a cycle is 500 ns. It takes the
   clock in the middle of the answer, which has to be sent again. *)
let%expect_test "ps2 in lockstep" =
  let host = ref (Host.create ~cycle_ns:500 [ 2_080, Send 0xed; 5_000, Inhibit ]) in
  let driver = ref (Driver.create ~quarter:40 [ 0x1c ]) in
  let last = ref None in
  let levels = ref (1, 1) in
  let model =
    Lockstep.lockstep
      ~cycles:9_500
      ~config
      ~program:(Firmware.assemble firmware)
      ~inputs:(fun _ ->
        levels := Option.value_map !last ~default:(1, 1) ~f:(fun m -> bus m !host);
        let clock, data = !levels in
        inputs ~clock ~data)
      ~host:(fun _ ->
        match !last with
        | None -> Lockstep.Host.idle
        | Some m ->
          let decided, action = Driver.decide !driver m in
          driver := decided;
          action)
      ~react:(fun m ->
        let clock, data = !levels in
        host := Host.step !host ~clock ~data;
        last := Some m)
      ()
  in
  print_run !host !driver model.fault;
  [%expect
    {|
    ("lockstep held" (cycles 9500))
    ((host
      ("byte 0x1c" "sent 0xed, acknowledged" "gave up a frame after 5 bits"
       inhibited "byte 0xfa"))
     (core_received (0x3ed)) (resent 1)
     (measured_ns
      ((setup (19000 19000)) ("clock low" (40000 40000))
       ("clock high" (40000 40000)) (hold (21000 21000))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "every edge and every sample is placed by a deadline" =
  Timing_report.print ~config ~period:standard_quarter firmware;
  [%expect
    {|
      9  in pins, 1                   phase 2  sample 2
     15  set pindirs, 1               phase -999  edge -998
     18  set pindirs, 0               phase -999  edge -998
     20  in pins, 1                   phase -999  sample -999
     22  mov pindirs, !null           phase -996  edge -995
     24  set pindirs, 1               phase -999  edge -998
     27  set pindirs, 0               phase -999  edge -998
     29  mov pindirs, null            phase -999  edge -998
     54  mov pindirs, !y              phase -997  edge -996
     56  set pindirs, 1               phase -999  edge -998
     59  set pindirs, 0               phase -999  edge -998
     62  mov pindirs, null            phase -997  edge -996
    ((words 65) (edge_jitter 0) (sample_jitter 0) (may_miss 0))
    |}]
;;

let%expect_test "the shortest quarter the program keeps up with" =
  Timing_report.print ~config ~period:8 firmware;
  [%expect
    {|
      9  in pins, 1                   phase 2  sample 2
     15  set pindirs, 1               phase -7  edge -6
     18  set pindirs, 0               phase -7  edge -6
     20  in pins, 1                   phase -7  sample -7
     22  mov pindirs, !null           phase -4  edge -3
     24  set pindirs, 1               phase -7  edge -6
     27  set pindirs, 0               phase -7  edge -6
     29  mov pindirs, null            phase -7  edge -6
     54  mov pindirs, !y              phase -5  edge -4
     56  set pindirs, 1               phase -7  edge -6
     59  set pindirs, 0               phase -7  edge -6
     62  mov pindirs, null            phase -5  edge -4
    ((words 65) (edge_jitter 0) (sample_jitter 0) (may_miss 0))
    |}]
;;

let%expect_test "a quarter of seven cycles is too short" =
  Timing_report.print ~config ~period:7 firmware;
  [%expect
    {|
      9  in pins, 1                   phase 2  sample 2
     14  wait t+                      phase -3..1  slack -1..3  MAY MISS
     15  set pindirs, 1               phase -6..-5  edge -5..-4  jitter 1
     18  set pindirs, 0               phase -6  edge -5
     20  in pins, 1                   phase -6  sample -6
     22  mov pindirs, !null           phase -3  edge -2
     24  set pindirs, 1               phase -6  edge -5
     27  set pindirs, 0               phase -6  edge -5
     29  mov pindirs, null            phase -6  edge -5
     54  mov pindirs, !y              phase -4  edge -3
     56  set pindirs, 1               phase -6  edge -5
     59  set pindirs, 0               phase -6  edge -5
     62  mov pindirs, null            phase -4  edge -3
    ((words 65) (edge_jitter 1) (sample_jitter 0) (may_miss 1))
    |}]
;;

(* a quarter of 10 us keeps every deadline and makes a 25 kHz clock, which the host will
   not have *)
let%expect_test "a clock of 25 kHz is out of the standard" =
  run ~quarter:(10_000 / cycle_ns) ~bytes:[ 0x1c ] ~cycles:26_000 ();
  [%expect
    {|
    ((host ("byte 0x1c")) (core_received ()) (resent 0)
     (measured_ns
      ((setup (9960 9960)) ("clock low" (20000 20000))
       ("clock high" (20000 20000)) (hold (10040 10040))))
     (violations ("clock high of 20000 ns" "clock low of 20000 ns"))
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
