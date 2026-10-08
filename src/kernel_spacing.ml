open! Core
open! Hardcaml

module Edge = struct
  type 'a t =
    { since : 'a [@bits Isa.data_bits]
    ; level : 'a
    ; fresh : 'a
    }
  [@@deriving hardcaml]
end

module Spacing = struct
  type 'a t =
    { a : 'a [@bits Isa.Field.wait_index.width]
    ; b : 'a [@bits Isa.Field.wait_index.width]
    ; dirs : 'a
    ; side_set_base : 'a [@bits Isa.Field.wait_index.width]
    ; side_set_pindirs : 'a
    ; set_base : 'a [@bits Isa.Field.wait_index.width]
    ; set_count : 'a [@bits 3]
    ; out_base : 'a [@bits Isa.Field.wait_index.width]
    ; out_count : 'a [@bits Isa.count_bits]
    ; hold_a : 'a list [@length 4] [@bits Isa.data_bits]
    ; apart_a : 'a list [@length 4] [@bits Isa.data_bits]
    ; hold_b : 'a list [@length 4] [@bits Isa.data_bits]
    ; apart_b : 'a list [@length 4] [@bits Isa.data_bits]
    }
  [@@deriving hardcaml]

  module Spec = struct
    type t =
      { a : int
      ; b : int
      ; dirs : bool
      ; hold_a : own:bool -> other:bool -> int
      ; apart_a : own:bool -> other:bool -> int
      ; hold_b : own:bool -> other:bool -> int
      ; apart_b : own:bool -> other:bool -> int
      }
  end

  let of_spec (config : Program_config.t) (spec : Spec.t) =
    let pin n = Bits.of_unsigned_int ~width:Isa.Field.wait_index.width n in
    let cycles f =
      List.init 4 ~f:(fun i ->
        Bits.of_unsigned_int
          ~width:Isa.data_bits
          (f ~own:(i lsr 1 = 1) ~other:(i land 1 = 1)))
    in
    { a = pin spec.a
    ; b = pin spec.b
    ; dirs = Bits.of_bool spec.dirs
    ; side_set_base = pin config.side_set_base
    ; side_set_pindirs = Bits.of_bool config.side_set_pindirs
    ; set_base = pin config.set_base
    ; set_count = Bits.of_unsigned_int ~width:3 config.set_count
    ; out_base = pin config.out_base
    ; out_count = Bits.of_unsigned_int ~width:Isa.count_bits config.out_count
    ; hold_a = cycles spec.hold_a
    ; apart_a = cycles spec.apart_a
    ; hold_b = cycles spec.hold_b
    ; apart_b = cycles spec.apart_b
    }
  ;;
end

module Spaced = With_valid.Wrap.Make (Spacing)
