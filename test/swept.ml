open! Core
open Protocol_emulator

let wire = Isa.num_pins

type t =
  { name : string
  ; watch : string
  ; on_wire : Program_config.t -> Program_config.t
  ; period : int option
  ; bursts : int list list
  }

let line (c : Program_config.t) = { c with out_base = wire; set_base = wire }
let bytes text = String.to_list text |> List.map ~f:(fun c -> [ Char.to_int c ])

let all =
  [ { name = "uart_tx"
    ; watch = "line"
    ; on_wire = line
    ; period = None
    ; bursts = bytes "Jane"
    }
  ; { name = "uart_tx16"
    ; watch = "line"
    ; on_wire = line
    ; period = None
    ; bursts = bytes "Jane"
    }
  ; { name = "uart_tx_host_rate"
    ; watch = "line"
    ; on_wire = line
    ; period = Some 434
    ; bursts = bytes "St"
    }
    (* SCK by side-set beside MOSI: 16 edges a byte 8 cycles apart is twice the fifo *)
  ; { name = "spi_master"
    ; watch = "mosi"
    ; on_wire = (fun c -> { c with out_base = wire; side_set_base = wire + 1 })
    ; period = None
    ; bursts = bytes "Jane"
    }
    (* TMS beside TDI and TCK after them, for the same reason *)
  ; { name = "jtag"
    ; watch = "tdi"
    ; on_wire = (fun c -> { c with out_base = wire; side_set_base = wire + 2 })
    ; period = None
    ; bursts =
        Jtag.words (Jtag.reset @ Jtag.scan_dr ~bits:16 0x6e4a) |> List.map ~f:List.return
    }
    (* 26.7 kbit/s at 48 MHz, where nine edges take twice a poll *)
  ; { name = "can"
    ; watch = "tx"
    ; on_wire =
        (fun c ->
          { c with in_base = wire; out_base = wire; set_base = wire; jmp_pin = wire })
    ; period = Some 1800
    ; bursts = [ Can.words (Can.Frame.data ~id:0x4a [ 0x61 ]) ]
    }
    (* a tick of 6.25 us at 48 MHz, for the same reason *)
  ; { name = "sent"
    ; watch = "line"
    ; on_wire = line
    ; period = Some 300
    ; bursts = [ Sent.words { status = 0; data = [ 1; 2; 3; 4; 5; 6 ] } ]
    }
  ]
;;

let not_swept =
  [ "uart_rx", "a receiver: it samples, and nothing on the chip sends to it"
  ; "spi_slave", "a slave: the master's clock moves it"
  ; "i2c_master", "open drain, which a wire does not show, and a slave has to acknowledge"
  ; "i2c_slave", "a slave: the master's clock moves it"
  ; "i2c_logger", "an I2C master: open drain, and a slave has to answer"
  ; ( "usb_tx"
    , "certified at 32 cycles a bit only, where 9 edges come in 256: the fifo holds 8" )
  ; "usb_rx", "a receiver: nothing on the chip sends to it"
  ; "usb_device", "a device: a USB host has to talk first"
  ; ( "edge_meter"
    , "toggles every 16 cycles for ever, so 9 edges come in 128: the fifo holds 8" )
  ; "ws2812", "48 edges a pixel in 600 cycles: the fifo holds 8"
  ; "ethernet", "half bits of 2 cycles: the logger needs up to 6 between edges"
  ; "one_wire", "open drain, which a wire does not show, and a slave has to answer"
  ; "ps2", "open drain, which a wire does not show, and the host holds the clock"
  ; "dshot600", "32 edges a frame in 1328 cycles: the fifo holds 8"
  ; "cec", "open drain, which a wire does not show"
  ; "uart_tx_stream", "time-triggered: it underflows, a sticky fault, once the host stops"
  ; ( "spi_master_stream"
    , "time-triggered: it underflows, a sticky fault, once the host stops" )
  ; ( "uart_tx_stamped"
    , "26 bits 8 cycles apart, and the chip's clock in them, which the model cannot know"
    )
  ; "uart_rx_host_rate", "a receiver: both_roles.ml sends to it on a wire"
  ; ( "i2c_master_standard"
    , "open drain, which a wire does not show, and a slave has to acknowledge" )
  ; ( "i2c_master_fast"
    , "open drain, which a wire does not show, and a slave has to acknowledge" )
  ; "i2c_controller_wire", "on two wires already, and both_roles.ml's target acknowledges"
  ; "i2c_target_wire", "a target: the controller's clock moves it"
  ]
  @ List.concat_map [ 0; 1; 2; 3 ] ~f:(fun n ->
    [ ( [%string "spi_cs_mode%{n#Int}"]
      , "not stamped: test/test_outside.py runs each mode against a slave of the mode, \
         and both_roles.ml against Spi_target" )
    ; [%string "spi_target_mode%{n#Int}"], "a target: the controller's clock moves it"
    ])
;;
