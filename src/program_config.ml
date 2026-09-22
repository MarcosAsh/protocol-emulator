open! Core

module Shift_direction = struct
  type t =
    | Left
    | Right
  [@@deriving sexp_of, compare, equal]
end

type t =
  { side_set_count : int
  ; side_set_base : int
  ; side_set_pindirs : bool
  ; in_base : int
  ; in_count : int
  ; out_base : int
  ; out_count : int
  ; set_base : int
  ; set_count : int
  ; jmp_pin : int
  ; capture_pin : int
  ; capture_rising : bool
  ; in_shift : Shift_direction.t
  ; out_shift : Shift_direction.t
  ; autopush : bool
  ; push_threshold : int
  ; autopull : bool
  ; pull_threshold : int
  ; crc_width : int
  ; crc_poly : int
  ; crc_init : int
  ; crc_reflect : bool
  ; stuff_threshold : int
  ; stuff_level : bool
  ; wrap_bottom : int
  ; wrap_top : int
  ; period_fraction : int
  ; break_enable : bool
  ; break_pc : int
  ; autopull_data : bool
  }
[@@deriving sexp_of, compare, equal]

let default =
  { side_set_count = 0
  ; side_set_base = 5
  ; side_set_pindirs = false
  ; in_base = 0
  ; in_count = Isa.data_bits
  ; out_base = 5
  ; out_count = 1
  ; set_base = 5
  ; set_count = 1
  ; jmp_pin = 0
  ; capture_pin = 0
  ; capture_rising = true
  ; in_shift = Right
  ; out_shift = Right
  ; autopush = false
  ; push_threshold = Isa.data_bits
  ; autopull = false
  ; pull_threshold = Isa.data_bits
  ; crc_width = Isa.data_bits
  ; crc_poly = 0xa001
  ; crc_init = 0xffff
  ; crc_reflect = true
  ; stuff_threshold = 0
  ; stuff_level = true
  ; wrap_bottom = 0
  ; wrap_top = (1 lsl Isa.pc_bits) - 1
  ; period_fraction = 0
  ; break_enable = false
  ; break_pc = 0
  ; autopull_data = false
  }
;;

let validate t =
  let range = Isa.in_range in
  let pin name value = range name value ~lo:0 ~hi:(Isa.pin_space - 1) in
  Or_error.all_unit
    [ range "side_set_count" t.side_set_count ~lo:0 ~hi:Isa.max_side_set
    ; pin "side_set_base" t.side_set_base
    ; pin "in_base" t.in_base
    ; range "in_count" t.in_count ~lo:1 ~hi:Isa.data_bits
    ; pin "out_base" t.out_base
    ; range "out_count" t.out_count ~lo:1 ~hi:Isa.data_bits
    ; pin "set_base" t.set_base
    ; range "set_count" t.set_count ~lo:1 ~hi:Isa.Field.set_value.width
    ; pin "jmp_pin" t.jmp_pin
    ; pin "capture_pin" t.capture_pin
    ; range "push_threshold" t.push_threshold ~lo:1 ~hi:Isa.data_bits
    ; range "pull_threshold" t.pull_threshold ~lo:1 ~hi:Isa.data_bits
    ; range "crc_width" t.crc_width ~lo:1 ~hi:Isa.data_bits
    ; range "crc_poly" t.crc_poly ~lo:0 ~hi:0xffff
    ; range "crc_init" t.crc_init ~lo:0 ~hi:0xffff
    ; range "stuff_threshold" t.stuff_threshold ~lo:0 ~hi:31
    ; range "wrap_bottom" t.wrap_bottom ~lo:0 ~hi:((1 lsl Isa.pc_bits) - 1)
    ; range "wrap_top" t.wrap_top ~lo:0 ~hi:((1 lsl Isa.pc_bits) - 1)
    ; range "period_fraction" t.period_fraction ~lo:0 ~hi:((1 lsl Isa.fraction_bits) - 1)
    ; range "break_pc" t.break_pc ~lo:0 ~hi:((1 lsl Isa.pc_bits) - 1)
    ]
;;
