open! Core
open! Hardcaml
open! Hardcaml_waveterm
open Protocol_emulator
open Firmware
open Protocol_models
module Harness = Hardcaml_test_harness.Lws_harness.Make (Engine.I) (Engine.O)

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

let lockstep
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
       (match !mismatch with
        | None -> print_s [%message "lockstep held" (cycles : int)]
        | Some (cycle, expected, actual) ->
          print_s
            [%message "MISMATCH" (cycle : int) (expected : State.t) (actual : State.t)]);
       !model)
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
  print_s [%message (Spi_slave.received !slave : int list)];
  [%expect
    {|
    ("lockstep held" (cycles 400))
    ("Spi_slave.received (!slave)" (165 60))
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
  print_s [%message (I2c_slave.log !slave : string list) (memory : int array)];
  [%expect
    {|
    ("lockstep held" (cycles 1500))
    (("I2c_slave.log (!slave)"
      (start "address 80 write" "pointer 3" "write 170" stop))
     (memory (0 0 0 170 0 0 0 0 0 0 0 0 0 0 0 0)))
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
      let cycle ?n () = Hardcaml_lws.Lws.cycle ?n h in
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
      cycle ~n:24 ();
      ());
  [%expect
    {|
    ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────────────────────────┐
    │                  ││────────────────┬─┬─┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─              │
    │engine$pc         ││ 0              │1│2│3│4│2  │3│4│2  │3│4│2  │3│4│2  │3│4│2  │3│4              │
    │                  ││────────────────┴─┴─┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─              │
    │                  ││────┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─              │
    │engine$now        ││ 0  │1│2│3│4│5│0│1│2│3│4│5│6│7│8│9│.│.│.│.│.│.│.│.│.│.│.│.│.│.│.              │
    │                  ││────┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─              │
    │                  ││──────────────────┬─┬───────┬───────┬───────┬───────┬───────┬───              │
    │engine$t          ││ 0                │1│5      │9      │13     │17     │21     │25               │
    │                  ││──────────────────┴─┴───────┴───────┴───────┴───────┴───────┴───              │
    │                  ││────────────────────────┬─┬─────┬─┬─────┬─┬─────┬─┬─────┬─┬─────              │
    │engine$stall      ││ 0                      │1│0    │1│0    │1│0    │1│0    │1│0                  │
    │                  ││────────────────────────┴─┴─────┴─┴─────┴─┴─────┴─┴─────┴─┴─────              │
    │engine$issue      ││──┐           ┌─────────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────              │
    │                  ││  └───────────┘         └─┘     └─┘     └─┘     └─┘     └─┘                   │
    │                  ││────┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─              │
    │engine$word       ││ 0  │.│.│.│.│2│.│.│.│.│2│83.│.│2│83.│.│2│83.│.│2│83.│.│2│83.│.│2              │
    │                  ││────┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─              │
    │                  ││──────────────────────┬───────┬───────┬───────┬───────┬───────┬─              │
    │engine$pin_out    ││ 0                    │32     │0      │32     │0      │32     │0              │
    │                  ││──────────────────────┴───────┴───────┴───────┴───────┴───────┴─              │
    └──────────────────┘└──────────────────────────────────────────────────────────────────────────────┘
    |}]
;;
