open! Core
open Protocol_emulator
open Firmware
open Protocol_models
open Pin_trace
module Reg = Host_port.Reg

(* bits of 16 cycles: 3 Mbaud at 48 MHz *)
let clock_hz = 48_000_000

let uart ?(teeth = []) ~channel ~pin bytes =
  { Sigrok.clock_hz
  ; decoders =
      [ Sigrok.decoder
          "uart"
          ~pins:[ channel, pin ]
          ~options:[ "baudrate", Int.to_string (clock_hz / 16) ]
      ]
  ; expect =
      [ [%string "uart=%{channel}-data"], List.map bytes ~f:(sprintf "uart-1: %02X") ]
  ; joins_after = None
  ; rejected = None
  ; teeth
  }
;;

let uart_tx =
  { Scenario.name = "uart_tx"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:Program_config.default
        ~program:(assemble (uart_tx ~period:16)) ()
      @ [ Write (Reg.tx, [ 0x55; 0xa3 ]); Scenario.start; Run 400; Read (Reg.status, 1) ]
  ; sigrok =
      (* the first stop bit, edge 10, 12 cycles late: sampled low, a framing error *)
      Some
        (uart
           ~channel:"tx"
           ~pin:Program_config.default.out_base
           ~teeth:
             [ [ Shift { pin = Program_config.default.out_base; edge = 10; cycles = 12 } ]
             ]
           [ 0x55; 0xa3 ])
  }
;;

(* A read frame ends with the next rx head on miso; after emptying the fifo that is
   unwritten RAM, zero here but X in Verilog. So the host always leaves a word behind. *)
let uart_rx =
  let period = 16 in
  let first = [ 0x55; 0xa3; 0xff; 0x00 ]
  and second = [ 0x0f; 0xf0; 0x5a ] in
  let drive bytes =
    Step.Drive { pin = 0; levels = serial_levels bytes ~period ~stop:1 }
  in
  { Scenario.name = "uart_rx"
  ; peer = (fun () -> Peer.idle 1)
  ; script =
      Scenario.load
        ~assumptions:{ System_lockstep.Assumptions.none with single_capture_edge = true }
        ~config:rx_config
        ~program:(assemble (uart_rx ~period))
        ()
      @ [ Scenario.start
        ; drive first
        ; Read (Reg.rx, 3)
        ; drive second
        ; Read (Reg.rx, 3)
        ; Read (Reg.status, 1)
        ]
  ; sigrok =
      (* the first stop bit, edge 9, 12 cycles late: a framing error *)
      Some
        (uart
           ~channel:"rx"
           ~pin:rx_config.in_base
           ~teeth:[ [ Shift { pin = rx_config.in_base; edge = 9; cycles = 12 } ] ]
           (first @ second))
  }
;;

let spi_master =
  let sent = [ 0xa5; 0x3c; 0x0f ]
  and replies = [ 0x81; 0x7e; 0x42 ] in
  let peer () =
    let slave = ref (Spi_slave.create replies) in
    { Peer.inputs = (fun () -> Spi_slave.miso !slave lsl miso_pin)
    ; step =
        (fun ~pin_out ~pin_dir:_ ->
          slave
          := Spi_slave.step
               !slave
               ~sck:(Peer.bit pin_out sck_pin)
               ~mosi:(Peer.bit pin_out mosi_pin))
    }
  in
  { Scenario.name = "spi_master"
  ; peer
  ; script =
      Scenario.load ~config:spi_config ~program:(assemble (spi_master ~half_period:8)) ()
      @ [ Write (Reg.tx, sent)
        ; Scenario.start
        ; Run 600
        ; Read (Reg.rx, 2)
        ; Read (Reg.status, 1)
        ]
  ; sigrok =
      Some
        { clock_hz
        ; decoders =
            [ Sigrok.decoder
                "spi"
                ~pins:[ "clk", sck_pin; "mosi", mosi_pin; "miso", miso_pin ]
            ]
        ; expect =
            [ "spi=mosi-data", List.map sent ~f:(sprintf "spi-1: %02X")
            ; "spi=miso-data", List.map replies ~f:(sprintf "spi-1: %02X")
            ]
        ; joins_after = None
        ; rejected = None
        ; (* a bit of the first reply inverted *)
          teeth = [ [ Flip { pin = miso_pin; edge = 0; after = 0; cycles = 16 } ] ]
        }
  }
;;

let i2c_logger =
  let memory = List.init 16 ~f:(fun i -> 0x10 + (0x11 * i)) in
  (* the reads that end inside the trace *)
  let read = List.take memory 4 in
  let peer () =
    let slave = ref (I2c_slave.create ~address:0x50 ~memory:(Array.of_list memory)) in
    let bus_sda = ref 1
    and bus_scl = ref 1 in
    { Peer.inputs = (fun () -> (!bus_sda lsl sda) lor (!bus_scl lsl scl))
    ; step =
        (fun ~pin_out:_ ~pin_dir ->
          bus_sda := if I2c_slave.drive_low !slave then 0 else 1 - Peer.bit pin_dir sda;
          bus_scl := 1 - Peer.bit pin_dir scl;
          slave := I2c_slave.step !slave ~sda:!bus_sda ~scl:!bus_scl)
    }
  in
  { Scenario.name = "i2c_logger"
  ; peer
  ; script =
      Scenario.load ~config:i2c_logger_config ~program:(Timed_program.words i2c_logger) ()
      @ [ Scenario.start; Run 3000; Read (Reg.status, 1) ]
  ; sigrok =
      Some
        { clock_hz
        ; decoders =
            [ Sigrok.decoder "i2c" ~pins:[ "scl", scl; "sda", sda ]
            ; Sigrok.decoder
                "uart"
                ~pins:[ "tx", logger_uart_pin ]
                ~options:[ "baudrate", Int.to_string (clock_hz / 16) ]
            ]
        ; expect =
            [ ( "i2c=start:address-read:ack:data-read:nack:stop"
              , List.concat_map read ~f:(fun byte ->
                  [ "Start"
                  ; "Read"
                  ; "Address read: 50"
                  ; "ACK"
                  ; sprintf "Data read: %02X" byte
                  ; "NACK"
                  ; "Stop"
                  ])
                |> List.map ~f:(( ^ ) "i2c-1: ") )
            ; "uart=tx-data", List.map read ~f:(sprintf "uart-1: %02X")
            ]
        ; joins_after = None
        ; rejected = None
        ; (* edge 6 is the slave's ACK of the first address: a NACK instead *)
          teeth = [ [ Flip { pin = sda; edge = 6; after = 0; cycles = 32 } ] ]
        }
  }
;;

let wrapped_loop =
  let program =
    assemble
      {|
    set p, 2
    mov t, now
    add t, p
.wrap_target
    wait t+
    mov pins, !pins
.wrap
|}
  in
  { Scenario.name = "wrapped_loop"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:{ Program_config.default with in_base = 5; wrap_bottom = 3; wrap_top = 4 }
        ~program ()
      @ [ Scenario.start; Run 60; Read (Reg.status, 1) ]
  ; sigrok = None
  }
;;

let fifo_poll =
  let program = assemble (List.hd_exn Fifo_poll.programs) in
  let traffic words =
    List.concat_map words ~f:(fun word ->
      [ Step.Write (Reg.tx, [ word ]); Run (word land 7); Read (Reg.status, 1) ])
  in
  { Scenario.name = "fifo_poll"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load ~config:{ Program_config.default with in_base = 5 } ~program ()
      @ [ Scenario.start ]
      @ traffic [ 0x1234; 0xbeef; 0x0001 ]
      @ [ Step.Read (Reg.rx, 2) ]
      @ traffic [ 0xffff; 0x8000; 0x7a5c; 0x0ff0 ]
      @ [ Read (Reg.rx, 3); Write (Reg.tx, [ 1; 2 ]); Read (Reg.rx, 2); Read (Reg.pc, 1) ]
  ; sigrok = None
  }
;;

let all = [ uart_tx; uart_rx; spi_master; i2c_logger; wrapped_loop; fifo_poll ]
