open! Core
open Protocol_emulator

module Assumption = struct
  type t =
    | Nothing
    | Floor of int
    | Period of int
    | Receiver of int
end

type t =
  { name : string
  ; what : string
  ; source : string
  ; config : Program_config.t
  ; assumption : Assumption.t
  }

(* The Icepi's USB build drives IO0 and IO1's header pins with the USB lines, so I2C moves
   to IO2 and IO3, 1-Wire to IO4 and 10BASE-T to IO6 and IO7. The bench is wired once for
   every demo: CAN's TX keeps OUT1 and SWD keeps OUT2 and IO5, so the SK6812 moves to OUT3
   and the SPI masters to MOSI on OUT4, SCK on OUT5 and CS on OUT6. The CAN node's CRX is
   on IN1. *)
let neopixel = 8
let mosi = 9
let sck = 10
let sda = 14
let scl = 15
let one_wire = 16
let td_plus = 18

(* side-set bit 0 is SCK and bit 1, for Spi_cs, CS *)
let on_spi_pins (config : Program_config.t) =
  { config with out_base = mosi; set_base = mosi; side_set_base = sck }
;;

let patch source ~pattern ~with_ =
  if List.length (String.substr_index_all source ~may_overlap:false ~pattern) <> 1
  then raise_s [%message "BUG: the firmware has moved" (pattern : string)];
  String.substr_replace_first source ~pattern ~with_
;;

(* The library's reset is 80 units, 480 us at the 6 us unit: exactly the least a DS18B20
   takes. One more pass of its low loop makes it 84, 504 us. *)
let one_wire_firmware =
  patch
    (Timed_program.source One_wire.firmware)
    ~pattern:"    set x, 19\n"
    ~with_:"    set x, 20\n"
;;

(* The library's line is dominant from reset until a bit after the period, and a frame can
   follow a bit later. On a bus it goes recessive at once and stays so eleven bits after
   the period, which a node needs to join the bus. *)
let can_firmware firmware =
  patch
    (Timed_program.source firmware)
    ~pattern:
      "    wait tx\n\
      \    pull\n\
      \    mov p, osr               ; the bit period\n\
      \    mov t, now\n\
      \    add t, p\n\
      \    wait t+\n\
      \    set pins, 1              ; recessive\n"
    ~with_:
      "    set pins, 1              ; recessive\n\
      \    wait tx\n\
      \    pull\n\
      \    mov p, osr               ; the bit period\n\
      \    mov t, now\n\
      \    add t, p\n\
      \    set x, 10\n\
       bus_idle:\n\
      \    wait t+\n\
      \    jmp x--, bus_idle\n"
;;

let all =
  [ { name = "spi_master"
    ; what =
        "Firmware.spi_master ~half_period:8: SCK at 3 MHz on OUT5, MOSI on OUT4, MISO on \
         IN0, no chip select"
    ; source = Firmware.spi_master ~half_period:8
    ; config = on_spi_pins Firmware.spi_config
    ; assumption = Nothing
    }
  ; { name = "i2c_master"
    ; what =
        "Firmware.i2c_master_host_rate: the host sends the quarter, 48 cycles for 250 \
         kHz, SDA on IO2, SCL on IO3"
    ; source = Firmware.i2c_master_host_rate
    ; config =
        { Firmware.i2c_config with
          side_set_base = scl
        ; out_base = sda
        ; set_base = sda
        ; in_base = sda
        ; jmp_pin = sda
        }
    ; assumption = Floor 31
    }
  ; { name = "i2c_master_stretch"
    ; what =
        "Firmware.i2c_master_stretch_host_rate: i2c_master waiting on SCL, SDA on IO2, \
         SCL on IO3"
    ; source = Firmware.i2c_master_stretch_host_rate
    ; config =
        { Firmware.i2c_stretch_config with
          side_set_base = scl
        ; out_base = sda
        ; set_base = sda
        ; in_base = sda
        ; jmp_pin = scl
        }
    ; assumption = Floor 31
    }
  ; { name = "one_wire"
    ; what =
        "One_wire.firmware with a reset of 84 units: the host sends the unit, 288 cycles \
         for 6 us, so 504 us, on IO4"
    ; source = one_wire_firmware
    ; config =
        { One_wire.config with
          in_base = one_wire
        ; out_base = one_wire
        ; set_base = one_wire
        }
    ; assumption = Floor 5
    }
  ; { name = "can"
    ; what =
        "Can.firmware, recessive from the start and for eleven bits after the period: \
         the host sends the bit period, 96 cycles for 500 kbit/s"
    ; source = can_firmware Can.firmware
    ; config = Can.config
    ; assumption = Floor Can.shortest_period
    }
  ; { name = "can_sender"
    ; what =
        "Can_node.Sender.firmware, recessive from the start and for eleven bits after \
         the period: Can.firmware reading its ACK slot on IN1, the host sends the bit \
         period, 96 cycles for 500 kbit/s"
    ; source = can_firmware Can_node.Sender.firmware
    ; config = Can_node.Sender.config
    ; assumption = Floor Can_node.Sender.shortest_period
    }
  ; { name = "can_receiver"
    ; what =
        "Can_node.Receiver.firmware: 500 kbit/s at 48 MHz sampled 72 cycles in, CRX on \
         IN1, the ACK on OUT1"
    ; source = Timed_program.source Can_node.Receiver.firmware
    ; config = Can_node.Receiver.config
    ; assumption = Receiver Can_node.Receiver.period
    }
  ; { name = "sk6812"
    ; what =
        "Ws2812.latching ~gaps:4 ~third:17 ~tail:8: T0H 354, T1H 708, T0L 875, T1L 521 \
         ns, a bit of 1229 ns, 227 us low before a frame, on OUT3"
    ; source = Ws2812.latching ~gaps:4 ~third:17 ~tail:8
    ; config = { Ws2812.config with out_base = neopixel; set_base = neopixel }
    ; assumption = Nothing
    }
  ; { name = "start_hold"
    ; what =
        "Firmware.start_hold for engine 1: each START's hold in cycles, SDA on IO2, SCL \
         on IO3, both only listened to"
    ; source = Firmware.start_hold ~sda ~scl
    ; config = Firmware.start_hold_config ~scl
    ; assumption = Nothing
    }
  ; { name = "ethernet"
    ; what =
        "Ethernet.firmware at the Icepi's 40 MHz: the host sends a tenth of the link \
         pulse interval, 64000 cycles for 16 ms, TD+ on IO6, TD- on IO7"
    ; source = Timed_program.source Ethernet.firmware
    ; config = { Ethernet.config with out_base = td_plus; set_base = td_plus }
    ; assumption = Period Ethernet.link_tenth
    }
  ; { name = "swd"
    ; what =
        "Swd.firmware: the host sends the half period, 24 cycles for a 1 MHz SWCLK, \
         SWCLK on OUT2, SWDIO on IO5"
    ; source = Timed_program.source Swd.firmware
    ; config = Swd.config
    ; assumption = Floor Swd.shortest_half
    }
  ]
  @ List.map Spi_cs.Mode.all ~f:(fun mode ->
    let n = Spi_cs.Mode.to_int mode in
    { name = [%string "spi_cs_mode%{n#Int}"]
    ; what =
        [%string
          "Spi_cs.master in mode %{n#Int}, half period 8: SCK at 3 MHz on OUT5, MOSI on \
           OUT4, MISO on IN0, CS on OUT6 4 cycles before the first edge and 8 after the \
           last, and high 144 cycles, 3 us, between frames"]
        (* the W25Q64JV's tRES1 after ABh, kept by every frame *)
    ; source = Spi_cs.master ~mode ~half_period:8 ~setup:4 ~hold:8 ~deselect:144
    ; config = on_spi_pins Spi_cs.config
    ; assumption = Nothing
    })
;;

let find_exn name =
  match List.find all ~f:(fun t -> String.equal t.name name) with
  | Some t -> t
  | None -> raise_s [%message "no such bench firmware" (name : string)]
;;

let timed t =
  let config = t.config in
  match t.assumption with
  | Nothing -> Timed_program.of_source_exn ~config t.source
  | Floor period_floor -> Timed_program.of_source_exn ~period_floor ~config t.source
  | Period period -> Timed_program.of_source_exn ~period ~config t.source
  | Receiver period ->
    Timed_program.of_source_exn ~period ~single_capture_edge:true ~config t.source
;;
