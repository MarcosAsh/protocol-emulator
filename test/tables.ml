open! Core
open Protocol_emulator.Tables

let certified name wiring =
  Certified.plain ~any_data:true name (interpreter wiring) (config wiring)
;;

let protocol =
  { Protocol.name = "tables"
  ; certified =
      [ certified "table" Wiring.default
      ; certified
          "table_open_drain"
          (i2c_slave ~address:0 ~sda:Protocol_emulator.Isa.first_bidir_pin).wiring
      ]
  ; time_triggered = []
  ; bench = []
  ; loaded_from_hex = []
  ; limits = []
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ "table", "its pins follow a table in data memory, which the sweep does not load"
      ; "table_open_drain", "the same"
      ]
  ; scenarios = []
  ; decoded = []
  }
;;
