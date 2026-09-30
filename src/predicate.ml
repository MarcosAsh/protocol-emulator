open! Core
open! Hardcaml

module Edge = struct
  type t =
    { pin : int
    ; rising : bool
    }
  [@@deriving sexp_of, compare, equal]
end

module Level = struct
  type t =
    { pin : int
    ; high : bool
    }
  [@@deriving sexp_of, compare, equal]
end

type t =
  | Edge of Edge.t
  | Edge_while of
      { edge : Edge.t
      ; guard : Level.t
      }
[@@deriving sexp_of, compare, equal]

let edge_to_string ({ pin; rising } : Edge.t) =
  [%string "pin %{pin#Int} %{if rising then \"rises\" else \"falls\"}"]
;;

let level_to_string ({ pin; high } : Level.t) =
  [%string "pin %{pin#Int} is %{if high then \"high\" else \"low\"}"]
;;

let to_string = function
  | Edge edge -> edge_to_string edge
  | Edge_while { edge; guard } ->
    [%string "%{edge_to_string edge} while %{level_to_string guard}"]
;;

module Certificate = struct
  type t =
    { latency : int
    ; guard_at : int option
    ; blind_after_match : int
    ; blind_after_reject : int option
    ; verdict_pc : int
    }
  [@@deriving sexp_of]
end

module Firmware = struct
  type t =
    { source : string
    ; program : Asm.Program.t
    ; config : Program_config.t
    ; certificate : Certificate.t
    }
end

let refuse fmt = Printf.ksprintf Or_error.error_string fmt

let readable name pin =
  if pin < 0
     || pin >= Isa.pin_space
     || (pin >= Isa.first_output_pin && pin < Isa.first_bidir_pin)
  then refuse "%s pin %d is not an input, a bidirectional pin or a wire" name pin
  else Ok ()
;;

let line ?comment text =
  let text = "    " ^ text in
  match comment with
  | None -> text
  | Some comment -> [%string "%{String.pad_right text ~len:24}; %{comment}"]
;;

let source t ~verdict_pin ~latency ~budget =
  let edge, guard =
    match t with
    | Edge edge -> edge, None
    | Edge_while { edge; guard } -> edge, Some guard
  in
  let reject =
    Option.value_map guard ~default:[] ~f:(fun (guard : Level.t) ->
      let level = if guard.high then "low" else "high" in
      [ line
          [%string "jmp %{if guard.high then \"!pin\" else \"pin\"}, watch"]
          ~comment:[%string "pin %{guard.pin#Int} %{level}: no match"]
      ])
  in
  [ [%string "; %{to_string t}: pin %{verdict_pin#Int} pulses %{latency#Int} cycles on"]
  ; line [%string "set p, %{budget#Int}"] ~comment:"the budget"
  ; line "set pins, 0"
  ; "watch:"
  ; line
      [%string "wait %{if edge.rising then \"rise\" else \"fall\"} pin %{edge.pin#Int}"]
      ~comment:"the event"
  ]
  @ reject
  @ [ line "mov t, now" ~comment:"the anchor"
    ; line "add t, p"
    ; line "wait t" ~comment:"pads every match to the latency"
    ; line "set pins, 1" ~comment:"the verdict"
    ; line "set pins, 0"
    ; line "jmp watch"
    ]
  |> String.concat_lines
;;

let cycles : Isa.t -> int = function
  | Jmp _ -> Isa.jmp_cycles
  | Op { delay; _ } -> 1 + delay
;;

(* The cycles from issuing [first] to issuing [last], falling through every jump. *)
let cycles_between (instructions : Isa.t array) ~first ~last =
  Array.sub instructions ~pos:first ~len:(last - first)
  |> Array.sum (module Int) ~f:cycles
;;

let find_pc (instructions : Isa.t array) ~f =
  Array.findi_exn instructions ~f:(fun _ instruction -> f instruction) |> fst
;;

(* The phase on entry to [pc] as the kernel's table holds it, once the table is accepted. *)
let certified_phase (table : Kernel.Table.t) ~pc =
  let row = table.(pc) in
  Bits.to_signed_int row.phase_lo, Bits.to_signed_int row.phase_hi
;;

(* A pad wait entered late: the latency is short by the lateness, and by the budget
   clamped to zero below. *)
let shortfall rows ~budget =
  List.find_map rows ~f:(fun (r : Analyser.Row.t) ->
    match r.instruction, r.phase.hi with
    | Op { op = Wait (Deadline _); _ }, Some hi when hi > 0 ->
      Some (hi + Int.max 0 (-budget))
    | _ -> None)
;;

let compile ?(verdict_pin = Isa.first_output_pin) ~latency t =
  let open Or_error.Let_syntax in
  let edge, guard =
    match t with
    | Edge edge -> edge, None
    | Edge_while { edge; guard } -> edge, Some guard
  in
  let%bind () = readable "event" edge.pin in
  let%bind () =
    Option.value_map guard ~default:(Ok ()) ~f:(fun g -> readable "guard" g.pin)
  in
  let%bind () =
    if verdict_pin < Isa.first_output_pin || verdict_pin >= Isa.num_pins
    then refuse "verdict pin %d is not an output" verdict_pin
    else Ok ()
  in
  let config =
    { Program_config.default with
      set_base = verdict_pin
    ; jmp_pin = Option.value_map guard ~default:0 ~f:(fun g -> g.pin)
    }
  in
  let assemble ~budget =
    let source = source t ~verdict_pin ~latency ~budget in
    let%map program = Asm.assemble source in
    source, program
  in
  (* the layout does not depend on the budget, so a probe at zero finds it *)
  let%bind _, probe = assemble ~budget:0 in
  let instructions = Array.of_list probe.instructions in
  let event_pc =
    find_pc instructions ~f:(function
      | Op { op = Wait (Pin_edge _); _ } -> true
      | _ -> false)
  in
  let anchor_pc =
    find_pc instructions ~f:(function
      | Op { op = Mov { dest = T; source = Now; _ }; _ } -> true
      | _ -> false)
  in
  let verdict_pc =
    find_pc instructions ~f:(function
      | Op { op = Set { dest = Pins; value = 1 }; _ } -> true
      | _ -> false)
  in
  let to_anchor = cycles_between instructions ~first:event_pc ~last:anchor_pc in
  (* released at the deadline, the verdict issues the cycle after *)
  let budget = latency - to_anchor - 1 in
  let%bind () =
    if budget >= 1 lsl Isa.Field.set_value.width
    then
      refuse "latency %d needs a budget of %d cycles, above what set holds" latency budget
    else Ok ()
  in
  let%bind source, program = assemble ~budget:(Int.max 0 budget) in
  let config = Asm.Program.configure program config in
  let rows = Analyser.analyse ~config program.instructions in
  let%bind () =
    match shortfall rows ~budget with
    | Some short ->
      refuse
        "latency %d exceeded by %d %s: %s needs %d"
        latency
        short
        (if short = 1 then "cycle" else "cycles")
        (to_string t)
        (latency + short)
    | None -> Ok ()
  in
  let%bind _ : Analyser.Verdict.t = Analyser.check ~config program in
  let%bind words = Asm.Program.words program in
  let table = Kernel.Table.of_analyser rows in
  let%bind () = Kernel.check ~config ~words table in
  let%bind certified =
    match certified_phase table ~pc:verdict_pc with
    | lo, hi when lo = hi -> Ok (to_anchor + budget + lo)
    | lo, hi -> refuse "BUG: the verdict's phase is %d..%d, not one cycle" lo hi
  in
  let%bind () =
    if certified = latency
    then Ok ()
    else refuse "BUG: certified latency %d, asked for %d" certified latency
  in
  let last = Array.length instructions in
  (* the next event the wait sees is one sampled in the cycle it issues again *)
  let back_to_watch ~from = cycles_between instructions ~first:from ~last - 1 in
  let certificate =
    { Certificate.latency
    ; guard_at =
        Option.map guard ~f:(fun _ ->
          cycles_between instructions ~first:event_pc ~last:(event_pc + 1))
    ; blind_after_match = latency + back_to_watch ~from:verdict_pc
    ; blind_after_reject =
        Option.map guard ~f:(fun _ ->
          cycles_between instructions ~first:event_pc ~last:(event_pc + 2) - 1)
    ; verdict_pc
    }
  in
  return { Firmware.source; program; config; certificate }
;;
