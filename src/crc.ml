open! Core
open! Hardcaml

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

module Make (Comb : Comb.S) = struct
  open Comb

  let step ~width ~poly ~reflect crc ~bit =
    let mask = ~:(log_shift ~f:sll (ones (Comb.width crc)) ~by:width) in
    let top = mux (width -:. 1) (bits_lsb crc) in
    let reflected =
      let shifted = srl crc ~by:1 in
      mux2 (crc.:(0) ^: bit) (shifted ^: poly) shifted
    in
    let forward =
      let shifted = sll crc ~by:1 in
      mux2 (top ^: bit) (shifted ^: poly) shifted
    in
    mux2 reflect reflected forward &: mask
  ;;
end
