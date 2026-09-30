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
  | Quiet of { pin : int }
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
  | Quiet { pin } -> [%string "pin %{pin#Int} stops moving"]
;;

module Sampling = struct
  type t =
    | Waits of
        { guard_at : int option
        ; blind_after_match : int
        ; blind_after_reject : int option
        }
    | Polls of
        { min_run : int
        ; unseen_before_verdict : int
        }
  [@@deriving sexp_of]
end

module Certificate = struct
  type t =
    { latency : int
    ; jitter : int
    ; sampling : Sampling.t
    ; verdict_pcs : int list
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

let of_string text =
  let open Or_error.Let_syntax in
  let pin s =
    match Int.of_string_opt s with
    | Some pin -> Ok pin
    | None -> refuse "%S is not a pin number" s
  in
  let edge p moves =
    let%map pin = pin p in
    { Edge.pin; rising = String.equal moves "rises" }
  in
  match String.split text ~on:' ' |> List.filter ~f:(Fn.non String.is_empty) with
  | [ "pin"; p; (("rises" | "falls") as moves) ] ->
    let%map edge = edge p moves in
    Edge edge
  | [ "pin"
    ; p
    ; (("rises" | "falls") as moves)
    ; "while"
    ; "pin"
    ; g
    ; "is"
    ; (("high" | "low") as level)
    ] ->
    let%map edge = edge p moves
    and guard = pin g in
    Edge_while { edge; guard = { pin = guard; high = String.equal level "high" } }
  | [ "pin"; p; "stops"; "moving" ] ->
    let%map pin = pin p in
    Quiet { pin }
  | _ ->
    refuse
      "%S: expected pin N rises|falls, then perhaps while pin M is high|low, or pin N \
       stops moving"
      text
;;

let line ?comment text =
  let text = "    " ^ text in
  match comment with
  | None -> text
  | Some comment -> [%string "%{String.pad_right text ~len:24}; %{comment}"]
;;

let pulses ~verdict_pin ~latency ~jitter =
  if jitter = 0
  then [%string "pin %{verdict_pin#Int} pulses %{latency#Int} cycles on"]
  else
    [%string
      "pin %{verdict_pin#Int} pulses %{latency#Int} to %{latency + jitter#Int} cycles on"]
;;

let event_source ~(edge : Edge.t) ~(guard : Level.t option) ~header ~budget =
  let reject =
    Option.value_map guard ~default:[] ~f:(fun (guard : Level.t) ->
      let level = if guard.high then "low" else "high" in
      [ line
          [%string "jmp %{if guard.high then \"!pin\" else \"pin\"}, watch"]
          ~comment:[%string "pin %{guard.pin#Int} %{level}: no match"]
      ])
  in
  [ header
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

(* A half per level of the pin: it anchors, polls in a counted loop, pads to the latency,
   polls once more and pulses the verdict, then waits for the level to change. The wait's
   delay anchors an edge it sees as far on as a poll's jump does. *)
let quiet_source ~pin ~header ~budget ~loops =
  let half ~name ~other ~high =
    let leave = [%string "jmp %{if high then \"!pin\" else \"pin\"}, %{other}"] in
    [ name ^ ":"
    ; line "mov t, now" ~comment:"the anchor"
    ; line "add t, p"
    ; line [%string "set x, %{loops#Int}"]
    ; name ^ "_poll:"
    ; line leave ~comment:"an edge"
    ; line [%string "jmp x--, %{name}_poll"]
    ; line "wait t" ~comment:"pads the verdict to the latency"
    ; line leave
    ; line "set pins, 1" ~comment:"the verdict"
    ; line "set pins, 0"
    ]
  in
  [ header
  ; line [%string "set p, %{budget#Int}"] ~comment:"the budget"
  ; line "set pins, 0"
  ; line "jmp pin, high"
  ; line "jmp low"
  ; "low_wait:"
  ; line [%string "wait 0 pin %{pin#Int} [1]"]
  ]
  @ half ~name:"low" ~other:"high" ~high:false
  @ [ line [%string "wait 1 pin %{pin#Int} [1]"] ]
  @ half ~name:"high" ~other:"low" ~high:true
  @ [ line "jmp low_wait" ]
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

let pcs (instructions : Isa.t array) ~f =
  Array.filter_mapi instructions ~f:(fun pc instruction ->
    Option.some_if (f instruction) pc)
  |> Array.to_list
;;

let is_anchor : Isa.t -> bool = function
  | Op { op = Mov { dest = T; source = Now; _ }; _ } -> true
  | _ -> false
;;

let is_pad : Isa.t -> bool = function
  | Op { op = Wait (Deadline _); _ } -> true
  | _ -> false
;;

let is_verdict : Isa.t -> bool = function
  | Op { op = Set { dest = Pins; value = 1 }; _ } -> true
  | _ -> false
;;

(* The phase on entry to [pc] as the kernel's table holds it, once the table is accepted. *)
let certified_phase (table : Kernel.Table.t) ~pc =
  let row = table.(pc) in
  Bits.to_signed_int row.phase_lo, Bits.to_signed_int row.phase_hi
;;

let pad_lateness rows =
  List.filter_map rows ~f:(fun (r : Analyser.Row.t) ->
    if is_pad r.instruction then r.phase.hi else None)
  |> List.max_elt ~compare:Int.compare
;;

let fits_set ~latency name value =
  if value >= 1 lsl Isa.Field.set_value.width
  then refuse "latency %d needs %s of %d, above what set holds" latency name value
  else Ok ()
;;

(* A pad wait entered late is refused: the latency is short by the lateness, and by the
   budget below zero. The kernel's table must then give every verdict one phase. *)
let certify t ~config ~latency ~budget (program : Asm.Program.t) =
  let open Or_error.Let_syntax in
  let rows = Analyser.analyse ~config program.instructions in
  let%bind () =
    match pad_lateness rows with
    | Some late when late > 0 ->
      let short = late + Int.max 0 (-budget) in
      refuse
        "latency %d exceeded by %d %s: %s needs %d"
        latency
        short
        (if short = 1 then "cycle" else "cycles")
        (to_string t)
        (latency + short)
    | _ -> Ok ()
  in
  let%bind _ : Analyser.Verdict.t = Analyser.check ~config program in
  let%bind words = Asm.Program.words program in
  let table = Kernel.Table.of_analyser rows in
  let%bind () = Kernel.check ~config ~words table in
  let instructions = Array.of_list program.instructions in
  match
    List.map (pcs instructions ~f:is_verdict) ~f:(fun pc -> certified_phase table ~pc)
    |> List.dedup_and_sort ~compare:[%compare: int * int]
  with
  | [ (lo, hi) ] when lo = hi -> Ok lo
  | phases ->
    Or_error.error_s
      [%message "BUG: the verdicts' phase is not one cycle" (phases : (int * int) list)]
;;

let check_latency ~certified ~latency =
  if certified = latency
  then Ok ()
  else refuse "BUG: certified latency %d, asked for %d" certified latency
;;

let compile_event ~config ~verdict_pin ~latency t ~edge ~guard =
  let open Or_error.Let_syntax in
  let header = [%string "; %{to_string t}: %{pulses ~verdict_pin ~latency ~jitter:0}"] in
  let assemble ~budget =
    let source = event_source ~edge ~guard ~header ~budget in
    let%map program = Asm.assemble source in
    source, program
  in
  (* the layout does not depend on the budget, so a probe at zero finds it *)
  let%bind _, probe = assemble ~budget:0 in
  let instructions = Array.of_list probe.instructions in
  let event_pc =
    pcs instructions ~f:(function
      | Op { op = Wait (Pin_edge _); _ } -> true
      | _ -> false)
    |> List.hd_exn
  in
  let anchor_pc = List.hd_exn (pcs instructions ~f:is_anchor) in
  let verdict_pc = List.hd_exn (pcs instructions ~f:is_verdict) in
  let to_anchor = cycles_between instructions ~first:event_pc ~last:anchor_pc in
  (* released at the deadline, the verdict issues the cycle after *)
  let budget = latency - to_anchor - 1 in
  let%bind () = fits_set ~latency "a budget" budget in
  let%bind source, program = assemble ~budget:(Int.max 0 budget) in
  let config = Asm.Program.configure program config in
  let%bind phase = certify t ~config ~latency ~budget program in
  let%bind () = check_latency ~certified:(to_anchor + budget + phase) ~latency in
  (* the next event the wait sees is one sampled in the cycle it issues again *)
  let back_to_watch ~from =
    cycles_between instructions ~first:from ~last:(Array.length instructions) - 1
  in
  let sampling =
    Sampling.Waits
      { guard_at =
          Option.map guard ~f:(fun _ ->
            cycles_between instructions ~first:event_pc ~last:(event_pc + 1))
      ; blind_after_match = latency + back_to_watch ~from:verdict_pc
      ; blind_after_reject =
          Option.map guard ~f:(fun _ ->
            cycles_between instructions ~first:event_pc ~last:(event_pc + 2) - 1)
      }
  in
  return
    { Firmware.source
    ; program
    ; config
    ; certificate = { latency; jitter = 0; sampling; verdict_pcs = [ verdict_pc ] }
    }
;;

(* The halves are laid out alike, so the low one's cycles stand for both, but for the high
   one's jump back to the low wait. *)
let compile_quiet ~config ~verdict_pin ~latency t ~pin =
  let open Or_error.Let_syntax in
  let assemble ~header ~budget ~loops =
    let source = quiet_source ~pin ~header ~budget ~loops in
    let%map program = Asm.assemble source in
    source, program
  in
  let%bind _, probe = assemble ~header:"" ~budget:0 ~loops:0 in
  let instructions = Array.of_list probe.instructions in
  let anchor = List.hd_exn (pcs instructions ~f:is_anchor) in
  let pad = List.hd_exn (pcs instructions ~f:is_pad) in
  let verdicts = pcs instructions ~f:is_verdict in
  let verdict = List.hd_exn verdicts in
  let poll = anchor + 3 in
  let loop_period = cycles_between instructions ~first:poll ~last:(poll + 2) in
  (* a poll's jump and the level wait's delay each anchor [to_anchor] after the edge *)
  let to_anchor = Isa.jmp_cycles in
  let verdict_phase = cycles_between instructions ~first:pad ~last:verdict in
  let budget = latency - to_anchor - verdict_phase in
  let%bind () = fits_set ~latency "a budget" budget in
  let%bind pad_at_zero =
    match pad_lateness (Analyser.analyse ~config probe.instructions) with
    | Some late -> Ok late
    | None -> refuse "BUG: the pad wait has no bound"
  in
  let loops = Int.max 0 ((budget - pad_at_zero) / loop_period) in
  let%bind () = fits_set ~latency "a count of polls" loops in
  (* where the pin is sampled, in cycles from the anchor *)
  let first_poll = cycles_between instructions ~first:anchor ~last:poll in
  let last_loop_poll = first_poll + (loops * loop_period) in
  let final_poll = budget + cycles instructions.(pad) in
  let verdict_at = budget + verdict_phase in
  let level_wait =
    verdict_at
    + cycles_between instructions ~first:verdict ~last:(verdict + 2)
    + Isa.jmp_cycles
  in
  let min_run =
    List.fold
      [ first_poll + to_anchor
      ; (if loops > 0 then loop_period else 0)
      ; final_poll - last_loop_poll
      ; level_wait - final_poll
      ]
      ~init:0
      ~f:Int.max
  in
  let jitter = min_run - 1 in
  let header = [%string "; %{to_string t}: %{pulses ~verdict_pin ~latency ~jitter}"] in
  let%bind source, program = assemble ~header ~budget:(Int.max 0 budget) ~loops in
  let config = Asm.Program.configure program config in
  let%bind phase = certify t ~config ~latency ~budget program in
  let%bind () = check_latency ~certified:(to_anchor + budget + phase) ~latency in
  let sampling =
    Sampling.Polls { min_run; unseen_before_verdict = verdict_at - final_poll }
  in
  return
    { Firmware.source
    ; program
    ; config
    ; certificate = { latency; jitter; sampling; verdict_pcs = verdicts }
    }
;;

let compile ?(verdict_pin = Isa.first_output_pin) ~latency t =
  let open Or_error.Let_syntax in
  let%bind () =
    match t with
    | Edge edge -> readable "event" edge.pin
    | Edge_while { edge; guard } ->
      let%bind () = readable "event" edge.pin in
      readable "guard" guard.pin
    | Quiet { pin } -> readable "watched" pin
  in
  let%bind () =
    if verdict_pin < Isa.first_output_pin || verdict_pin >= Isa.num_pins
    then refuse "verdict pin %d is not an output" verdict_pin
    else Ok ()
  in
  let config = { Program_config.default with set_base = verdict_pin } in
  match t with
  | Edge edge -> compile_event ~config ~verdict_pin ~latency t ~edge ~guard:None
  | Edge_while { edge; guard } ->
    compile_event
      ~config:{ config with jmp_pin = guard.pin }
      ~verdict_pin
      ~latency
      t
      ~edge
      ~guard:(Some guard)
  | Quiet { pin } ->
    compile_quiet ~config:{ config with jmp_pin = pin } ~verdict_pin ~latency t ~pin
;;
