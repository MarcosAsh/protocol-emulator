open! Core
open Protocol_emulator

(* [holding] from the arm to the wait's release, [seen] once at the captured level *)
type t =
  { holding : bool
  ; seen : bool
  ; held : bool
  }

let create () = { holding = false; seen = false; held = true }
let held t = t.held

let step t ~(before : Machine.t) ~inputs ~(after : Machine.t) =
  let c = before.config in
  let level =
    Bool.equal
      ((Machine.pins before ~inputs lsr c.capture_pin) land 1 = 1)
      c.capture_rising
  in
  let op =
    if before.stall > 0 || before.halted
    then None
    else (
      match Isa.of_word ~side_set_count:c.side_set_count before.program.(before.pc) with
      | Ok (Op { op; _ }) -> Some op
      | Ok (Jmp _) | Error _ -> None)
  in
  let arms =
    match op with
    | Some (Sys Capture_arm) -> true
    | _ -> false
  in
  (* a wait takes effect by moving on *)
  let releases =
    after.pc <> before.pc
    &&
    match op with
    | Some (Wait (Pin_level { pin; level })) ->
      pin = c.capture_pin && Bool.equal level c.capture_rising
    | Some (Wait (Pin_edge { pin; rising })) ->
      pin = c.capture_pin && Bool.equal rising c.capture_rising
    | _ -> false
  in
  let off = (arms && level) || (t.holding && t.seen && not level) in
  let holding, seen =
    if arms
    then true, false
    else if releases
    then false, t.seen
    else t.holding, t.seen || (t.holding && level)
  in
  { holding; seen; held = t.held && not off }
;;
