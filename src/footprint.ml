open! Core
open! Hardcaml

module Writes = struct
  type 'a t =
    { out_pins_width : 'a [@bits Isa.count_bits]
    ; out_dirs_width : 'a [@bits Isa.count_bits]
    ; sets_pins : 'a
    ; sets_dirs : 'a
    ; movs_pins : 'a
    ; movs_dirs : 'a
    }
  [@@deriving hardcaml]

  let width n = Bits.of_unsigned_int ~width:Isa.count_bits n

  let of_program program =
    let ops =
      List.filter_map program ~f:(fun (instruction : Isa.t) ->
        match instruction with
        | Jmp _ -> None
        | Op { op; _ } -> Some op)
    in
    let widest (dest : Isa.Out_dest.Cases.t) =
      List.fold ops ~init:0 ~f:(fun widest (op : Isa.Op.t) ->
        match op with
        | Out { dest = d; count } when Isa.Out_dest.Cases.equal d dest -> max widest count
        | _ -> widest)
      |> width
    in
    let has f = Bits.of_bool (List.exists ops ~f) in
    { out_pins_width = widest Pins
    ; out_dirs_width = widest Pindirs
    ; sets_pins =
        has (function
          | Set { dest = Pins; _ } -> true
          | _ -> false)
    ; sets_dirs =
        has (function
          | Set { dest = Pindirs; _ } -> true
          | _ -> false)
    ; movs_pins =
        has (function
          | Mov { dest = Pins; _ } -> true
          | _ -> false)
    ; movs_dirs =
        has (function
          | Mov { dest = Pindirs; _ } -> true
          | _ -> false)
    }
  ;;

  let any =
    { out_pins_width = width Isa.max_shift_count
    ; out_dirs_width = width Isa.max_shift_count
    ; sets_pins = Bits.vdd
    ; sets_dirs = Bits.vdd
    ; movs_pins = Bits.vdd
    ; movs_dirs = Bits.vdd
    }
  ;;
end

module Make (Comb : Comb.S) = struct
  open Comb
  module Pins = Pins.Make (Comb)

  let output_pin n = n >= Isa.first_output_pin
  let bidir_pin n = n >= Isa.first_bidir_pin && n < Isa.num_pins

  (* what a write of [count] bits from [base] reaches: ones written over no pins *)
  let window ~base ~count ~writable =
    Pins.write
      (zero Isa.pin_space)
      ~base
      ~count:(uresize count ~width:Isa.count_bits)
      ~value:(ones Isa.data_bits)
      ~writable
  ;;

  let only_if used pins = mux2 used pins (zero Isa.pin_space)

  (* a side-set window wider than [Isa.max_side_set] writes 0 above it, and a pin only
     ever written 0 never moves *)
  let side_set_reach (c : Comb.t Engine.Config.t) =
    let most = of_unsigned_int ~width:(width c.side_set_count) Isa.max_side_set in
    mux2 (c.side_set_count >:. Isa.max_side_set) most c.side_set_count
  ;;

  let footprint (c : Comb.t Engine.Config.t) ~writable ~side_set ~sets ~outs ~movs =
    let window = window ~writable in
    reduce
      ~f:( |: )
      [ only_if side_set (window ~base:c.side_set_base ~count:(side_set_reach c))
      ; only_if sets (window ~base:c.set_base ~count:c.set_count)
      ; window ~base:c.out_base ~count:outs
      ; only_if movs (window ~base:c.out_base ~count:c.out_count)
      ]
  ;;

  let pin_out (c : Comb.t Engine.Config.t) (w : Comb.t Writes.t) =
    let two = of_unsigned_int ~width:Isa.count_bits 2 in
    let manchester_bit = c.manchester &: (w.out_pins_width ==:. 1) in
    (* a line-coded bit drives up to two pins, no more than [out_count] *)
    let line_pins = mux2 (c.out_count >=: two) two c.out_count in
    let line_width = mux2 (line_pins >: w.out_pins_width) line_pins w.out_pins_width in
    footprint
      c
      ~writable:output_pin
      ~side_set:~:(c.side_set_pindirs)
      ~sets:w.sets_pins
      ~outs:
        (mux2 manchester_bit two
         @@ mux2 (c.line_code &: (w.out_pins_width <>:. 0)) line_width w.out_pins_width)
      ~movs:w.movs_pins
  ;;

  let pin_dir (c : Comb.t Engine.Config.t) (w : Comb.t Writes.t) =
    footprint
      c
      ~writable:bidir_pin
      ~side_set:c.side_set_pindirs
      ~sets:w.sets_dirs
      ~outs:w.out_dirs_width
      ~movs:w.movs_dirs
  ;;
end

module Of_bits = Make (Bits)

type t =
  { pin_out : int list
  ; pin_dir : int list
  }
[@@deriving sexp_of, equal]

let pins mask =
  List.filter (List.range 0 Isa.pin_space) ~f:(fun n -> Bits.(to_bool mask.:(n)))
;;

let of_writes config writes =
  let config = Engine.Config.of_program_config config in
  { pin_out = pins (Of_bits.pin_out config writes)
  ; pin_dir = pins (Of_bits.pin_dir config writes)
  }
;;

let of_program config program = of_writes config (Writes.of_program program)
let of_config config = of_writes config Writes.any

let shared a b =
  let moves t = Int.Set.of_list (t.pin_out @ t.pin_dir) in
  Set.inter (moves a) (moves b) |> Set.to_list
;;
