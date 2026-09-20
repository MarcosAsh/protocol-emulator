open! Core

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
