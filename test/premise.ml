open! Core
open Protocol_emulator

module Count = struct
  type t =
    { arms : int
    ; at_captured_level : int
    ; left_captured_level : int
    }
  [@@deriving sexp_of]
end

(* phase_step.sv's registers: [holding] is armed and not yet released, [seen] is at the
   captured level since the arm *)
type t =
  { mutable count : Count.t
  ; mutable holding : bool
  ; mutable seen : bool
  ; mutable left : bool
  }

let create () =
  { count = { arms = 0; at_captured_level = 0; left_captured_level = 0 }
  ; holding = false
  ; seen = false
  ; left = false
  }
;;

let count t = t.count

let record t ~(before : Machine.t) ~(after : Machine.t) =
  let c = before.config in
  let level =
    Bool.equal ((after.pins_sampled lsr c.capture_pin) land 1 = 1) c.capture_rising
  in
  (* a wait that holds neither moves the program on nor begins a delay; a host's stop
     halts after the step *)
  let completes = after.pc <> before.pc || after.stall > 0 in
  let op : Isa.Op.t option =
    if before.halted || before.stall > 0 || not completes
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
  let captures =
    match op with
    | Some (Wait (Pin_level { pin; level })) ->
      pin = c.capture_pin && Bool.equal level c.capture_rising
    | Some (Wait (Pin_edge { pin; rising })) ->
      pin = c.capture_pin && Bool.equal rising c.capture_rising
    | _ -> false
  in
  let count = t.count in
  if arms
  then
    t.count
    <- { count with
         arms = count.arms + 1
       ; at_captured_level = count.at_captured_level + Bool.to_int level
       };
  if t.holding && t.seen && (not level) && not t.left
  then (
    t.left <- true;
    t.count <- { t.count with left_captured_level = t.count.left_captured_level + 1 });
  if arms
  then (
    t.holding <- true;
    t.seen <- false;
    t.left <- false)
  else if captures
  then t.holding <- false
  else if t.holding && level
  then t.seen <- true
;;
