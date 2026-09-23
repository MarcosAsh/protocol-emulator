open! Core
open Protocol_emulator
open Jtag

let half_period = 10

(* reset, read the IDCODE, write the user register twice and read the first value back
   through the second scan, then select BYPASS, which delays TDI by one clock *)
let scans =
  [ `Reset, reset
  ; `Dr "idcode", scan_dr ~bits:32 0
  ; `Ir, scan_ir ~bits:4 0x2
  ; `Dr "user was", scan_dr ~bits:8 0xa5
  ; `Dr "user was", scan_dr ~bits:8 0x3c
  ; `Ir, scan_ir ~bits:4 0xf
  ; `Dr "bypass of 0xb6", scan_dr ~bits:9 0xb6
  ]
;;

let clocks = List.concat_map scans ~f:snd
let schedule = words clocks

(* the value each data scan shifted out, found at its place in the whole sequence *)
let results ~pushed =
  List.fold scans ~init:(0, []) ~f:(fun (first, results) (kind, clocks) ->
    let results =
      match kind with
      | `Dr name ->
        let bits = List.length clocks - 5 in
        let value = shifted_out ~pushed ~first:(first + dr_shift_offset) ~bits in
        (name, value) :: results
      | `Reset | `Ir -> results
    in
    first + List.length clocks, results)
  |> snd
  |> List.rev
;;

let pins (m : Machine.t) =
  let bit pin = (m.pin_out lsr pin) land 1 in
  bit tck_pin, bit tms_pin, bit tdi_pin
;;

let print ~pushed tap (fault : Machine.Fault.t) =
  print_s
    [%message
      ""
        ~pushed:(List.length pushed : int)
        ~results:(results ~pushed : (string * Int.Hex.t) list)
        ~user:(Tap.user tap : Int.Hex.t)
        ~measured_ns:(Tap.measured tap : Measured.t)
        ~violations:
          (Tap.violations tap |> List.dedup_and_sort ~compare:String.compare
           : string list)
        (fault : Machine.Fault.t)]
;;

let cycles = 4_000

let%expect_test "a TAP reads its IDCODE and keeps what the user register was given" =
  let t =
    Machine.create ~config ~program:(Firmware.assemble (firmware ~half_period)) |> ok_exn
  in
  let rec loop (t : Machine.t) tap schedule pushed n =
    if n = cycles
    then t, tap, List.rev pushed
    else (
      let t, schedule =
        match schedule with
        | word :: rest when List.length t.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx t word |> ok_exn, rest
        | schedule -> t, schedule
      in
      let t = Machine.step t ~inputs:(Tap.tdo tap lsl tdo_pin) in
      let tck, tms, tdi = pins t in
      let tap = Tap.step tap ~tck ~tms ~tdi in
      let pushed, t =
        match Machine.read_rx t with
        | Some (word, t) -> word :: pushed, t
        | None -> pushed, t
      in
      loop t tap schedule pushed (n + 1))
  in
  let t, tap, pushed = loop t (Tap.create ~cycle_ns) schedule [] 0 in
  print ~pushed tap t.fault;
  [%expect
    {|
    ((pushed 13)
     (results
      ((idcode 0x4ba00477) ("user was" 0x0) ("user was" 0xa5)
       ("bypass of 0xb6" 0x16c)))
     (user 0x3c)
     (measured_ns
      ((setup (200 14600)) ("TCK high" (200 200)) ("TCK low" (200 600))
       (hold (200 600))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* the host pops every word the core pushes, so the rx fifo never fills *)
let%expect_test "jtag in lockstep" =
  let tap = ref (Tap.create ~cycle_ns) in
  let schedule = ref schedule in
  let tx_level = ref 0 in
  let model =
    Lockstep.lockstep
      ~cycles
      ~config
      ~program:(Firmware.assemble (firmware ~half_period))
      ~inputs:(fun _ -> Tap.tdo !tap lsl tdo_pin)
      ~host:(fun _ ->
        match !schedule with
        | word :: rest when !tx_level < Machine.fifo_depth ->
          schedule := rest;
          { Lockstep.Host.idle with tx = Some word; pop_rx = true }
        | _ -> { Lockstep.Host.idle with pop_rx = true })
      ~react:(fun m ->
        tx_level := List.length m.tx_fifo;
        let tck, tms, tdi = pins m in
        tap := Tap.step !tap ~tck ~tms ~tdi)
      ()
  in
  print_s [%message (Tap.user !tap : Int.Hex.t) (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ("lockstep held" (cycles 4000))
    (("Tap.user (!tap)" 0x3c)
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "every edge is placed by a deadline" =
  Timing_report.print ~config (firmware ~half_period);
  [%expect
    {|
      0  set p, 10 side 0             phase ?..?  side ?..?  jitter ?
      7  out pins, 2 side 0           phase -9  edge -8  gap ?..?
      9  in pins, 1 side 1            phase -9  sample -9  side -8
     11  out pins, 2 side 0           phase -9  edge -8  side -8  gap 18..22
    ((words 15) (edge_jitter 0) (sample_jitter 0) (side_jitter unbounded)
     (may_miss 0))
    |}]
;;

let%expect_test "the shortest half period" =
  let check half_period =
    Analyser.check ~config (Asm.assemble (firmware ~half_period) |> ok_exn)
    |> Or_error.is_ok
  in
  print_s [%message (check shortest_half : bool) (check (shortest_half - 1) : bool)];
  [%expect {| (("check shortest_half" true) ("check (shortest_half - 1)" false)) |}]
;;
