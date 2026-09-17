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
  }
[@@deriving sexp_of, compare, equal]

let default =
  { side_set_count = 0
  ; side_set_base = 5
  ; side_set_pindirs = false
  ; in_base = 0
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
  }
;;

let validate t =
  let open Or_error.Let_syntax in
  let range name value ~lo ~hi =
    if lo <= value && value <= hi
    then Ok ()
    else
      Or_error.error_s [%message name "out of range" (value : int) (lo : int) (hi : int)]
  in
  let pin name value = range name value ~lo:0 ~hi:(Isa.num_pins - 1) in
  let%bind () = range "side_set_count" t.side_set_count ~lo:0 ~hi:Isa.max_side_set in
  let%bind () = pin "side_set_base" t.side_set_base in
  let%bind () = pin "in_base" t.in_base in
  let%bind () = pin "out_base" t.out_base in
  let%bind () = range "out_count" t.out_count ~lo:1 ~hi:Isa.data_bits in
  let%bind () = pin "set_base" t.set_base in
  let%bind () = range "set_count" t.set_count ~lo:1 ~hi:Isa.Field.set_value.width in
  let%bind () = pin "jmp_pin" t.jmp_pin in
  let%bind () = pin "capture_pin" t.capture_pin in
  let%bind () = range "push_threshold" t.push_threshold ~lo:1 ~hi:Isa.data_bits in
  range "pull_threshold" t.pull_threshold ~lo:1 ~hi:Isa.data_bits
;;
