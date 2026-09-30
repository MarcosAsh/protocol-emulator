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
    ; budget_from_host : int option
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

(* [set] takes five bits; a longer budget comes from the host, which the analyser and the
   kernel take as the value every load of p carries *)
let from_host budget = budget >= 1 lsl Isa.Field.set_value.width

let set_budget budget =
  if from_host budget
  then
    [ line "wait tx"
    ; line "pull" ~comment:[%string "the host sends the budget, %{budget#Int}"]
    ; line "mov p, osr"
    ]
  else [ line [%string "set p, %{budget#Int}"] ~comment:"the budget" ]
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
  [ header ]
  @ set_budget budget
  @ [ line "set pins, 0"
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
   polls once more and pulses the verdict, then waits for the level to change. Every way
   into an anchor, the first poll's fall through and the wrap included, is a sample
   [to_anchor] cycles before. *)
let quiet_source ~pin ~header ~budget ~loops ~stretch =
  let half ~name ~other ~high =
    let leave = [%string "jmp %{if high then \"!pin\" else \"pin\"}, %{other}"] in
    [ name ^ ":"
    ; line "mov t, now" ~comment:"the anchor"
    ; line "add t, p"
    ; line [%string "set x, %{loops#Int}"]
    ; name ^ "_poll:"
    ; line leave ~comment:"an edge"
    ]
    @ Option.value_map stretch ~default:[] ~f:(fun delay ->
      [ line [%string "nop [%{delay#Int}]"] ~comment:"spaces the polls" ])
    @ [ line [%string "jmp x--, %{name}_poll"]
      ; line "wait t" ~comment:"pads the verdict to the latency"
      ; line leave
      ; line "set pins, 1" ~comment:"the verdict"
      ; line "set pins, 0"
      ]
  in
  [ header ]
  @ set_budget budget
  @ [ line "set pins, 0"; line "jmp pin, high"; ".wrap_target" ]
  @ half ~name:"low" ~other:"high" ~high:false
  @ [ line [%string "wait 1 pin %{pin#Int} [1]"] ]
  @ half ~name:"high" ~other:"low" ~high:true
  @ [ line [%string "wait 0 pin %{pin#Int} [1]"]; ".wrap" ]
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

let bug fmt = Printf.ksprintf (fun s -> Or_error.error_string ("BUG: " ^ s)) fmt

let exactly name ~pc lo hi =
  if lo = hi then Ok lo else bug "the %s at pc %d is %d..%d, not one value" name pc lo hi
;;

(* Read from the kernel's table once it is accepted: the phase [now - t] on entry to [pc],
   and [p] there. *)
let certified_phase (table : Kernel.Table.t) ~pc =
  let row = table.(pc) in
  exactly "phase" ~pc (Bits.to_signed_int row.phase_lo) (Bits.to_signed_int row.phase_hi)
;;

let certified_period (table : Kernel.Table.t) ~pc =
  let row = table.(pc) in
  exactly
    "period"
    ~pc
    (Bits.to_unsigned_int row.period_lo)
    (Bits.to_unsigned_int row.period_hi)
;;

let pad_lateness rows =
  List.filter_map rows ~f:(fun (r : Analyser.Row.t) ->
    if is_pad r.instruction then r.phase.hi else None)
  |> List.max_elt ~compare:Int.compare
;;

let fits_budget ~latency budget =
  if budget >= 1 lsl Isa.data_bits
  then refuse "latency %d needs a budget of %d, above what p holds" latency budget
  else Ok ()
;;

(* A pad wait entered late is refused: the latency is short by the lateness, and by the
   budget below zero. Gives the kernel's table, and the verdicts' phase in it. *)
let certify t ~config ~latency ~budget (program : Asm.Program.t) =
  let open Or_error.Let_syntax in
  let period = Option.some_if (from_host budget) budget in
  let rows = Analyser.analyse ?period ~config program.instructions in
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
  let%bind _ : Analyser.Verdict.t = Analyser.check ?period ~config program in
  let%bind words = Asm.Program.words program in
  let table = Kernel.Table.of_analyser rows in
  let%bind () = Kernel.check ?period ~config ~words table in
  let instructions = Array.of_list program.instructions in
  let%bind phases =
    List.map (pcs instructions ~f:is_verdict) ~f:(fun pc -> certified_phase table ~pc)
    |> Or_error.all
  in
  match List.dedup_and_sort phases ~compare:Int.compare with
  | [ phase ] -> Ok (table, phase)
  | phases ->
    bug "the verdicts' phases differ: %s" (List.to_string phases ~f:Int.to_string)
;;

(* The verdict issues [to_anchor] after the event's sample, plus the [p] that [add t, p]
   adds, plus its phase: all but [to_anchor] from the kernel's table. *)
let check_latency table ~anchor ~to_anchor ~verdict_phase ~latency =
  let open Or_error.Let_syntax in
  let%bind period = certified_period table ~pc:(anchor + 1) in
  let certified = to_anchor + period + verdict_phase in
  if certified = latency
  then Ok ()
  else bug "certified latency %d, asked for %d" certified latency
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
  let%bind () = fits_budget ~latency budget in
  let%bind source, program = assemble ~budget:(Int.max 0 budget) in
  let config = Asm.Program.configure program config in
  let%bind table, verdict_phase = certify t ~config ~latency ~budget program in
  let%bind () =
    check_latency table ~anchor:anchor_pc ~to_anchor ~verdict_phase ~latency
  in
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
    ; budget_from_host = Option.some_if (from_host budget) budget
    ; certificate =
        { latency
        ; jitter = 0
        ; sampling
        ; verdict_pcs = pcs (Array.of_list program.instructions) ~f:is_verdict
        }
    }
;;

(* Where [pc] may go next: its fall through, across the wrap, and a jump's target. *)
let successors (config : Program_config.t) (instructions : Isa.t array) pc =
  let following = if pc = config.wrap_top then config.wrap_bottom else pc + 1 in
  let following =
    List.filter [ following ] ~f:(fun pc -> pc < Array.length instructions)
  in
  match instructions.(pc) with
  | Jmp { cond = Always; target } -> [ target ]
  | Jmp { target; _ } -> target :: following
  | Op _ -> following
;;

let samples_pin : Isa.t -> bool = function
  | Jmp { cond = Pin | Not_pin; _ } | Op { op = Wait (Pin_level _); _ } -> true
  | _ -> false
;;

(* Every way into an anchor is a sample of the pin [to_anchor] cycles before. *)
let anchored_by_samples config (instructions : Isa.t array) ~to_anchor =
  let enters_anchor pc =
    List.exists (successors config instructions pc) ~f:(fun next ->
      is_anchor instructions.(next))
  in
  match
    List.find
      (List.init (Array.length instructions) ~f:Fn.id)
      ~f:(fun pc ->
        enters_anchor pc
        && not (samples_pin instructions.(pc) && cycles instructions.(pc) = to_anchor))
  with
  | None -> Ok ()
  | Some pc -> bug "pc %d enters an anchor but not %d cycles after a sample" pc to_anchor
;;

(* A half's samples of the pin in cycles from its deadline, all read from the kernel's
   table: its loop's polls [-slope] apart down to the offset, the poll after the pad and
   the level wait from its issue on. Gives the longest gap between samples, counting from
   the one that anchored the half, and the cycles from the last poll to the verdict. *)
let polled_half config table (instructions : Isa.t array) ~anchor ~to_anchor =
  let open Or_error.Let_syntax in
  let poll = anchor + 3 in
  let row : _ Kernel.Row.t = table.(poll) in
  let slope = Bits.to_signed_int row.slope in
  let%bind offset =
    exactly
      "offset"
      ~pc:poll
      (Bits.to_signed_int row.offset_lo)
      (Bits.to_signed_int row.offset_hi)
  in
  let%bind count =
    match instructions.(anchor + 2) with
    | Op { op = Set { dest = X; value }; _ }
      when slope < 0 && value = Bits.to_unsigned_int row.x_hi -> Ok value
    | _ -> bug "the polls at pc %d are not counted" poll
  in
  let pad = List.find_exn (pcs instructions ~f:is_pad) ~f:(fun pc -> pc > anchor) in
  let final = pad + 1 in
  let verdict = pad + 2 in
  let level_wait = verdict + 2 in
  let%bind () =
    let jumps_to_anchor pc =
      match instructions.(pc) with
      | Jmp { cond = Pin | Not_pin; target } -> is_anchor instructions.(target)
      | _ -> false
    in
    if jumps_to_anchor poll
       && jumps_to_anchor final
       && is_verdict instructions.(verdict)
       && level_wait < Array.length instructions
       && samples_pin instructions.(level_wait)
       && List.for_all (successors config instructions level_wait) ~f:(fun next ->
         is_anchor instructions.(next))
    then Ok ()
    else bug "the half at pc %d is not laid out as polls" anchor
  in
  let%bind period = certified_period table ~pc:(anchor + 1)
  and final_phase = certified_phase table ~pc:final
  and verdict_phase = certified_phase table ~pc:verdict
  and level_phase = certified_phase table ~pc:level_wait in
  let anchored = -period - to_anchor in
  let gaps =
    [ offset + (slope * count) - anchored
    ; (if count > 0 then -slope else 0)
    ; final_phase - offset
    ; level_phase - final_phase
    ]
  in
  return (List.fold gaps ~init:0 ~f:Int.max, verdict_phase - final_phase)
;;

(* Polls are spaced out only as far as [set x] needs to count them, since the space
   between them is the jitter. *)
let compile_quiet ~config ~verdict_pin ~latency t ~pin =
  let open Or_error.Let_syntax in
  let assemble ~header ~budget ~loops ~stretch =
    let source = quiet_source ~pin ~header ~budget ~loops ~stretch in
    let%map program = Asm.assemble source in
    source, program
  in
  (* the layout does not depend on the budget or the count, so a probe at zero finds it *)
  let probe stretch =
    let%bind _, probe = assemble ~header:"" ~budget:0 ~loops:0 ~stretch in
    let instructions = Array.of_list probe.instructions in
    let%map pad_at_zero =
      match pad_lateness (Analyser.analyse ~config probe.instructions) with
      | Some late -> Ok late
      | None -> bug "the pad wait has no bound"
    in
    stretch, instructions, pad_at_zero
  in
  let%bind _, instructions, _ = probe None in
  let anchor = List.hd_exn (pcs instructions ~f:is_anchor) in
  let pad = List.hd_exn (pcs instructions ~f:is_pad) in
  let verdict = List.hd_exn (pcs instructions ~f:is_verdict) in
  (* a poll's jump and the level wait's delay each anchor [to_anchor] after the edge *)
  let to_anchor = Isa.jmp_cycles in
  let verdict_phase = cycles_between instructions ~first:pad ~last:verdict in
  let budget = latency - to_anchor - verdict_phase in
  let%bind () = fits_budget ~latency budget in
  let most_loops = (1 lsl Isa.Field.set_value.width) - 1 in
  let%bind stretch, loops =
    let fits (stretch, instructions, pad_at_zero) =
      let poll = anchor + 3 in
      let back = pad - 1 + Bool.to_int (Option.is_some stretch) in
      let loop_period = cycles_between instructions ~first:poll ~last:(back + 1) in
      let loops = Int.max 0 ((budget - pad_at_zero) / loop_period) in
      Option.some_if (loops <= most_loops) (stretch, loops)
    in
    let rec search = function
      | [] -> refuse "latency %d is beyond %d polls however far apart" latency most_loops
      | stretch :: wider ->
        let%bind probed = probe stretch in
        (match fits probed with
         | Some fit -> Ok fit
         | None -> search wider)
    in
    search (None :: List.init (1 lsl Isa.delay_bits) ~f:Option.some)
  in
  let%bind _, program = assemble ~header:"" ~budget:(Int.max 0 budget) ~loops ~stretch in
  let config = Asm.Program.configure program config in
  let%bind table, verdict_phase = certify t ~config ~latency ~budget program in
  let%bind () = check_latency table ~anchor ~to_anchor ~verdict_phase ~latency in
  let%bind min_run, unseen_before_verdict =
    let instructions = Array.of_list program.instructions in
    let%bind () = anchored_by_samples config instructions ~to_anchor in
    let%map halves =
      pcs instructions ~f:is_anchor
      |> List.map ~f:(fun anchor ->
        polled_half config table instructions ~anchor ~to_anchor)
      |> Or_error.all
    in
    List.fold halves ~init:(0, 0) ~f:(fun (run, unseen) (run', unseen') ->
      Int.max run run', Int.max unseen unseen')
  in
  let jitter = min_run - 1 in
  (* the header is a comment, so the source assembles to [program] *)
  let header = [%string "; %{to_string t}: %{pulses ~verdict_pin ~latency ~jitter}"] in
  return
    { Firmware.source =
        quiet_source ~pin ~header ~budget:(Int.max 0 budget) ~loops ~stretch
    ; program
    ; config
    ; budget_from_host = Option.some_if (from_host budget) budget
    ; certificate =
        { latency
        ; jitter
        ; sampling = Polls { min_run; unseen_before_verdict }
        ; verdict_pcs = pcs (Array.of_list program.instructions) ~f:is_verdict
        }
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
