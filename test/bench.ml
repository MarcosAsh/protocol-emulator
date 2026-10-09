open! Core
open Protocol_emulator

module Assumption = struct
  type t =
    | Nothing
    | Floor of int
    | Period of int
    | Receiver of int
end

module Stimulus = struct
  type t =
    { bursts : int list list
    ; quiet : int
    ; cycles : int
    }
end

type t =
  { name : string
  ; what : string
  ; source : string
  ; config : Program_config.t
  ; assumption : Assumption.t
  ; clock_hz : int
  ; load : int option
  ; stimulus : Stimulus.t option
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

(* The Icepi's PLL and the demo board's [clock_hz] both run the chip at 48 MHz; 10BASE-T
   needs the Icepi's 40 MHz build. *)
let clock_hz = 48_000_000
let ethernet_clock_hz = 40_000_000
let bit ~hz = clock_hz / hz
let half ~hz = clock_hz / (2 * hz)
let quarter ~hz = clock_hz / (4 * hz)
let cycles_in ~us = clock_hz / 1_000_000 * us

(* labels from the cycles and the clock, never written by hand *)
let time ?(clock_hz = clock_hz) cycles =
  let ns = Float.of_int cycles *. 1e9 /. Float.of_int clock_hz in
  if Float.(ns < 1e3)
  then sprintf "%.0f ns" ns
  else if Float.(ns < 1e6)
  then sprintf "%.4g us" (ns /. 1e3)
  else sprintf "%.4g ms" (ns /. 1e6)
;;

let rate ?(clock_hz = clock_hz) ?(unit = "Hz") cycles =
  let hz = Float.of_int clock_hz /. Float.of_int cycles in
  if Float.(hz >= 1e6)
  then sprintf "%.4g M%s" (hz /. 1e6) unit
  else sprintf "%.4g k%s" (hz /. 1e3) unit
;;

let spi_half = 8
let one_wire_unit = cycles_in ~us:6
let can_bit = bit ~hz:500_000
let swd_half = half ~hz:1_000_000

(* SK6812, 012 B/0: a bit of 1.2 us at least and a reset of 200 us *)
let sk6812_third = 17
let sk6812_tail = 8
let sk6812_gaps = (cycles_in ~us:200 / (160 * sk6812_third)) + 1

let can_stimulus =
  { Stimulus.bursts = [ Can.words (Can.Frame.data ~id:0x4a [ 0x61 ]) ]
  ; quiet = 0
  ; cycles = 20_000
  }
;;

let others =
  [ { name = "one_wire"
    ; what =
        [%string
          "One_wire.firmware with a reset of 84 units: the host sends the unit, \
           %{one_wire_unit#Int} cycles for %{time one_wire_unit}, so %{time (84 * \
           one_wire_unit)}, on IO4"]
    ; source = one_wire_firmware
    ; config =
        { One_wire.config with
          in_base = one_wire
        ; out_base = one_wire
        ; set_base = one_wire
        }
    ; assumption = Floor 5
    ; clock_hz
    ; load = Some one_wire_unit
    ; stimulus =
        Some
          { bursts = [ One_wire.[ reset; byte 0x00; byte 0xa5; byte 0xff ] ]
          ; quiet = 0
          ; cycles = 200_000
          }
    }
  ; { name = "can"
    ; what =
        [%string
          "Can.firmware, recessive from the start and for eleven bits after the period: \
           the host sends the bit period, %{can_bit#Int} cycles for %{rate \
           ~unit:\"bit/s\" can_bit}"]
    ; source = can_firmware Can.firmware
    ; config = Can.config
    ; assumption = Floor Can.shortest_period
    ; clock_hz
    ; load = Some can_bit
    ; stimulus = Some can_stimulus
    }
  ; { name = "can_sender"
    ; what =
        [%string
          "Can_node.Sender.firmware, recessive from the start and for eleven bits after \
           the period: Can.firmware reading its ACK slot on IN1, the host sends the bit \
           period, %{can_bit#Int} cycles for %{rate ~unit:\"bit/s\" can_bit}"]
    ; source = can_firmware Can_node.Sender.firmware
    ; config = Can_node.Sender.config
    ; assumption = Floor Can_node.Sender.shortest_period
    ; clock_hz
    ; load = Some can_bit
    ; stimulus = Some can_stimulus
    }
  ; { name = "can_receiver"
    ; what =
        [%string
          "Can_node.Receiver.firmware: %{rate ~unit:\"bit/s\" Can_node.Receiver.period} \
           sampled %{Can_node.Receiver.sample#Int} cycles in, CRX on IN1, the ACK on \
           OUT1"]
    ; source = Timed_program.source Can_node.Receiver.firmware
    ; config = Can_node.Receiver.config
    ; assumption = Receiver Can_node.Receiver.period
    ; clock_hz
    ; load = Some Can_node.Receiver.period
    ; stimulus = None
    }
  ; { name = "sk6812"
    ; what =
        (let third = sk6812_third
         and tail = sk6812_tail in
         [%string
           "Ws2812.latching ~gaps:%{sk6812_gaps#Int} ~third:%{third#Int} \
            ~tail:%{tail#Int}: T0H %{time third}, T1H %{time (2 * third)}, T0L %{time \
            ((2 * third) + tail)}, T1L %{time (third + tail)}, a bit of %{time ((3 * \
            third) + tail)}, %{time (sk6812_gaps * 160 * third)} low before a frame, on \
            OUT3"])
    ; source = Ws2812.latching ~gaps:sk6812_gaps ~third:sk6812_third ~tail:sk6812_tail
    ; config = { Ws2812.config with out_base = neopixel; set_base = neopixel }
    ; assumption = Nothing
    ; clock_hz
    ; load = None
    ; stimulus =
        (let pixels =
           List.concat_map
             [ { Ws2812.Pixel.red = 0x0f; green = 0xf0; blue = 0x55 }
             ; { red = 0xaa; green = 0x33; blue = 0xcc }
             ]
             ~f:Ws2812.Pixel.words
         in
         Some { bursts = [ pixels; pixels; pixels ]; quiet = 200; cycles = 60_000 })
    }
  ; { name = "start_hold"
    ; what =
        "Firmware.start_hold for engine 1: each START's hold in cycles, SDA on IO2, SCL \
         on IO3, both only listened to"
    ; source = Firmware.start_hold ~sda ~scl
    ; config = Firmware.start_hold_config ~scl
    ; assumption = Nothing
    ; clock_hz
    ; load = None
    ; stimulus = None
    }
  ; { name = "ethernet"
    ; what =
        [%string
          "Ethernet.firmware at the Icepi's 40 MHz: the host sends a tenth of the link \
           pulse interval, %{Ethernet.link_tenth#Int} cycles for %{time \
           ~clock_hz:ethernet_clock_hz (10 * Ethernet.link_tenth)}, TD+ on IO6, TD- on \
           IO7"]
    ; source = Timed_program.source Ethernet.firmware
    ; config = { Ethernet.config with out_base = td_plus; set_base = td_plus }
    ; assumption = Period Ethernet.link_tenth
    ; clock_hz = ethernet_clock_hz
    ; load = Some Ethernet.link_tenth
    ; stimulus = None
    }
  ; { name = "swd"
    ; what =
        [%string
          "Swd.firmware: the host sends the half period, %{swd_half#Int} cycles for a \
           %{rate (2 * swd_half)} SWCLK, SWCLK on OUT2, SWDIO on IO5"]
    ; source = Timed_program.source Swd.firmware
    ; config = Swd.config
    ; assumption = Floor Swd.shortest_half
    ; clock_hz
    ; load = Some swd_half
    ; stimulus = None
    }
  ]
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

let period t =
  match t.assumption with
  | Period period | Receiver period -> Some period
  | Nothing | Floor _ -> t.load
;;
