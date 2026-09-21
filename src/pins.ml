open! Core
open! Hardcaml

module Make (Comb : Comb.S) = struct
  open Comb

  let num_pins = Isa.num_pins
  let data_bits = Isa.data_bits

  (* A rotate by [base] in one stage per bit of it. The pins are not a power of two wide,
     which a rotate by constants does not mind. *)
  let rotate v ~f ~base =
    List.foldi (bits_lsb base) ~init:v ~f:(fun k v bit -> mux2 bit (f v ~by:(1 lsl k)) v)
  ;;

  let count_mask count = ~:(log_shift ~f:sll (ones data_bits) ~by:count)

  let read sample ~base ~count =
    sel_bottom (rotate sample ~f:rotr ~base) ~width:data_bits &: count_mask count
  ;;

  let write old ~base ~count ~value ~writable =
    let place v = rotate (uresize v ~width:num_pins) ~f:rotl ~base in
    let writable = List.init num_pins ~f:(fun i -> of_bool (writable i)) |> concat_lsb in
    let hit = place (count_mask count) &: writable in
    old &: ~:hit |: (place (uresize value ~width:data_bits) &: hit)
  ;;
end
