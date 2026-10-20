open! Core
open! Hardcaml

let max_width = 32
let width_bits = Int.ceil_log2 (max_width + 1)

let step ~width ~poly ~reflect crc ~bit =
  let mask = (1 lsl width) - 1 in
  if reflect
  then (
    let feedback = crc lxor bit land 1 = 1 in
    let shifted = crc lsr 1 in
    (if feedback then shifted lxor poly else shifted) land mask)
  else (
    let feedback = (crc lsr (width - 1)) land 1 <> bit in
    let shifted = crc lsl 1 in
    (if feedback then shifted lxor poly else shifted) land mask)
;;

let out_bit ~width ~reflect crc =
  if reflect then crc land 1 else (crc lsr (width - 1)) land 1
;;

module Make (Comb : Comb.S) = struct
  open Comb

  let top ~width crc = mux (width -:. 1) (bits_lsb crc)
  let out_bit ~width ~reflect crc = mux2 reflect crc.:(0) (top ~width crc)

  let step ~width ~poly ~reflect crc ~bit =
    let mask = ~:(log_shift ~f:sll (ones (Comb.width crc)) ~by:width) in
    let reflected =
      let shifted = srl crc ~by:1 in
      mux2 (crc.:(0) ^: bit) (shifted ^: poly) shifted
    in
    let forward =
      let shifted = sll crc ~by:1 in
      mux2 (top ~width crc ^: bit) (shifted ^: poly) shifted
    in
    mux2 reflect reflected forward &: mask
  ;;
end
