open! Core

module Analyser = struct
  type t =
    | A
    | B
  [@@deriving compare, sexp_of]
end

type t =
  { pin : int
  ; name : string
  ; analyser : Analyser.t
  ; channel : int
  ; net : string
  }

(* Inputs are pins 0 to 4, OUT0 is [Isa.first_output_pin], IO0 [Isa.first_bidir_pin]. A's
   D0 to D3 are Pico A's host SPI, not chip pins a protocol drives. *)
let all =
  let t pin name analyser channel net = { pin; name; analyser; channel; net } in
  [ t 0 "IN0" B 2 "flash DO"
  ; t 1 "IN1" A 5 "CAN board A's CRX via 1k"
  ; t 5 "OUT0" A 4 "Pico B GP1 via 1k"
  ; t 7 "OUT2" A 6 "SWCLK, 220R to the RP2040 target"
  ; t 8 "OUT3" B 4 "SK6812 level shifter, 10k to GND"
  ; t 9 "OUT4" B 1 "flash DI"
  ; t 10 "OUT5" B 0 "flash CLK"
  ; t 11 "OUT6" B 3 "flash CS, 10k pull-up"
  ; t 14 "IO2" B 7 "SCL, EEPROM and Pico B GP3, 2k2 pull-up"
  ; t 15 "IO3" B 6 "SDA, EEPROM and Pico B GP2, 2k2 pull-up"
  ; t 16 "IO4" B 5 "DS18B20 DQ, 4k7 pull-up"
  ; t 17 "IO5" A 7 "SWDIO, 220R, 4k7 pull-up to 3V3_B"
  ]
;;

let find ~pin = List.find all ~f:(fun t -> t.pin = pin)
