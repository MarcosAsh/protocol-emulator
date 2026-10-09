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

let others =
  [ (* TMS beside TDI and TCK after them, for the reason [Spi]'s SCK is beside MOSI *)
    { name = "jtag"
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
  [ ( "usb_tx"
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
  ]
;;
