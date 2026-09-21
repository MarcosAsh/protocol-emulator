open! Core
open! Hardcaml
open Hardcaml_lws
open! Hardcaml_test_harness
open! Hardcaml_waveterm
open Protocol_emulator
open Firmware
open Protocol_models
open Lockstep
module Harness = Hardcaml_test_harness.Lws_harness.Make (Engine.I) (Engine.O)

let ( <--. ) = Bits.( <--. )

let%expect_test "usb tx" =
  let bit_period = 32 in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let sniffer = ref (Usb_ls.Sniffer.create ~bit_period) in
  let pending =
    ref ((0x80 :: 0xc3 :: (List.length data - 1) :: data) @ [ 0x80; 0xc3; 0; 0xff ])
  in
  let level = ref 0 in
  let host _ =
    match !pending with
    | w :: rest when !level < Machine.fifo_depth ->
      pending := rest;
      { Host.idle with tx = Some w; pop_rx = false }
    | _ -> Host.idle
  in
  let (_ : Machine.t) =
    lockstep
      ~cycles:(bit_period * 200)
      ~config:usb_config
      ~program:(assemble usb_tx)
      ~preload:[ bit_period ]
      ~inputs:(fun _ -> 0)
      ~host
      ~react:(fun m ->
        level := List.length m.tx_fifo;
        let pin p = (m.pin_out lsr p) land 1 in
        sniffer := Usb_ls.Sniffer.step !sniffer ~dp:(pin usb_dp_pin) ~dm:(pin usb_dm_pin))
      ()
  in
  print_s [%message (Usb_ls.Sniffer.packets !sniffer : int list list)];
  [%expect
    {|
    ("lockstep held" (cycles 6400))
    ("Usb_ls.Sniffer.packets (!sniffer)"
     ((195 128 6 0 1 0 0 64 0 221 148) (195 255 0 255)))
    |}]
;;

let%expect_test "usb rx" =
  let bit_period = 32 in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes data) in
  let packet = (0xc3 :: data) @ [ crc land 0xff; crc lsr 8 ] in
  let levels =
    List.init 40 ~f:(fun _ -> 1 lsl usb_rx_dm_pin)
    @ List.concat_map
        (Usb_ls.encode packet @ List.init 4 ~f:(fun _ -> Usb_ls.Line.J))
        ~f:(fun line ->
          let dp, dm =
            match line with
            | J -> 0, 1
            | K -> 1, 0
            | Se0 -> 0, 0
          in
          List.init bit_period ~f:(fun _ ->
            (dp lsl usb_rx_dp_pin) lor (dm lsl usb_rx_dm_pin)))
    |> Array.of_list
  in
  let words = ref [] in
  let (_ : Machine.t) =
    lockstep
      ~cycles:(Array.length levels)
      ~config:usb_rx_config
      ~program:(assemble (usb_rx ~half_period:(bit_period / 2)))
      ~preload:[ bit_period ]
      ~inputs:(fun n -> levels.(n))
      ~host:(fun _ -> { Host.idle with tx = None; pop_rx = true })
      ~react:(fun m ->
        match m.rx_fifo with
        | w :: _ -> words := w :: !words
        | [] -> ())
      ()
  in
  let bytes = List.rev_map !words ~f:(fun w -> w lsr 8) in
  print_s [%message (bytes : int list)];
  [%expect
    {|
    ("lockstep held" (cycles 3336))
    (bytes (128 195 128 6 0 1 0 0 64 0 221 148 140))
    |}]
;;

let%expect_test "wait rx blocks on a full fifo" =
  let program =
    assemble {|
loop:
    wait rx
    push
    add x, 1
    mov isr, x
    jmp loop
|}
  in
  let random = Splittable_random.of_int 9 in
  let host _ =
    { Host.idle with tx = None; pop_rx = Splittable_random.int random ~lo:0 ~hi:3 = 0 }
  in
  let (_ : Machine.t) =
    lockstep ~config:Program_config.default ~program ~inputs:(fun _ -> 0) ~host ()
  in
  [%expect {| ("lockstep held" (cycles 400)) |}]
;;

let%expect_test "edge meter" =
  let last = ref 0 in
  let stamps = ref [] in
  let (_ : Machine.t) =
    lockstep
      ~config:edge_meter_config
      ~program:(assemble (edge_meter ~period:16))
      ~inputs:(fun _ -> !last)
      ~host:(fun _ -> { Host.idle with tx = None; pop_rx = true })
      ~react:(fun m ->
        last := (m.pin_out lsr 5) land 1;
        match m.rx_fifo with
        | s :: _ -> stamps := s :: !stamps
        | [] -> ())
      ()
  in
  let stamps = List.rev !stamps in
  let intervals =
    List.zip_exn (List.drop stamps 1) (List.drop_last_exn stamps)
    |> List.map ~f:(fun (a, b) -> a - b)
  in
  print_s [%message (intervals : int list)];
  [%expect
    {|
    ("lockstep held" (cycles 400))
    (intervals (32 32 32 32 32 32 32 32 32 32 32))
    |}]
;;

let%expect_test "the host clears the interrupt" =
  let program = assemble {|
loop:
    irq [7]
    jmp loop
|} in
  let random = Splittable_random.of_int 4 in
  let host _ =
    { Host.idle with clear_irq = Splittable_random.int random ~lo:0 ~hi:5 = 0 }
  in
  let (_ : Machine.t) =
    lockstep
      ~cycles:200
      ~config:Program_config.default
      ~program
      ~inputs:(fun _ -> 0)
      ~host
      ()
  in
  [%expect {| ("lockstep held" (cycles 200)) |}]
;;

let%expect_test "faults and halt" =
  let program = assemble {|
    pull
    mov t, now
    wait t
    halt
|} in
  let m =
    lockstep ~cycles:12 ~config:Program_config.default ~program ~inputs:(fun _ -> 0) ()
  in
  print_s [%message (m.fault : Machine.Fault.t) (m.halted : bool)];
  [%expect
    {|
    ("lockstep held" (cycles 12))
    ((m.fault
      ((underflow true) (overflow false) (missed_deadline true) (decode false)))
     (m.halted true))
    |}]
;;

let%expect_test "a decode fault halts the core" =
  let m =
    lockstep
      ~cycles:4
      ~config:Program_config.default
      ~program:[ 0xa000; 0xe0ff ]
      ~inputs:(fun _ -> 0)
      ()
  in
  print_s [%message (m.fault : Machine.Fault.t) (m.pc : int)];
  [%expect
    {|
    ("lockstep held" (cycles 4))
    ((m.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode true)))
     (m.pc 1))
    |}]
;;

let%expect_test "waveform of a short loop" =
  let program =
    assemble
      {|
    set p, 4
    mov t, now
loop:
    wait t+
    mov pins, !pins
    jmp loop
|}
  in
  let config = { Program_config.default with in_base = 5; out_base = 5; out_count = 1 } in
  let display_rules =
    List.map [ "pc"; "now"; "t"; "stall"; "issue"; "word"; "pin_out" ] ~f:(fun name ->
      Display_rule.port_name_is ("engine$" ^ name) ~wave_format:(Bit_or Unsigned_int))
  in
  Harness.run
    ~create:(Engine.hierarchical ~memory:Flops)
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:20
        ~display_width:100
        ~wave_width:0
        waves)
    (fun (h @ local) ~inputs:i ~outputs:_ ->
      let cycle ?n () = Lws.step ?n h in
      i.clocking.clear := Bits.vdd;
      cycle ();
      i.clocking.clear := Bits.gnd;
      Engine.Config.iter2 i.config (Engine.Config.of_program_config config) ~f:( := );
      List.iteri program ~f:(fun addr word ->
        i.program_write.valid := Bits.vdd;
        i.program_write.addr <--. addr;
        i.program_write.data <--. word;
        cycle ());
      i.program_write.valid := Bits.gnd;
      i.start := Bits.vdd;
      cycle ();
      i.start := Bits.gnd;
      cycle ();
      cycle ~n:24 ();
      ());
  [%expect
    {|
    ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────────────────────────┐
    │                  ││──────────────────┬─┬─┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─            │
    │engine$pc         ││ 0                │1│2│3│4│2  │3│4│2  │3│4│2  │3│4│2  │3│4│2  │3│4            │
    │                  ││──────────────────┴─┴─┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─            │
    │                  ││────┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─            │
    │engine$now        ││ 0  │1│2│3│4│5│6│0│1│2│3│4│5│6│7│8│9│.│.│.│.│.│.│.│.│.│.│.│.│.│.│.            │
    │                  ││────┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─            │
    │                  ││────────────────────┬─┬───────┬───────┬───────┬───────┬───────┬───            │
    │engine$t          ││ 0                  │1│5      │9      │13     │17     │21     │25             │
    │                  ││────────────────────┴─┴───────┴───────┴───────┴───────┴───────┴───            │
    │                  ││──────────────────────────┬─┬─────┬─┬─────┬─┬─────┬─┬─────┬─┬─────            │
    │engine$stall      ││ 0                        │1│0    │1│0    │1│0    │1│0    │1│0                │
    │                  ││──────────────────────────┴─┴─────┴─┴─────┴─┴─────┴─┴─────┴─┴─────            │
    │engine$issue      ││──┐             ┌─────────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────            │
    │                  ││  └─────────────┘         └─┘     └─┘     └─┘     └─┘     └─┘                 │
    │                  ││────────────────┬─┬─┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬─            │
    │engine$word       ││ 0              │.│.│.│.│2  │.│.│2  │.│.│2  │.│.│2  │.│.│2  │.│.│2            │
    │                  ││────────────────┴─┴─┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴─            │
    │                  ││────────────────────────┬───────┬───────┬───────┬───────┬───────┬─            │
    │engine$pin_out    ││ 0                      │32     │0      │32     │0      │32     │0            │
    │                  ││────────────────────────┴───────┴───────┴───────┴───────┴───────┴─            │
    └──────────────────┘└──────────────────────────────────────────────────────────────────────────────┘
    |}]
;;

let%expect_test "random programs" =
  let random = Splittable_random.of_int 1 in
  let int hi = Splittable_random.int random ~lo:0 ~hi in
  let programs = 16 in
  let failed =
    List.init programs ~f:(fun seed ->
      let config = Random_program.config random in
      let program = Random_program.program random ~config in
      let level = ref 0 in
      let host _ =
        { Host.idle with
          tx =
            (if !level < Machine.fifo_depth && int 3 = 0 then Some (int 0xffff) else None)
        ; pop_rx = int 3 = 0
        }
      in
      let react (m : Machine.t) = level := List.length m.tx_fifo in
      match
        run ~cycles:200 ~config ~program ~inputs:(fun _ -> int 0xfffff) ~host ~react ()
      with
      | _, None -> None
      | _, Some (cycle, expected, actual) ->
        print_s
          [%message
            "MISMATCH"
              (seed : int)
              (cycle : int)
              (config : Program_config.t)
              (expected : State.t)
              (actual : State.t)];
        Some seed)
    |> List.filter_opt
  in
  print_s [%message (programs : int) (failed : int list)];
  [%expect {| ((programs 16) (failed ())) |}]
;;
