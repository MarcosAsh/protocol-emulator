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

(* Engine [n]'s routed pushes land in engine [n + 1]'s tx fifo after the step, judged
   full by the level before it. A fault stops the engine an edge after it shows, as
   [Machine.stop] does for the host. *)
let step t ~pads =
  let count = List.length t.engines in
  let next n = List.nth_exn t.engines ((n + 1) % count) in
  let stepped =
    List.mapi t.engines ~f:(fun n m ->
      let route_full = List.length (next n).tx_fifo >= Machine.fifo_depth in
      let stepped = Machine.step m ~route_full ~inputs:(seen t n ~pads) in
      if faulted m then Machine.stop stepped else stepped)
  in
  let routed n = (List.nth_exn stepped ((n + count - 1) % count)).routed in
  { engines =
      List.mapi stepped ~f:(fun n m ->
        match routed n with
        | Some word -> Machine.write_tx m word |> ok_exn
        | None -> m)
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
