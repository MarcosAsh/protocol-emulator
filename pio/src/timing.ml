open! Core
open Protocol_emulator

module Pin_ref = struct
  type t =
    | Side of int
    | Set of int
    | Out of int
    | In of int
    | Jmp_pin
    | Gpio of int
  [@@deriving sexp_of, equal]

  let to_string = function
    | Side i -> [%string "side%{i#Int}"]
    | Set i -> [%string "set%{i#Int}"]
    | Out i -> [%string "out%{i#Int}"]
    | In i -> [%string "in%{i#Int}"]
    | Jmp_pin -> "jmp pin"
    | Gpio i -> [%string "gpio%{i#Int}"]
  ;;
end

module Drive = struct
  type t =
    | Level
    | Dir
    | Dir_low
    | Input
  [@@deriving sexp_of]
end

module Pin = struct
  type t =
    { name : string
    ; bindings : (Pin_ref.t * Drive.t) list
    ; initial : bool option
    }
  [@@deriving sexp_of]

  let binding_of_string text : (Pin_ref.t * Drive.t) Or_error.t =
    let body, drive =
      match String.lsplit2 text ~on:':' with
      | Some (body, drive) -> body, Some drive
      | None -> text, None
    in
    let indexed prefix =
      Option.bind (String.chop_prefix body ~prefix) ~f:Int.of_string_opt
    in
    let output (make : int -> Pin_ref.t) index =
      match drive with
      | None -> Ok (make index, Drive.Level)
      | Some "dir" -> Ok (make index, Dir)
      | Some "!dir" -> Ok (make index, Dir_low)
      | Some drive -> Or_error.error_s [%message "bad drive" (drive : string)]
    in
    match
      body, indexed "side", indexed "set", indexed "out", indexed "in", indexed "gpio"
    with
    | "jmp", _, _, _, _, _ -> Ok (Jmp_pin, Input)
    | _, Some index, _, _, _, _ -> output (fun i -> Side i) index
    | _, _, Some index, _, _, _ -> output (fun i -> Set i) index
    | _, _, _, Some index, _, _ -> output (fun i -> Out i) index
    | _, _, _, _, Some index, _ -> Ok (In index, Input)
    | _, _, _, _, _, Some index -> Ok (Gpio index, Input)
    | _ -> Or_error.error_s [%message "bad pin binding" (text : string)]
  ;;

  let of_string text =
    match String.lsplit2 text ~on:'=' with
    | None -> Or_error.error_s [%message "expected name=bindings" (text : string)]
    | Some (name, bindings) ->
      let%map.Or_error bindings =
        String.split bindings ~on:',' |> List.map ~f:binding_of_string |> Or_error.all
      in
      { name; bindings; initial = None }
  ;;

  let is_output t =
    List.exists t.bindings ~f:(fun (_, drive) ->
      match drive with
      | Level | Dir | Dir_low -> true
      | Input -> false)
  ;;
end

module Edge = struct
  type t =
    { pin : string
    ; rising : bool option
    }
  [@@deriving sexp_of]

  let of_string text =
    match String.chop_suffix text ~suffix:"+", String.chop_suffix text ~suffix:"-" with
    | Some pin, _ -> { pin; rising = Some true }
    | _, Some pin -> { pin; rising = Some false }
    | None, None -> { pin = text; rising = None }
  ;;

  let to_string { pin; rising } =
    match rising with
    | Some true -> pin ^ "+"
    | Some false -> pin ^ "-"
    | None -> pin
  ;;
end

module Time = struct
  type t =
    | Cycles of int
    | Ns of float
  [@@deriving sexp_of]

  let of_string text =
    let number text scale =
      match Float.of_string_opt text with
      | Some value -> Ok (Ns (value *. scale))
      | None -> Or_error.error_s [%message "bad time" (text : string)]
    in
    match
      ( String.chop_suffix text ~suffix:"ns"
      , String.chop_suffix text ~suffix:"us"
      , String.chop_suffix text ~suffix:"cy" )
    with
    | Some value, _, _ -> number value 1.
    | _, Some value, _ -> number value 1000.
    | _, _, cycles ->
      let value = Option.value cycles ~default:text in
      (match Int.of_string_opt value with
       | Some cycles -> Ok (Cycles cycles)
       | None -> Or_error.error_s [%message "bad time" (text : string)])
  ;;

  let to_string = function
    | Cycles cycles -> [%string "%{cycles#Int} cycles"]
    | Ns ns when Float.( >= ) ns 1000. -> sprintf "%gus" (ns /. 1000.)
    | Ns ns -> sprintf "%gns" ns
  ;;
end

module Rule = struct
  type t =
    { name : string
    ; source : Edge.t
    ; target : Edge.t
    ; at_least : Time.t
    }
  [@@deriving sexp_of]

  let of_string text =
    let name, body =
      match String.lsplit2 text ~on:':' with
      | Some (name, body) -> String.strip name, body
      | None -> text, text
    in
    match String.split body ~on:' ' |> List.filter ~f:(Fn.non String.is_empty) with
    | [ source; "->"; target; ">="; time ] ->
      let%map.Or_error at_least = Time.of_string time in
      { name; source = Edge.of_string source; target = Edge.of_string target; at_least }
    | _ -> Or_error.error_s [%message "expected 'name: a- -> b+ >= 4us'" (text : string)]
  ;;
end

module Clock = struct
  type t =
    { sys_hz : float
    ; clkdiv : float
    }
  [@@deriving sexp_of]

  (* pico-sdk's pio_calculate_clkdiv8_from_float, in single precision, with
     PICO_CLKDIV_ROUND_NEAREST on as it is by default:
     {v
       div += 0.5f / 256;
       div_int = (uint16_t)div;
       div_frac8 = div_int == 0 ? 0 : (uint8_t)((div - div_int) * 256);
     v}
     An integer part of 0 is the hardware's 65536. *)
  let effective_div { clkdiv; _ } =
    let single value = Int32.float_of_bits (Int32.bits_of_float value) in
    let div = single (single clkdiv +. (0.5 /. 256.)) in
    let whole = Float.round_down div in
    if Float.( >= ) whole 65536.
    then 65536.
    else whole +. (Float.round_down ((div -. whole) *. 256.) /. 256.)
  ;;

  (* A fractional divider spaces ticks by the floor or the ceiling of the divider, so [n]
     ticks span at least the floor of [n] times it. *)
  let min_ns t cycles =
    Float.round_down (Float.of_int cycles *. effective_div t) *. 1e9 /. t.sys_hz
  ;;
end

module Exec_sequence = struct
  type t =
    { guard : (string * int) list
    ; instructions : Pioasm.Instruction.t list
    }
  [@@deriving sexp_of]

  let guard_of_string text =
    String.split text ~on:','
    |> List.map ~f:(fun term ->
      match String.lsplit2 (String.strip term) ~on:'=' with
      | Some (name, value) when Option.is_some (Int.of_string_opt value) ->
        Ok (name, Int.of_string value)
      | _ -> Or_error.error_s [%message "bad guard" (term : string)])
    |> Or_error.all
  ;;

  let of_string program text =
    let%bind.Or_error guard, body =
      match String.lsplit2 text ~on:':' with
      | Some (guard, body) ->
        let%map.Or_error guard = guard_of_string guard in
        guard, body
      | None -> Ok ([], text)
    in
    let%map.Or_error instructions =
      String.split body ~on:'|'
      |> List.map ~f:(Pioasm.parse_instruction program)
      |> Or_error.all
    in
    { guard; instructions }
  ;;
end

module Config = struct
  type t =
    { pins : Pin.t list
    ; autopull : bool
    ; autopush : bool
    ; fifo_ready : bool
    ; irq_wait_halts : bool
    ; set_count : int
    ; out_count : int
    ; exec : Exec_sequence.t list
    ; clock : Clock.t option
    ; rules : Rule.t list
    ; cell : int option
    ; entry : string option
    }
  [@@deriving sexp_of]

  let default =
    { pins = []
    ; autopull = false
    ; autopush = false
    ; fifo_ready = false
    ; irq_wait_halts = false
    ; set_count = 1
    ; out_count = 1
    ; exec = []
    ; clock = None
    ; rules = []
    ; cell = None
    ; entry = None
    }
  ;;
end

module Level = struct
  type t =
    | Low
    | High
    | Unknown
  [@@deriving sexp_of, compare, equal, hash]

  let of_bool = function
    | Some true -> High
    | Some false -> Low
    | None -> Unknown
  ;;
end

(* Cycles since something last happened; [None] when it never has on any path. *)
module Since = struct
  type t = Interval.t option [@@deriving sexp_of, compare, equal]

  let zero = Some (Interval.exactly 0)

  let join a b =
    match a, b with
    | None, None -> None
    | Some a, Some b -> Some (Interval.join a b)
    | Some a, None | None, Some a -> Some { a with hi = None }
  ;;

  let shift t cycles = Option.map t ~f:(fun t -> Interval.shift t cycles)
  let stall t = Option.map t ~f:(fun (t : Interval.t) -> { t with hi = None })

  let widen ~(old : t) (t : t) =
    match old, t with
    | Some old, Some t ->
      Some { t with hi = (if [%equal: int option] old.hi t.hi then t.hi else None) }
    | _, t -> t
  ;;

  (* The more recent of two. *)
  let min a b =
    match a, b with
    | None, t | t, None -> t
    | Some (a : Interval.t), Some (b : Interval.t) ->
      let lo = Option.map2 a.lo b.lo ~f:Int.min in
      let hi =
        match a.hi, b.hi with
        | None, hi | hi, None -> hi
        | Some a, Some b -> Some (Int.min a b)
      in
      Some { Interval.lo; hi }
  ;;

  let to_string = function
    | None -> "-"
    | Some t -> Interval.to_string t
  ;;
end

module Key = struct
  type t =
    { pc : int
    ; exec : (int * int) option
    ; x : int option
    ; y : int option
    ; levels : Level.t list
    ; seen : bool list
    (** Which of the phase and each pin's rise and fall have happened, so a path from
        entry joins no path that has them. *)
    }
  [@@deriving sexp_of, compare, hash]
end

module Timing = struct
  type t =
    { phase : Since.t
    ; rise : Since.t list
    ; fall : Since.t list
    }
  [@@deriving sexp_of, equal]

  let map t ~f =
    { phase = f t.phase; rise = List.map t.rise ~f; fall = List.map t.fall ~f }
  ;;

  let shift t cycles = map t ~f:(fun since -> Since.shift since cycles)

  let map2 a b ~f =
    { phase = f a.phase b.phase
    ; rise = List.map2_exn a.rise b.rise ~f
    ; fall = List.map2_exn a.fall b.fall ~f
    }
  ;;

  let join a b = map2 a b ~f:Since.join
  let seen t = List.map (t.phase :: (t.rise @ t.fall)) ~f:Option.is_some
  let widen ~old t = map2 old t ~f:(fun old t -> Since.widen ~old t)
end

module Row_id = struct
  type t =
    { pc : int
    ; exec : (int * int) option
    }
  [@@deriving sexp_of, compare, hash]
end

module Event = struct
  type t =
    | Phase of Since.t
    | Edge of
        { pin : string
        ; rising : bool
        ; width : Since.t
        }
    | Sample of
        { pin : string
        ; phase : Since.t
        ; own : (Since.t * Since.t) option
        (** Cycles since the last rise and fall of an output of the same name. *)
        }
    | Anchor
    | Unmodelled of string
    | Rule of
        { rule : int
        ; value : Interval.t
        }
  [@@deriving sexp_of, compare]
end

module Row = struct
  type t =
    { id : Row_id.t
    ; text : string
    ; cycles : string
    ; events : Event.t list
    }
  [@@deriving sexp_of]
end

module Report = struct
  type t =
    { program : string
    ; rows : Row.t list
    ; rules : Rule.t list
    ; clock : Clock.t option
    ; cell : int option
    ; errors : string list
    }
  [@@deriving sexp_of]

  let rule_values t index =
    List.concat_map t.rows ~f:(fun row ->
      List.filter_map row.events ~f:(function
        | Rule { rule; value } when rule = index -> Some (row, value)
        | _ -> None))
  ;;

  let unmodelled t =
    List.concat_map t.rows ~f:(fun row ->
      List.filter_map row.events ~f:(function
        | Unmodelled why -> Some [%string "pc %{row.id.pc#Int}: %{why}"]
        | _ -> None))
  ;;

  let lowest values =
    List.filter_map values ~f:(fun (row, (value : Interval.t)) ->
      Option.map value.lo ~f:(fun lo -> lo, row))
    |> List.min_elt ~compare:(fun (a, _) (b, _) -> Int.compare a b)
  ;;

  let rule_verdict t index (rule : Rule.t) =
    match lowest (rule_values t index) with
    | None -> Ok None
    | Some (cycles, row) ->
      (match rule.at_least, t.clock with
       | Cycles at_least, _ -> Ok (Some (cycles, row, cycles >= at_least, None))
       | Ns at_least, Some clock ->
         let ns = Clock.min_ns clock cycles in
         Ok (Some (cycles, row, Float.( >= ) (ns +. 1e-6) at_least, Some ns))
       | Ns _, None -> Error "needs a clock")
  ;;

  let passed t =
    List.is_empty t.errors
    && List.is_empty (unmodelled t)
    && List.for_alli t.rules ~f:(fun index rule ->
      match rule_verdict t index rule with
      | Ok None -> true
      | Ok (Some (_, _, ok, _)) -> ok
      | Error _ -> false)
  ;;

  let values to_string list =
    let list = List.dedup_and_sort list ~compare:[%compare: Since.t] in
    if List.length list <= 6
    then List.map list ~f:to_string |> String.concat ~sep:","
    else to_string (List.reduce_exn list ~f:Since.join)
  ;;

  let row_line (row : Row.t) =
    let phases =
      List.filter_map row.events ~f:(function
        | Phase phase -> Some phase
        | _ -> None)
    in
    let edges =
      List.filter_map row.events ~f:(function
        | Edge { pin; rising; width } -> Some ((pin, rising), width)
        | _ -> None)
      |> List.Assoc.sort_and_group ~compare:[%compare: string * bool]
      |> List.map ~f:(fun ((pin, rising), widths) ->
        let sign = if rising then "+" else "-" in
        match values Since.to_string widths with
        | "-" -> pin ^ sign
        | widths -> [%string "%{pin}%{sign} %{widths}"])
    in
    let samples =
      List.filter_map row.events ~f:(function
        | Sample { pin; own; _ } -> Some (pin, own)
        | _ -> None)
      |> List.Assoc.sort_and_group ~compare:String.compare
      |> List.map ~f:(fun (pin, owns) ->
        match List.filter_opt owns with
        | [] -> "samples " ^ pin
        | owns ->
          let rise = values Since.to_string (List.map owns ~f:fst) in
          let fall = values Since.to_string (List.map owns ~f:snd) in
          [%string "samples %{pin} (%{pin}+ %{rise}, %{pin}- %{fall})"])
    in
    let anchor =
      if List.exists row.events ~f:(function
           | Anchor -> true
           | _ -> false)
      then [ "anchor" ]
      else []
    in
    let text =
      match row.id.exec with
      | None -> row.text
      | Some _ -> "  exec " ^ row.text
    in
    sprintf
      "%3d  %-30s %4s  %-14s %s"
      row.id.pc
      text
      row.cycles
      (values Since.to_string phases)
      (String.concat ~sep:"  " (edges @ samples @ anchor))
    |> String.rstrip
  ;;

  (* A sample at phase [p] lands [p, p + 1) cycles after the edge its wait saw, since a
     wait releases on the first tick after the edge. With a clock this is in system
     clocks: the release also waits for the synchroniser's clock, [n] ticks of a
     fractional divider span the floor to the ceiling of [n] times it, and the divider is
     the one the SDK programs while the sender runs at the one asked for. A wait's own sample
     follows its stall, so it is unbounded and left out. *)
  let receiver_line t cell =
    let earliest, latest, cell_length =
      match t.clock with
      | None ->
        (fun lo -> Float.of_int lo), (fun hi -> Float.of_int (hi + 1)), Float.of_int cell
      | Some clock ->
        let div = Clock.effective_div clock in
        ( (fun lo -> Float.round_down (Float.of_int lo *. div) -. 1.)
        , (fun hi -> Float.round_up (Float.of_int hi *. div) +. Float.round_up div +. 1.)
        , Float.of_int cell *. clock.clkdiv )
    in
    let samples =
      List.concat_map t.rows ~f:(fun row ->
        List.filter_map row.events ~f:(function
          | Sample { phase = Some { lo = Some lo; hi = Some hi }; _ } -> Some (lo, hi)
          | _ -> None))
      |> List.dedup_and_sort ~compare:[%compare: int * int]
    in
    let straddles = List.filter samples ~f:(fun (lo, hi) -> lo / cell <> hi / cell) in
    let fast =
      List.map samples ~f:(fun (lo, hi) ->
        latest hi /. (Float.of_int ((lo / cell) + 1) *. cell_length))
      |> List.max_elt ~compare:Float.compare
    in
    let slow =
      List.filter_map samples ~f:(fun (lo, _) ->
        let k = lo / cell in
        Option.some_if (k > 0) (earliest lo /. (Float.of_int k *. cell_length)))
      |> List.min_elt ~compare:Float.compare
    in
    let percent ratio = sprintf "%.2f%%" (Float.abs ratio *. 100.) in
    let tolerance =
      match fast, slow with
      | Some fast, Some slow when List.is_empty straddles ->
        [%string
          "sender may run %{percent (1. -. fast)} fast or %{percent (slow -. 1.)} slow"]
      | _, _ when not (List.is_empty straddles) -> "a sample straddles a cell boundary"
      | _ -> "no bounded samples"
    in
    [%string "cells of %{cell#Int} cycles from each anchor: %{tolerance}"]
  ;;

  let to_string t =
    let rows = List.map t.rows ~f:row_line in
    let rule_lines =
      List.mapi t.rules ~f:(fun index (rule : Rule.t) ->
        let head =
          [%string
            "%{rule.name}: %{Edge.to_string rule.source} -> %{Edge.to_string \
             rule.target} >= %{Time.to_string rule.at_least}"]
        in
        match rule_verdict t index rule with
        | Error why -> [%string "%{head}: %{why}"]
        | Ok None -> [%string "%{head}: never happens"]
        | Ok (Some (cycles, row, ok, ns)) ->
          let time =
            match ns with
            | Some ns -> sprintf " (%gns)" ns
            | None -> ""
          in
          let where =
            match row.id.exec with
            | None -> [%string "pc %{row.id.pc#Int}"]
            | Some _ -> [%string "pc %{row.id.pc#Int} exec %{row.text}"]
          in
          let verdict = if ok then "ok" else "FAIL" in
          [%string "%{head}: %{verdict}, %{cycles#Int} cycles%{time} at %{where}"])
    in
    let receiver =
      match t.cell with
      | Some cell -> [ receiver_line t cell ]
      | None -> []
    in
    let errors = List.map (t.errors @ unmodelled t) ~f:(fun error -> "ERROR " ^ error) in
    String.concat
      ~sep:"\n"
      (([ t.program ] @ rows @ rule_lines @ receiver @ errors) @ [ "" ])
  ;;
end

(* What an instruction writes: a pin group position, whether it is the direction bit, and
   the value when it is known. *)
module Write = struct
  type t =
    { pin : Pin_ref.t
    ; dir : bool
    ; value : bool option
    }
end

type context =
  { config : Config.t
  ; program : Pioasm.Program.t
  ; outputs : Pin.t array
  ; inputs : Pin.t list
  ; rules : (int * Rule.t * int option) list (* index, rule, source output *)
  ; emit : Row_id.t -> Event.t -> unit
  }

let cap value = Option.bind value ~f:(fun value -> Option.some_if (value <= 255) value)
let mask32 = 0xFFFF_FFFF

let reverse32 value =
  List.init 32 ~f:Fn.id
  |> List.fold ~init:0 ~f:(fun acc bit ->
    if value land (1 lsl bit) <> 0 then acc lor (1 lsl (31 - bit)) else acc)
;;

let known_source (key : Key.t) (source : Pioasm.Source.t) =
  match source with
  | X -> key.x
  | Y -> key.y
  | Null -> Some 0
  | Pins | Status | Isr | Osr -> None
;;

let apply_mov_op (op : Pioasm.Mov_op.t) value =
  match op with
  | Copy -> value
  | Invert -> Option.map value ~f:(fun value -> lnot value land mask32)
  | Reverse -> Option.map value ~f:reverse32
;;

let bits ~count ~make ~dir value =
  List.init count ~f:(fun bit ->
    { Write.pin = make bit
    ; dir
    ; value = Option.map value ~f:(fun value -> value land (1 lsl bit) <> 0)
    })
;;

let data_writes ctx (key : Key.t) (op : Pioasm.Op.t) =
  let set_pin i = Pin_ref.Set i in
  let out_pin i = Pin_ref.Out i in
  let out_count = ctx.config.out_count in
  (* The low [n] bits come from the OSR and the rest are zeroes (datasheet 3.4.5.2). *)
  let out_bits n ~dir =
    List.init out_count ~f:(fun bit ->
      { Write.pin = out_pin bit; dir; value = Option.some_if (bit >= n) false })
  in
  match op with
  | Set { destination = Pins; value } ->
    bits ~count:ctx.config.set_count ~make:set_pin ~dir:false (Some value)
  | Set { destination = Pindirs; value } ->
    bits ~count:ctx.config.set_count ~make:set_pin ~dir:true (Some value)
  | Out { destination = Pins; bits = n } -> out_bits n ~dir:false
  | Out { destination = Pindirs; bits = n } -> out_bits n ~dir:true
  | Mov { destination = Pins; op; source } ->
    bits
      ~count:out_count
      ~make:out_pin
      ~dir:false
      (apply_mov_op op (known_source key source))
  | Mov { destination = Pindirs; op; source } ->
    bits
      ~count:out_count
      ~make:out_pin
      ~dir:true
      (apply_mov_op op (known_source key source))
  | _ -> []
;;

let side_writes ctx (instruction : Pioasm.Instruction.t) =
  match instruction.side with
  | None -> []
  | Some value ->
    bits
      ~count:ctx.program.side_set.count
      ~make:(fun i -> Pin_ref.Side i)
      ~dir:ctx.program.side_set.pindirs
      (Some value)
;;

let level_of_write (pin : Pin.t) (write : Write.t) =
  List.find_map pin.bindings ~f:(fun (pin_ref, drive) ->
    if not (Pin_ref.equal pin_ref write.pin)
    then None
    else (
      match drive, write.dir with
      | Level, false | Dir, true -> Some (Level.of_bool write.value)
      | Dir_low, true -> Some (Level.of_bool (Option.map write.value ~f:not))
      | (Level | Dir | Dir_low | Input), _ -> None))
;;

(* Side-set wins a GPIO that the same instruction's OUT, SET or MOV also writes, level and
   direction separately (RP2040 datasheet 3.5.6). *)
let side_set_wins ctx ~side (data : Write.t) =
  Array.exists ctx.outputs ~f:(fun pin ->
    Option.is_some (level_of_write pin data)
    && List.exists side ~f:(fun (side : Write.t) ->
      Bool.equal side.dir data.dir && Option.is_some (level_of_write pin side)))
;;

(* Apply writes that land in the same cycle, report each edge with the width of the pulse
   it ends, and check the rules against it. *)
let write ctx ~row writes ((key : Key.t), (timing : Timing.t)) =
  let levels = Array.of_list key.levels in
  let rise = Array.of_list timing.rise in
  let fall = Array.of_list timing.fall in
  let edges =
    Array.to_list ctx.outputs
    |> List.filter_mapi ~f:(fun i pin ->
      List.find_map writes ~f:(level_of_write pin)
      |> Option.map ~f:(fun level ->
        let old = levels.(i) in
        let may_rise = (not (Level.equal level Low)) && not (Level.equal old High) in
        let may_fall = (not (Level.equal level High)) && not (Level.equal old Low) in
        levels.(i) <- level;
        i, may_rise, may_fall))
  in
  let before = Array.copy rise, Array.copy fall in
  List.iter edges ~f:(fun (i, may_rise, may_fall) ->
    if may_rise then rise.(i) <- Since.zero;
    if may_fall then fall.(i) <- Since.zero);
  let since (rise, fall) source (edge : Edge.t) =
    match edge.rising with
    | Some true -> rise.(source)
    | Some false -> fall.(source)
    | None -> Since.min rise.(source) fall.(source)
  in
  List.iter edges ~f:(fun (i, may_rise, may_fall) ->
    let name = ctx.outputs.(i).name in
    let emit_edge rising =
      let width = if rising then (snd before).(i) else (fst before).(i) in
      ctx.emit row (Edge { pin = name; rising; width });
      List.iter ctx.rules ~f:(fun (index, rule, source) ->
        match source with
        | Some source
          when String.equal rule.target.pin name
               && Option.value_map rule.target.rising ~default:true ~f:(Bool.equal rising)
          ->
          let after = rise, fall in
          let value = since (if source = i then before else after) source rule.source in
          Option.iter value ~f:(fun value -> ctx.emit row (Rule { rule = index; value }))
        | _ -> ())
    in
    if may_rise then emit_edge true;
    if may_fall then emit_edge false);
  ( { key with levels = Array.to_list levels }
  , { timing with rise = Array.to_list rise; fall = Array.to_list fall } )
;;

let sample ctx ~row (timing : Timing.t) pin_ref =
  let names =
    List.filter_map ctx.inputs ~f:(fun pin ->
      Option.some_if
        (List.exists pin.bindings ~f:(fun (bound, drive) ->
           Pin_ref.equal bound pin_ref
           &&
           match drive with
           | Input -> true
           | Level | Dir | Dir_low -> false))
        pin.name)
  in
  let names = if List.is_empty names then [ Pin_ref.to_string pin_ref ] else names in
  List.iter names ~f:(fun pin ->
    let own =
      Array.findi ctx.outputs ~f:(fun _ (output : Pin.t) -> String.equal output.name pin)
      |> Option.map ~f:(fun (i, _) ->
        List.nth_exn timing.rise i, List.nth_exn timing.fall i)
    in
    ctx.emit row (Sample { pin; phase = timing.phase; own }))
;;

let may_stall ctx (op : Pioasm.Op.t) =
  match op with
  | Wait _ | Irq { mode = Raise_and_wait; _ } -> true
  | Pull { block; _ } | Push { block; _ } -> block && not ctx.config.fifo_ready
  | Out _ -> ctx.config.autopull && not ctx.config.fifo_ready
  | In _ -> ctx.config.autopush && not ctx.config.fifo_ready
  | Jmp _ | Mov _ | Irq _ | Set _ -> false
;;

type control =
  | Next
  | Jump of int

(* One instruction from issue to the next issue: side-set, stall, execute, delay. The pin
   writes are applied together at issue, as they land with no stall: side-set and data
   edges may coincide, and any stall only lengthens what follows. *)
let rec execute ctx ~row (instruction : Pioasm.Instruction.t) state =
  let key, (timing : Timing.t) = state in
  ctx.emit row (Phase timing.phase);
  let side = side_writes ctx instruction in
  let data =
    data_writes ctx key instruction.op
    |> List.filter ~f:(fun data -> not (side_set_wins ctx ~side data))
  in
  let key, timing = write ctx ~row (side @ data) (key, timing) in
  let timing =
    if may_stall ctx instruction.op then Timing.map timing ~f:Since.stall else timing
  in
  let finish ?(delay = instruction.delay) key timing control =
    [ key, Timing.shift timing (1 + delay), control ]
  in
  let unmodelled why =
    ctx.emit row (Unmodelled why);
    []
  in
  match instruction.op with
  | Jmp { condition; target } ->
    let go key taken = finish key timing (if taken then Jump target else Next) in
    let register key ~get ~set ~decrement =
      match get key with
      | Some value when decrement ->
        if value = 0
        then go (set key None) false
        else go (set key (Some (value - 1))) true
      | Some value -> go key (value = 0)
      | None when decrement -> go key true @ go key false
      | None -> go (set key (Some 0)) true @ go key false
    in
    let x =
      register ~get:(fun (key : Key.t) -> key.x) ~set:(fun key x -> { key with x })
    in
    let y =
      register ~get:(fun (key : Key.t) -> key.y) ~set:(fun key y -> { key with y })
    in
    (match condition with
     | Always -> go key true
     | X_zero -> x key ~decrement:false
     | X_post_decrement -> x key ~decrement:true
     | Y_zero -> y key ~decrement:false
     | Y_post_decrement -> y key ~decrement:true
     | X_not_y ->
       (match key.x, key.y with
        | Some x, Some y -> go key (x <> y)
        | _ -> go key true @ go key false)
     | Pin ->
       sample ctx ~row timing Jmp_pin;
       go key true @ go key false
     | Osr_not_empty -> go key true @ go key false)
  | Wait { source; _ } ->
    (match source with
     | Pin index -> sample ctx ~row timing (In index)
     | Gpio index -> sample ctx ~row timing (Gpio index)
     | Jmp_pin -> sample ctx ~row timing Jmp_pin
     | Irq _ -> ());
    ctx.emit row Anchor;
    finish key { timing with phase = Since.zero } Next
  | In { source = Pins; bits } ->
    List.iter (List.init bits ~f:Fn.id) ~f:(fun bit ->
      if bit = 0
         || List.exists ctx.inputs ~f:(fun pin ->
           List.exists pin.bindings ~f:(fun (bound, _) -> Pin_ref.equal bound (In bit)))
      then sample ctx ~row timing (In bit));
    finish key timing Next
  | Mov { destination; op; source } ->
    if Pioasm.Source.equal source Pins then sample ctx ~row timing (In 0);
    let value = cap (apply_mov_op op (known_source key source)) in
    (match destination with
     | X -> finish { key with x = value } timing Next
     | Y -> finish { key with y = value } timing Next
     | Exec -> exec ctx ~row key timing
     | Pc -> unmodelled "mov pc"
     | Pins | Null | Pindirs | Isr | Osr -> finish key timing Next)
  | Out { destination; _ } ->
    (match destination with
     | X -> finish { key with x = None } timing Next
     | Y -> finish { key with y = None } timing Next
     | Exec -> exec ctx ~row key timing
     | Pc -> unmodelled "out pc"
     | Pins | Null | Pindirs | Isr | Osr -> finish key timing Next)
  | Irq { mode = Raise_and_wait; _ } when ctx.config.irq_wait_halts -> []
  | Set { destination = X; value } -> finish { key with x = Some value } timing Next
  | Set { destination = Y; value } -> finish { key with y = Some value } timing Next
  | In _ | Push _ | Pull _ | Irq _ | Set _ -> finish key timing Next

(* The executee runs on the next cycle; the delay of the [out] or [mov] is ignored. *)
and exec ctx ~(row : Row_id.t) (key : Key.t) timing =
  let timing = Timing.shift timing 1 in
  let sequences =
    List.map ctx.config.exec ~f:(fun sequence -> sequence.instructions) |> List.to_array
  in
  (* The key the sequence starts from, with its guard assumed, if the guard may hold. *)
  let start (sequence : Exec_sequence.t) =
    let register (value : int option) expected =
      match value with
      | None -> Some (Some expected)
      | Some value -> Option.some_if (value = expected) (Some value)
    in
    List.fold
      sequence.guard
      ~init:(Option.some_if (not (List.is_empty sequence.instructions)) key)
      ~f:(fun key (name, value) ->
        Option.bind key ~f:(fun (key : Key.t) ->
          match name with
          | "x" -> Option.map (register key.x value) ~f:(fun x -> { key with x })
          | "y" -> Option.map (register key.y value) ~f:(fun y -> { key with y })
          | name ->
            Array.findi ctx.outputs ~f:(fun _ (pin : Pin.t) -> String.equal pin.name name)
            |> Option.bind ~f:(fun (i, _) ->
              match List.nth_exn key.levels i, value with
              | Unknown, _ | High, 1 | Low, 0 -> Some key
              | (High | Low), _ -> None)))
  in
  let starts =
    match key.exec with
    | Some position -> [ position, key ]
    | None ->
      List.filter_mapi ctx.config.exec ~f:(fun i sequence ->
        Option.map (start sequence) ~f:(fun key -> (i, 0), key))
  in
  if List.is_empty ctx.config.exec
  then (
    ctx.emit row (Unmodelled "exec without an exec table");
    [])
  else if List.is_empty starts
  then (
    ctx.emit row (Unmodelled "exec where no sequence's guard may hold");
    [])
  else
    List.concat_map starts ~f:(fun ((i, j), key) ->
      let sequence = sequences.(i) in
      let instruction = List.nth_exn sequence j in
      let next = Option.some_if (j + 1 < List.length sequence) (i, j + 1) in
      let exec_row = { row with exec = Some (i, j) } in
      match instruction.op with
      | Jmp _ | Out { destination = Exec | Pc; _ } | Mov { destination = Exec | Pc; _ } ->
        ctx.emit exec_row (Unmodelled "exec of a jump");
        []
      | _ ->
        execute ctx ~row:exec_row instruction ({ key with exec = next }, timing)
        |> List.map ~f:(fun (key, timing, _) -> key, timing, Next))
;;

let default_pins (config : Config.t) (program : Pioasm.Program.t) =
  let output count prefix make drive =
    List.init count ~f:(fun i ->
      { Pin.name = [%string "%{prefix}%{i#Int}"]
      ; bindings = [ make i, drive ]
      ; initial = None
      })
  in
  output
    program.side_set.count
    "side"
    (fun i -> Pin_ref.Side i)
    (if program.side_set.pindirs then Drive.Dir else Level)
  @ output config.set_count "set" (fun i -> Pin_ref.Set i) Level
  @ output config.out_count "out" (fun i -> Pin_ref.Out i) Level
;;

let analyse (config : Config.t) (program : Pioasm.Program.t) =
  let pins =
    if List.is_empty config.pins then default_pins config program else config.pins
  in
  let outputs = List.filter pins ~f:Pin.is_output |> Array.of_list in
  let output_index name =
    Array.findi outputs ~f:(fun _ (pin : Pin.t) -> String.equal pin.name name)
    |> Option.map ~f:fst
  in
  let errors =
    List.concat_map config.rules ~f:(fun rule ->
      List.filter_map [ rule.source.pin; rule.target.pin ] ~f:(fun pin ->
        Option.some_if
          (Option.is_none (output_index pin))
          [%string "rule %{rule.name}: %{pin} is not an output"]))
    @ List.concat_map config.exec ~f:(fun sequence ->
      List.filter_map sequence.guard ~f:(fun (name, _) ->
        Option.some_if
          (not
             (List.mem [ "x"; "y" ] name ~equal:String.equal
              || Option.is_some (output_index name)))
          [%string "exec guard: %{name} is neither x, y nor an output"]))
    @
    match config.entry with
    | Some label when not (List.Assoc.mem program.labels label ~equal:String.equal) ->
      [ [%string "no label %{label}"] ]
    | _ -> []
  in
  let rules =
    List.mapi config.rules ~f:(fun index rule ->
      index, rule, output_index rule.source.pin)
  in
  let ctx = { config; program; outputs; inputs = pins; rules; emit = (fun _ _ -> ()) } in
  let entry =
    Option.bind config.entry ~f:(fun label ->
      List.Assoc.find program.labels label ~equal:String.equal)
    |> Option.value ~default:0
  in
  let count = Array.length program.instructions in
  let initial =
    ( { Key.pc = entry
      ; exec = None
      ; x = None
      ; y = None
      ; levels =
          Array.to_list outputs
          |> List.map ~f:(fun (pin : Pin.t) -> Level.of_bool pin.initial)
      ; seen = List.init (1 + (2 * Array.length outputs)) ~f:(fun _ -> false)
      }
    , { Timing.phase = None
      ; rise = Array.to_list outputs |> List.map ~f:(fun _ -> None)
      ; fall = Array.to_list outputs |> List.map ~f:(fun _ -> None)
      } )
  in
  let successors ctx ((key : Key.t), timing) =
    let row = { Row_id.pc = key.pc; exec = None } in
    execute ctx ~row program.instructions.(key.pc) (key, timing)
    |> List.filter_map ~f:(fun ((key : Key.t), timing, control) ->
      let pc =
        match control with
        | Jump target -> Some target
        | Next when key.pc = program.wrap -> Some program.wrap_target
        | Next when key.pc + 1 < count -> Some (key.pc + 1)
        | Next ->
          ctx.emit row (Unmodelled "runs past the end");
          None
      in
      Option.map pc ~f:(fun pc -> { key with pc; seen = Timing.seen timing }, timing))
  in
  let table = Hashtbl.create (module Key) in
  let updates = Hashtbl.create (module Key) in
  let queue = Queue.create () in
  let add (key, timing) =
    match Hashtbl.find table key with
    | None ->
      Hashtbl.set table ~key ~data:timing;
      Queue.enqueue queue key
    | Some old ->
      let joined = Timing.join old timing in
      if not (Timing.equal joined old)
      then (
        Hashtbl.incr updates key;
        let joined =
          if Hashtbl.find_exn updates key > 8 then Timing.widen ~old joined else joined
        in
        Hashtbl.set table ~key ~data:joined;
        Queue.enqueue queue key)
  in
  if List.is_empty errors then add initial;
  while not (Queue.is_empty queue) do
    let key = Queue.dequeue_exn queue in
    successors ctx (key, Hashtbl.find_exn table key) |> List.iter ~f:add
  done;
  let events = Hashtbl.create (module Row_id) in
  let ctx =
    { ctx with emit = (fun row event -> Hashtbl.add_multi events ~key:row ~data:event) }
  in
  Hashtbl.iteri table ~f:(fun ~key ~data -> ignore (successors ctx (key, data) : _ list));
  let text (row : Row_id.t) =
    match row.exec with
    | None -> program.instructions.(row.pc)
    | Some (i, j) -> List.nth_exn (List.nth_exn config.exec i).instructions j
  in
  let rows =
    Hashtbl.to_alist events
    |> List.sort ~compare:(fun (a, _) (b, _) -> Row_id.compare a b)
    |> List.map ~f:(fun (id, events) ->
      let instruction = text id in
      let cycles =
        let base =
          match instruction.op, id.exec with
          | (Out { destination = Exec; _ } | Mov { destination = Exec; _ }), None -> 1
          | _ -> 1 + instruction.delay
        in
        if may_stall ctx instruction.op
        then [%string "%{base#Int}+"]
        else Int.to_string base
      in
      { Row.id
      ; text = instruction.text
      ; cycles
      ; events = List.dedup_and_sort events ~compare:Event.compare
      })
  in
  { Report.program = program.name
  ; rows
  ; rules = config.rules
  ; clock = config.clock
  ; cell = config.cell
  ; errors
  }
;;
