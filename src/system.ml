open! Core

type t = { engines : Machine.t list }

let create engines =
  if List.is_empty engines then raise_s [%message "BUG: there has to be an engine"];
  { engines }
;;

let pin_mask = (1 lsl Isa.num_pins) - 1
let wires = ((1 lsl Isa.pin_space) - 1) land lnot pin_mask
let output_only = (1 lsl Isa.first_bidir_pin) - 1
let faulted (m : Machine.t) = not (Machine.Fault.equal m.fault Machine.Fault.none)

(* what an engine drives, as [pin_out, pin_dir]: nothing once it has faulted, as at reset *)
let driving (m : Machine.t) = if faulted m then 0, 0 else m.pin_out, m.pin_dir
let any drives ~f = List.fold drives ~init:0 ~f:(fun v drive -> v lor f drive)

(* what engine [n] is handed as [inputs] for the next step *)
let seen t n ~pads =
  let others = List.filteri t.engines ~f:(fun m _ -> m <> n) |> List.map ~f:driving in
  let driven = any others ~f:snd in
  let level = any others ~f:(fun (out, dir) -> out land (dir lor wires)) in
  pads land pin_mask land lnot driven lor level
;;

(* a fault stops the engine an edge after it shows, as [Machine.stop] does for the host *)
let step t ~pads =
  { engines =
      List.mapi t.engines ~f:(fun n m ->
        let stepped = Machine.step m ~inputs:(seen t n ~pads) in
        if faulted m then Machine.stop stepped else stepped)
  }
;;

let pin_out t =
  match List.map t.engines ~f:driving with
  | [ (out, _) ] -> out land pin_mask
  | drives ->
    any drives ~f:(fun (out, dir) -> out land (dir lor output_only)) land pin_mask
;;

let pin_dir t = any (List.map t.engines ~f:driving) ~f:snd land pin_mask

let update t n ~f =
  { engines =
      List.mapi t.engines ~f:(fun m machine -> if m = n then f machine else machine)
  }
;;
