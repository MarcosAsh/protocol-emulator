open! Core

type t = { engines : Machine.t list }

let create engines =
  if List.is_empty engines then raise_s [%message "BUG: there has to be an engine"];
  { engines }
;;

let pin_mask = (1 lsl Isa.num_pins) - 1
let wires = ((1 lsl Isa.pin_space) - 1) land lnot pin_mask
let output_only = (1 lsl Isa.first_bidir_pin) - 1
let any engines ~f = List.fold engines ~init:0 ~f:(fun v (m : Machine.t) -> v lor f m)

let seen t n ~pads =
  let others = List.filteri t.engines ~f:(fun m _ -> m <> n) in
  let driven = any others ~f:(fun m -> m.pin_dir) in
  let level = any others ~f:(fun m -> m.pin_out land (m.pin_dir lor wires)) in
  pads land pin_mask land lnot driven lor level
;;

let step t ~pads =
  { engines = List.mapi t.engines ~f:(fun n m -> Machine.step m ~inputs:(seen t n ~pads))
  }
;;

let pin_out t =
  match t.engines with
  | [ m ] -> m.pin_out land pin_mask
  | engines ->
    any engines ~f:(fun m -> m.pin_out land (m.pin_dir lor output_only)) land pin_mask
;;

let pin_dir t = any t.engines ~f:(fun m -> m.pin_dir) land pin_mask

let update t n ~f =
  { engines =
      List.mapi t.engines ~f:(fun m machine -> if m = n then f machine else machine)
  }
;;
