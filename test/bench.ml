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
  ; clock_hz : int
  ; load : int option
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
let i2c_quarter = quarter ~hz:250_000
let one_wire_unit = cycles_in ~us:6
let can_bit = bit ~hz:500_000
let swd_half = half ~hz:1_000_000

(* SK6812, 012 B/0: a bit of 1.2 us at least and a reset of 200 us *)
let sk6812_third = 17
let sk6812_tail = 8
let sk6812_gaps = (cycles_in ~us:200 / (160 * sk6812_third)) + 1

(* the W25Q64JV's tRES1 after ABh, kept by every frame *)
let spi_cs_deselect = cycles_in ~us:3

let all =
  [ { name = "spi_master"
    ; what =
        [%string
          "Firmware.spi_master ~half_period:%{spi_half#Int}: SCK at %{rate (2 * \
           spi_half)} on OUT5, MOSI on OUT4, MISO on IN0, no chip select"]
    ; source = Firmware.spi_master ~half_period:spi_half
    ; config = on_spi_pins Firmware.spi_config
    ; assumption = Nothing
    ; clock_hz
    ; load = None
    }
  ; { name = "i2c_master"
    ; what =
        [%string
          "Firmware.i2c_master_host_rate: the host sends the quarter, %{i2c_quarter#Int} \
           cycles for %{rate (4 * i2c_quarter)}, SDA on IO2, SCL on IO3"]
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
    ; clock_hz
    ; load = Some i2c_quarter
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
    ; clock_hz
    ; load = Some i2c_quarter
    }
  ; { name = "one_wire"
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
    }
  ]
  @ List.map Spi_cs.Mode.all ~f:(fun mode ->
    let n = Spi_cs.Mode.to_int mode in
    { name = [%string "spi_cs_mode%{n#Int}"]
    ; what =
        [%string
          "Spi_cs.master in mode %{n#Int}, half period %{spi_half#Int}: SCK at %{rate (2 \
           * spi_half)} on OUT5, MOSI on OUT4, MISO on IN0, CS on OUT6 4 cycles before \
           the first edge and 8 after the last, and high %{time spi_cs_deselect} between \
           frames"]
    ; source =
        Spi_cs.master
          ~mode
          ~half_period:spi_half
          ~setup:4
          ~hold:8
          ~deselect:spi_cs_deselect
    ; config = on_spi_pins Spi_cs.config
    ; assumption = Nothing
    ; clock_hz
    ; load = None
    })
;;

(* the keyboard demo loads the certified copy, at the period python/demo_usb.py works out
   from the clock the same way *)
let uart_log =
  let baud = 115_200 in
  let period = (clock_hz + (baud / 2)) / baud in
  { name = "uart_log"
  ; what =
      [%string
        "Firmware.uart_tx_host_rate: the keyboard demo's log to Pico B, %{period#Int} \
         cycles a bit for %{rate ~unit:\"baud\" period}, on OUT0"]
  ; source = Firmware.uart_tx_host_rate
  ; config = Program_config.default
  ; assumption = Floor 4
  ; clock_hz
  ; load = Some period
  }
;;

let find_exn name =
  match List.find (uart_log :: all) ~f:(fun t -> String.equal t.name name) with
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

let period t =
  match t.assumption with
  | Period period | Receiver period -> Some period
  | Nothing | Floor _ -> t.load
;;
