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
