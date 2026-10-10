open! Core
open Protocol_emulator

module Sheet = struct
  type t =
    { part : string
    ; document : string
    ; page : string
    }
end

module Margin = struct
  type t =
    | Cycle
    | Ns of
        { ns : float
        ; why : string
        }
end

module Levels = struct
  type t = (bool * int) list
end

module Bound = struct
  type t =
    | Kernel of (Program_config.t -> int -> Kernel.Spacing.Spec.t)
    | Run of
        { pin : Program_config.t -> int
        ; widths : clock_hz:int -> Levels.t -> int list
        }
end

module Limit = struct
  type t =
    | At_least of float
    | At_most of float
end

type t =
  { firmware : string
  ; parameter : string
  ; limit : Limit.t
  ; sheet : Sheet.t
  ; margin : Margin.t
  ; bound : Bound.t
  }

let none ~own:_ ~other:_ = 0
let never ~own:_ ~other:_ = false

(* [n] cycles at least before an edge of [a] where [hold] holds of the two bits before it,
   and since [b]'s last edge where [apart] does *)
let spacing ?(dirs = false) ?(hold = never) ?(apart = never) ~a ~b () n =
  let at f ~own ~other = if f ~own ~other then n else 0 in
  let hold = at hold
  and apart = at apart in
  { Kernel.Spacing.Spec.a
  ; b
  ; dirs
  ; hold_a = hold
  ; apart_a = apart
  ; hold_b = none
  ; apart_b = none
  }
;;

let swap (spec : Kernel.Spacing.Spec.t) =
  { spec with
    a = spec.b
  ; b = spec.a
  ; hold_a = spec.hold_b
  ; apart_a = spec.apart_b
  ; hold_b = spec.hold_a
  ; apart_b = spec.apart_a
  }
;;

(* one pin at one level: high, or for [dirs] held low *)
let level ?dirs ~pin ~high () =
  Bound.Kernel
    (fun config ->
      let a = pin config in
      spacing ?dirs ~a ~b:(a + 1) ~hold:(fun ~own ~other:_ -> Bool.equal own high) ())
;;

let set_pin (config : Program_config.t) = config.set_base
let side_pin (config : Program_config.t) = config.side_set_base
let cycles ~clock_hz ns = Float.iround_down_exn (ns *. Float.of_int clock_hz /. 1e9)

(* each level after the one before it *)
let pairs (levels : Levels.t) =
  List.zip_exn (List.drop_last_exn levels) (List.tl_exn levels)
;;

let run ~pin widths = Bound.Run { pin; widths }
let lows levels = List.filter_map levels ~f:(fun (high, n) -> Option.some_if (not high) n)

(* every line pulled up, nothing else driving, and the host on time *)
let levels (bench : Bench.t) ~pin (stimulus : Bench.Stimulus.t) =
  let timed = Bench.timed bench in
  let inputs = (1 lsl Isa.num_pins) - 1 in
  let level machine = (Machine.pins machine ~inputs lsr pin) land 1 = 1 in
  let rec go machine ~cycle ~queued ~bursts ~quiet acc =
    if cycle = stimulus.cycles
    then (
      if not (Machine.Fault.equal machine.Machine.fault Machine.Fault.none)
      then
        raise_s
          [%message
            "BUG: the run faulted" bench.name ~fault:(machine.fault : Machine.Fault.t)];
      (* the last level has not ended *)
      List.tl_exn acc |> List.rev)
    else (
      let queued, bursts =
        match queued, bursts with
        | [], next :: bursts when List.is_empty machine.tx_fifo && quiet >= stimulus.quiet
          -> next, bursts
        | _ -> queued, bursts
      in
      let machine, queued =
        match queued with
        | word :: rest when List.length machine.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx machine word |> ok_exn, rest
        | _ -> machine, queued
      in
      let before = level machine in
      let machine = Machine.step machine ~inputs in
      let machine = Option.value_map (Machine.read_rx machine) ~default:machine ~f:snd in
      let now = level machine in
      let acc =
        match acc with
        | (high, n) :: rest when Bool.equal high now -> (high, n + 1) :: rest
        | acc -> (now, 1) :: acc
      in
      go
        machine
        ~cycle:(cycle + 1)
        ~queued
        ~bursts
        ~quiet:(if Bool.equal before now then quiet + 1 else 0)
        acc)
  in
  let machine =
    Machine.create
      ~config:(Timed_program.config timed)
      ~program:(Timed_program.words timed)
    |> ok_exn
  in
  (* the load, if any, goes first *)
  let bursts =
    match stimulus.bursts with
    | first :: rest -> (Option.to_list bench.load @ first) :: rest
    | [] -> []
  in
  go machine ~cycle:0 ~queued:[] ~bursts ~quiet:0 []
;;

module Verdict = struct
  type t =
    { limit : Limit.t
    ; needed : int
    ; bound : int option
    ; ok : bool
    }
end

let picoseconds ns = Float.iround_nearest_exn (ns *. 1000.)

(* the least or most cycles that clear the limit by the margin *)
let needed ~clock_hz (limit : Limit.t) (margin : Margin.t) =
  let per_ps = 1_000_000_000_000 in
  let cycle, margin_ps =
    match margin with
    | Cycle -> 1, 0
    | Ns { ns; why = _ } -> 0, picoseconds ns
  in
  match limit with
  | At_least ns ->
    ((((picoseconds ns + margin_ps) * clock_hz) + per_ps - 1) / per_ps) + cycle
  | At_most ns -> ((picoseconds ns - margin_ps) * clock_hz / per_ps) - cycle
;;

let kernel_accepts (bench : Bench.t) spec =
  let program = Asm.assemble bench.source |> ok_exn in
  let config = Asm.Program.configure program bench.config in
  let words = Asm.Program.words program |> ok_exn in
  let single_capture_edge =
    match bench.assumption with
    | Receiver _ -> true
    | Nothing | Floor _ | Period _ -> false
  in
  let period = Bench.period bench in
  let table =
    Analyser.analyse ?period ~single_capture_edge ~config program.instructions
    |> Kernel.Table.of_analyser
    |> Kernel.Table.with_edges
         ~single_capture_edge
         ~config
         ~spacing:(Kernel.Spacing.of_spec config spec)
         ~words
  in
  Kernel.check ?period ~single_capture_edge ~spacing:spec ~config ~words table
  |> Result.is_ok
;;

(* the most cycles the kernel accepts, by bisection: [ok] holds at [lo] and not at [hi] *)
let rec most ~ok ~lo ~hi =
  if hi - lo <= 1
  then lo
  else (
    let mid = (lo + hi) / 2 in
    if ok mid then most ~ok ~lo:mid ~hi else most ~ok ~lo ~hi:mid)
;;

let check limits (bench : Bench.t) =
  let limits = List.filter limits ~f:(fun t -> String.equal t.firmware bench.name) in
  List.map limits ~f:(fun t ->
    let needed = needed ~clock_hz:bench.clock_hz t.limit t.margin in
    let bound =
      match t.bound, t.limit with
      | Kernel spec, At_least _ ->
        let ok n = kernel_accepts bench (spec bench.config n) in
        if not (ok 0) then None else Some (most ~ok ~lo:0 ~hi:(1 lsl 16))
      | Kernel _, At_most _ -> raise_s [%message "BUG: the kernel bounds least widths"]
      | Run { pin; widths }, limit ->
        let stimulus =
          match bench.stimulus with
          | Some stimulus -> stimulus
          | None -> raise_s [%message "BUG: no stimulus to run" bench.name]
        in
        let widths =
          widths ~clock_hz:bench.clock_hz (levels bench ~pin:(pin bench.config) stimulus)
        in
        (match limit with
         | At_least _ -> List.min_elt widths ~compare
         | At_most _ -> List.max_elt widths ~compare)
    in
    let ok =
      match t.limit, bound with
      | _, None -> false
      | At_least _, Some bound -> bound >= needed
      | At_most _, Some bound -> bound <= needed
    in
    t, { Verdict.limit = t.limit; needed; bound; ok })
;;

let ns ~clock_hz cycles = Float.of_int cycles *. 1e9 /. Float.of_int clock_hz

let to_string (bench : Bench.t) verdicts =
  List.map verdicts ~f:(fun (t, (v : Verdict.t)) ->
    let side, limit =
      match v.limit with
      | At_least ns -> ">=", ns
      | At_most ns -> "<=", ns
    in
    let margin =
      match t.margin with
      | Cycle -> "a cycle"
      | Ns { ns; why } -> sprintf "%g ns, %s" ns why
    in
    let kind =
      match t.bound with
      | Kernel _ -> "kernel"
      | Run _ -> "run"
    in
    let bound =
      Option.value_map v.bound ~default:"none" ~f:(fun cycles ->
        sprintf "%d (%.1f ns)" cycles (ns ~clock_hz:bench.clock_hz cycles))
    in
    sprintf
      "%-18s %-14s %s %8g ns  %-6s %-17s needs %4d%-5s  %s, %s %s; margin %s"
      bench.name
      t.parameter
      side
      limit
      kind
      bound
      v.needed
      (if v.ok then "" else " FAIL")
      t.sheet.part
      t.sheet.document
      t.sheet.page
      margin)
  |> String.concat ~sep:"\n"
;;

let check_exn limits ~exempt (bench : Bench.t) =
  match check limits bench with
  | [] when not (List.Assoc.mem exempt bench.name ~equal:String.equal) ->
    raise_s [%message "no datasheet limits, and no reason why" bench.name]
  | verdicts ->
    if not (List.for_all verdicts ~f:(fun (_, v) -> v.ok))
    then
      raise_s
        [%message
          "a datasheet limit is not cleared" ~_:(to_string bench verdicts : string)]
;;
