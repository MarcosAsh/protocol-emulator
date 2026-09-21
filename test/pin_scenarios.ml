open! Core
open Protocol_emulator
open Firmware
open Protocol_models
open Pin_trace
module Reg = Host_port.Reg

let bit levels pin = (levels lsr pin) land 1

let uart_tx =
  { Scenario.name = "uart_tx"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:Program_config.default
        ~program:(assemble (uart_tx ~period:16))
      @ [ Write (Reg.tx, [ 0x55; 0xa3 ]); Scenario.start; Run 400; Read (Reg.status, 1) ]
  }
;;

(* An rx read that empties the fifo ends with the next head on miso, and the fifo's RAM is
   undefined in the Verilog until a fifth word has gone through it. The host leaves a word
   behind until then. *)
let uart_rx =
  let period = 16 in
  let drive bytes =
    Step.Drive { pin = 0; levels = serial_levels bytes ~period ~stop:1 }
  in
  { Scenario.name = "uart_rx"
  ; peer = (fun () -> Peer.idle 1)
  ; script =
      Scenario.load ~config:rx_config ~program:(assemble (uart_rx ~period))
      @ [ Scenario.start
        ; drive [ 0x55; 0xa3; 0xff; 0x00 ]
        ; Read (Reg.rx, 3)
        ; drive [ 0x0f; 0xf0; 0x5a ]
        ; Read (Reg.rx, 3)
        ; Read (Reg.rx, 1)
        ; Read (Reg.status, 1)
        ]
  }
;;

let spi_master =
  let peer () =
    let slave = ref (Spi_slave.create [ 0x81; 0x7e ]) in
    { Peer.inputs = (fun () -> Spi_slave.miso !slave lsl miso_pin)
    ; step =
        (fun ~pin_out ~pin_dir:_ ->
          slave
          := Spi_slave.step !slave ~sck:(bit pin_out sck_pin) ~mosi:(bit pin_out mosi_pin))
    }
  in
  { Scenario.name = "spi_master"
  ; peer
  ; script =
      Scenario.load ~config:spi_config ~program:(assemble (spi_master ~half_period:8))
      @ [ Write (Reg.tx, [ 0xa5; 0x3c ])
        ; Scenario.start
        ; Run 400
        ; Read (Reg.rx, 2)
        ; Read (Reg.status, 1)
        ]
  }
;;

let i2c_logger =
  let peer () =
    let memory = Array.init 16 ~f:(fun i -> 0x10 + (0x11 * i)) in
    let slave = ref (I2c_slave.create ~address:0x50 ~memory) in
    let bus_sda = ref 1
    and bus_scl = ref 1 in
    { Peer.inputs = (fun () -> (!bus_sda lsl sda) lor (!bus_scl lsl scl))
    ; step =
        (fun ~pin_out:_ ~pin_dir ->
          bus_sda := if I2c_slave.drive_low !slave then 0 else 1 - bit pin_dir sda;
          bus_scl := 1 - bit pin_dir scl;
          slave := I2c_slave.step !slave ~sda:!bus_sda ~scl:!bus_scl)
    }
  in
  { Scenario.name = "i2c_logger"
  ; peer
  ; script =
      Scenario.load ~config:i2c_logger_config ~program:(assemble i2c_logger)
      @ [ Scenario.start; Run 3000; Read (Reg.status, 1) ]
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
        ~program
      @ [ Scenario.start; Run 60; Read (Reg.status, 1) ]
  }
;;

let fifo_poll =
  let program =
    assemble
      {|
poll:
    jmp tx, take
    mov pins, !pins
    jmp poll
take:
    pull
    jmp !rx, poll
    mov isr, osr
    push
    jmp poll
|}
  in
  let traffic words =
    List.concat_map words ~f:(fun word ->
      [ Step.Write (Reg.tx, [ word ]); Run (word land 7); Read (Reg.status, 1) ])
  in
  { Scenario.name = "fifo_poll"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load ~config:{ Program_config.default with in_base = 5 } ~program
      @ [ Scenario.start ]
      @ traffic [ 0x1234; 0xbeef; 0x0001 ]
      @ [ Step.Read (Reg.rx, 2) ]
      @ traffic [ 0xffff; 0x8000; 0x7a5c; 0x0ff0 ]
      @ [ Read (Reg.rx, 4); Write (Reg.tx, [ 1; 2 ]); Read (Reg.rx, 2); Read (Reg.pc, 1) ]
  }
;;

let all = [ uart_tx; uart_rx; spi_master; i2c_logger; wrapped_loop; fifo_poll ]
