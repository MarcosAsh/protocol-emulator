open! Core
open! Hardcaml
open Hardcaml_lws
open! Hardcaml_test_harness
open! Hardcaml_waveterm
open Protocol_emulator
open Firmware
open Protocol_models
module Harness = Hardcaml_test_harness.Lws_harness.Make (Engine.I) (Engine.O)

let debug = false
let ( <--. ) = Bits.( <--. )

module State = struct
  type t =
    { pc : int
    ; x : int
    ; y : int
    ; p : int
    ; t : int
    ; osr : int
    ; osr_count : int
    ; isr : int
    ; isr_count : int
    ; now : int
    ; pin_out : int
    ; pin_dir : int
    ; stall : int
    ; halted : bool
    ; irq : bool
    ; fault : Machine.Fault.t
    ; capture : int
    ; capture_armed : bool
    ; tx_level : int
    ; rx_level : int
    ; rx_head : int option
    ; crc : int
    ; stuff_run : int
    }
  [@@deriving sexp_of, compare, equal]

  let of_machine (m : Machine.t) =
    { pc = m.pc
    ; x = m.x
    ; y = m.y
    ; p = m.p
    ; t = m.t
    ; osr = m.osr
    ; osr_count = m.osr_count
    ; isr = m.isr
    ; isr_count = m.isr_count
    ; now = m.now
    ; pin_out = m.pin_out
    ; pin_dir = m.pin_dir
    ; stall = m.stall
    ; halted = m.halted
    ; irq = m.irq
    ; fault = m.fault
    ; capture = m.capture
    ; capture_armed = m.capture_armed
    ; tx_level = List.length m.tx_fifo
    ; rx_level = List.length m.rx_fifo
    ; rx_head = List.hd m.rx_fifo
    ; crc = m.crc
    ; stuff_run = m.stuff_run
    }
  ;;

  let of_outputs (o : Bits.t ref Engine.O.t) =
    let int r = Bits.to_unsigned_int !r in
    let bool r = Bits.to_bool !r in
    let rx_level = int o.rx_level in
    { pc = int o.pc
    ; x = int o.x
    ; y = int o.y
    ; p = int o.p
    ; t = int o.t
    ; osr = int o.osr
    ; osr_count = int o.osr_count
    ; isr = int o.isr
    ; isr_count = int o.isr_count
    ; now = int o.now
    ; pin_out = int o.pin_out
    ; pin_dir = int o.pin_dir
    ; stall = int o.stall
    ; halted = bool o.halted
    ; irq = bool o.irq
    ; fault =
        { underflow = bool o.fault.underflow
        ; overflow = bool o.fault.overflow
        ; missed_deadline = bool o.fault.missed_deadline
        ; decode = bool o.fault.decode
        }
    ; capture = int o.capture
    ; capture_armed = bool o.capture_armed
    ; tx_level = int o.tx_level
    ; rx_level
    ; rx_head = (if rx_level = 0 then None else Some (int o.rx_head))
    ; crc = int o.crc
    ; stuff_run = int o.stuff_run
    }
  ;;
end

module Host = struct
  type t =
    { tx : int option
    ; pop_rx : bool
    }

  let idle = { tx = None; pop_rx = false }
end

let run
  ?(cycles = 400)
  ?(preload = [])
  ?(host = fun _ -> Host.idle)
  ?(react = fun (_ : Machine.t) -> ())
  ~config
  ~program
  ~inputs
  ()
  =
  Harness.run
    ~waves_config:
      (if debug then Waves_config.to_home_subdirectory () else Waves_config.no_waves)
    ~random_initial_state:`All
    ~create:(Engine.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
      let cycle () = Hardcaml_lws.Lws.cycle h in
      let after () = Before_and_after_edge.after_edge outputs in
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
      let model = ref (Machine.create ~config ~program |> ok_exn) in
      List.iter preload ~f:(fun word ->
        i.tx.valid := Bits.vdd;
        i.tx.value <--. word;
        cycle ();
        model := Machine.write_tx !model word |> ok_exn);
      i.tx.valid := Bits.gnd;
      i.start := Bits.vdd;
      cycle ();
      i.start := Bits.gnd;
      cycle ();
      let mismatch = ref None in
      let cycle_number = ref 0 in
      while !cycle_number < cycles && Option.is_none !mismatch do
        let n = !cycle_number in
        let expected = State.of_machine !model in
        let actual = State.of_outputs (after ()) in
        if not (State.equal expected actual)
        then mismatch := Some (n, expected, actual)
        else (
          let levels = inputs n in
          let action = host n in
          i.inputs <--. levels;
          (match action.tx with
           | Some word ->
             i.tx.valid := Bits.vdd;
             i.tx.value <--. word
           | None -> i.tx.valid := Bits.gnd);
          i.rx_pop := Bits.of_bool action.pop_rx;
          if action.pop_rx
          then (
            match Machine.read_rx !model with
            | Some (_, m) -> model := m
            | None -> ());
          cycle ();
          model := Machine.step !model ~inputs:levels;
          (match action.tx with
           | Some word -> model := Machine.write_tx !model word |> ok_exn
           | None -> ());
          react !model;
          Int.incr cycle_number)
      done;
      !model, !mismatch)
;;

let lockstep ?(cycles = 400) ?preload ?host ?react ~config ~program ~inputs () =
  let model, mismatch = run ~cycles ?preload ?host ?react ~config ~program ~inputs () in
  (match mismatch with
   | None -> print_s [%message "lockstep held" (cycles : int)]
   | Some (cycle, expected, actual) ->
     print_s [%message "MISMATCH" (cycle : int) (expected : State.t) (actual : State.t)]);
  model
;;

let%expect_test "uart tx" =
  let program = assemble (uart_tx ~period:16) in
  let (_ : Machine.t) =
    lockstep
      ~config:Program_config.default
      ~program
      ~preload:[ 0x55; 0xa3 ]
      ~inputs:(fun _ -> 0)
      ()
  in
  [%expect {| ("lockstep held" (cycles 400)) |}]
;;

let%expect_test "uart tx at 115200 baud" =
  let (_ : Machine.t) =
    lockstep
      ~cycles:(24 * 434)
      ~config:Program_config.default
      ~program:(assemble uart_tx_host_rate)
      ~preload:[ 434; 0x55; 0xa3 ]
      ~inputs:(fun _ -> 0)
      ()
  in
  [%expect {| ("lockstep held" (cycles 10416)) |}]
;;

let%expect_test "uart rx" =
  let period = 16 in
  let levels =
    serial_levels [ 0x55; 0xa3; 0xff; 0x00 ] ~period ~stop:1 |> Array.of_list
  in
  let (_ : Machine.t) =
    lockstep
      ~cycles:(Array.length levels)
      ~config:rx_config
      ~program:(assemble (uart_rx ~period))
      ~inputs:(fun n -> levels.(n))
      ~host:(fun _ -> { Host.idle with pop_rx = true })
      ()
  in
  [%expect {| ("lockstep held" (cycles 724)) |}]
;;

let%expect_test "spi master" =
  let slave = ref (Spi_slave.create [ 0x81; 0x7e ]) in
  let (_ : Machine.t) =
    lockstep
      ~config:spi_config
      ~program:(assemble (spi_master ~half_period:8))
      ~preload:[ 0xa5; 0x3c ]
      ~inputs:(fun _ -> Spi_slave.miso !slave lsl miso_pin)
      ~react:(fun m ->
        slave
        := Spi_slave.step
             !slave
             ~sck:((m.pin_out lsr sck_pin) land 1)
             ~mosi:((m.pin_out lsr mosi_pin) land 1))
      ()
  in
  let received = Spi_slave.received !slave in
  print_s [%message (received : int list)];
  [%expect {|
    ("lockstep held" (cycles 400))
    (received (165 60))
    |}]
;;

let%expect_test "spi slave" =
  let master = ref (Spi_peer.create ~half_period:4 [ 0xa5; 0x3c; 0xf0 ]) in
  let (_ : Machine.t) =
    lockstep
      ~config:spi_slave_config
      ~program:(assemble spi_slave)
      ~preload:(List.map [ 0x81; 0x7e; 0x11; 0 ] ~f:(fun reply -> reply lsl 8))
      ~inputs:(fun _ ->
        (Spi_peer.sck !master lsl slave_sck_pin)
        lor (Spi_peer.mosi !master lsl slave_mosi_pin))
      ~react:(fun m ->
        master := Spi_peer.step !master ~miso:((m.pin_out lsr slave_miso_pin) land 1))
      ()
  in
  let received = Spi_peer.received !master in
  print_s [%message (received : int list)];
  [%expect {|
    ("lockstep held" (cycles 400))
    (received (129 126 17))
    |}]
;;

let%expect_test "i2c master" =
  let memory = Array.create ~len:16 0 in
  let slave = ref (I2c_slave.create ~address:0x50 ~memory) in
  let words =
    [ i2c_word ~start:true 0xa0; i2c_word 3; i2c_word ~stop:true 0xaa ] |> ref
  in
  let bus (m : Machine.t) =
    let master_sda = 1 - ((m.pin_dir lsr sda) land 1) in
    let bus_sda = if I2c_slave.drive_low !slave then 0 else master_sda in
    let bus_scl = 1 - ((m.pin_dir lsr scl) land 1) in
    bus_sda, bus_scl
  in
  let model = ref None in
  let (_ : Machine.t) =
    lockstep
      ~cycles:1500
      ~config:i2c_config
      ~program:(assemble (i2c_master ~quarter:8))
      ~inputs:(fun _ ->
        match !model with
        | None -> (1 lsl sda) lor (1 lsl scl)
        | Some m ->
          let bus_sda, bus_scl = bus m in
          (bus_sda lsl sda) lor (bus_scl lsl scl))
      ~host:(fun _ ->
        match !words with
        | w :: rest ->
          words := rest;
          { Host.tx = Some w; pop_rx = true }
        | [] -> { Host.idle with pop_rx = true })
      ~react:(fun m ->
        let bus_sda, bus_scl = bus m in
        slave := I2c_slave.step !slave ~sda:bus_sda ~scl:bus_scl;
        model := Some m)
      ()
  in
  let log = I2c_slave.log !slave in
  print_s [%message (log : string list) (memory : int array)];
  [%expect
    {|
    ("lockstep held" (cycles 1500))
    ((log (start "address 80 write" "pointer 3" "write 170" stop))
     (memory (0 0 0 170 0 0 0 0 0 0 0 0 0 0 0 0)))
    |}]
;;

let%expect_test "i2c slave" =
  let master =
    ref
      (I2c_peer.create
         ~quarter:8
         [ Start
         ; Write 0xa0
         ; Write 3
         ; Start
         ; Write 0xa1
         ; Read { ack = true }
         ; Read { ack = false }
         ; Stop
         ])
  in
  let bus_sda (m : Machine.t) =
    I2c_peer.sda !master land (1 - ((m.pin_dir lsr sda) land 1))
  in
  let last_sda = ref 1 in
  let model =
    lockstep
      ~cycles:3000
      ~config:i2c_slave_config
      ~program:(assemble i2c_slave)
      ~preload:[ 0x50 lsl 1; 0x12; 0x34 ]
      ~inputs:(fun _ -> (!last_sda lsl sda) lor (I2c_peer.scl !master lsl scl))
      ~react:(fun m ->
        last_sda := bus_sda m;
        master := I2c_peer.step !master ~sda:!last_sda)
      ()
  in
  print_s
    [%message
      (I2c_peer.log !master : string list)
        (List.length model.rx_fifo : int)
        (model.pc : int)];
  [%expect
    {|
    ("lockstep held" (cycles 3000))
    (("I2c_peer.log (!master)" (ack ack ack "read 18" "read 52"))
     ("List.length model.rx_fifo" 3) (model.pc 4))
    |}]
;;

let%expect_test "i2c logger" =
  let memory = Array.init 16 ~f:(fun i -> 0x10 + (0x11 * i)) in
  let slave = ref (I2c_slave.create ~address:0x50 ~memory) in
  let levels = ref [] in
  let bus_sda (m : Machine.t) =
    if I2c_slave.drive_low !slave then 0 else 1 - ((m.pin_dir lsr sda) land 1)
  in
  let last_sda = ref 1 in
  let last_scl = ref 1 in
  let (_ : Machine.t) =
    lockstep
      ~cycles:3000
      ~config:i2c_logger_config
      ~program:(assemble i2c_logger)
      ~inputs:(fun _ -> (!last_sda lsl sda) lor (!last_scl lsl scl))
      ~react:(fun m ->
        last_sda := bus_sda m;
        last_scl := 1 - ((m.pin_dir lsr scl) land 1);
        slave := I2c_slave.step !slave ~sda:!last_sda ~scl:!last_scl;
        levels := ((m.pin_out lsr logger_uart_pin) land 1) :: !levels)
      ()
  in
  let logged = decode_uart (List.rev !levels) ~period:16 in
  print_s [%message (logged : int list) (I2c_slave.log !slave : string list)];
  [%expect
    {|
    ("lockstep held" (cycles 3000))
    ((logged (16 33 50))
     ("I2c_slave.log (!slave)"
      (start "address 80 read" nack stop start "address 80 read" nack stop start
       "address 80 read" nack stop start "address 80 read" nack)))
    |}]
;;

let%expect_test "usb tx" =
  let bit_period = 32 in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let sniffer = ref (Usb_ls.Sniffer.create ~bit_period) in
  let pending = ref (0x80 :: 0xc3 :: (List.length data - 1) :: data) in
  let level = ref 0 in
  let host _ =
    match !pending with
    | w :: rest when !level < Machine.fifo_depth ->
      pending := rest;
      { Host.tx = Some w; pop_rx = false }
    | _ -> Host.idle
  in
  let (_ : Machine.t) =
    lockstep
      ~cycles:(bit_period * 130)
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
    ("lockstep held" (cycles 4160))
    ("Usb_ls.Sniffer.packets (!sniffer)" ((195 128 6 0 1 0 0 64 0 221 148)))
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
      ~host:(fun _ -> { Host.tx = None; pop_rx = true })
      ~react:(fun m ->
        match m.rx_fifo with
        | w :: _ -> words := w :: !words
        | [] -> ())
      ()
  in
  let bytes = List.rev_map !words ~f:(fun w -> w lsr 8) in
  print_s [%message (bytes : int list)];
  [%expect {|
    ("lockstep held" (cycles 3336))
    (bytes (128 195 128 6 0 1 0 0 64 0 221 148 140))
    |}]
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
        { Host.tx =
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
