open! Core
open! Hardcaml

module Ports = struct
  type t =
    { reset : (string * Level.t) option
    ; valid : string
    ; data : string
    ; pin : string
    ; tied : (string * Bits.t) list
    }
  [@@deriving sexp_of]
end

module Symbol = struct
  type t =
    | Level of bool
    | Data of int
  [@@deriving compare, equal, sexp_of]

  let to_string = function
    | Level b -> Int.to_string (Bool.to_int b)
    | Data i -> [%string "d%{i#Int}"]
  ;;
end

module Frame = struct
  type t =
    { warm_up : Bit_sim.State.t array
    ; idle : Bit_sim.State.t
    ; pin_idle : bool
    ; states : Bit_sim.State.t array
    ; pins : Symbol.t array
    ; length : int
    ; data_width : int
    }

  let runs t =
    Array.to_list t.pins
    |> List.foldi ~init:[] ~f:(fun cycle runs symbol ->
      match runs with
      | (_, last) :: _ when Symbol.equal last symbol -> runs
      | _ -> (cycle, symbol) :: runs)
    |> List.rev
  ;;
end

let refuse fmt = Printf.ksprintf (fun s -> Or_error.error_string s) fmt

(* [set] takes five bits; a longer period is the host's first word *)
let period_from_host period = period >= 1 lsl Isa.Field.set_value.width

let names sim signals =
  List.map signals ~f:(Bit_sim.describe sim) |> String.concat ~sep:", "
;;

let changed sim a b =
  List.filter (Bit_sim.registers sim) ~f:(fun r ->
    not (Bit_sim.Value.equal (Bit_sim.State.find a r) (Bit_sim.State.find b r)))
;;

let known_bits value =
  Array.map value ~f:(fun (bit : Bit_sim.Bit.t) ->
    match bit with
    | Unknown -> Bit_sim.Bit.Zero
    | bit -> bit)
;;

let pin_of ~(ports : Ports.t) outputs =
  List.Assoc.find_exn outputs ports.pin ~equal:String.equal
;;

(* What leaves the pin unknown in cycle [cycle] of a run from [start]: each input, and
   each register unknown at the start, that made known alone makes the pin known. [why]
   says how each comes to be unknown. *)
let blame sim ~ports ~start ~inputs ~cycle ~why =
  let pin_known ~start ~inputs =
    let rec go state k =
      let outputs, next = Bit_sim.step sim state ~inputs:(inputs k) in
      if k = cycle
      then (
        match pin_of ~ports outputs with
        | [| Unknown |] -> false
        | _ -> true)
      else go next (k + 1)
    in
    go start 0
  in
  let by_input =
    List.filter
      (Circuit.inputs (Bit_sim.circuit sim))
      ~f:(fun input ->
        let name = List.hd_exn (Signal.names input) in
        pin_known ~start ~inputs:(fun k n ->
          if String.equal n name
          then (
            match inputs k n with
            | Some value -> Some (known_bits value)
            | None -> Some (Bit_sim.Value.of_bits (Bits.zero (Signal.width input))))
          else inputs k n))
    |> List.map ~f:(fun input -> why (`Input input))
  in
  let by_register =
    List.filter (Bit_sim.registers sim) ~f:(fun r ->
      let value = Bit_sim.State.find start r in
      (not (Bit_sim.Value.is_known value))
      && pin_known ~start:(Bit_sim.State.set start r (known_bits value)) ~inputs)
    |> List.map ~f:(fun r -> why (`Register r))
  in
  by_input @ by_register
;;

let symbol_of ~cycle ~what (value : Bit_sim.Value.t) ~why =
  match value with
  | [| Zero |] -> Ok (Symbol.Level false)
  | [| One |] -> Ok (Level true)
  | [| Data { index; inverted = false } |] -> Ok (Data index)
  | [| Data { index; inverted = true } |] ->
    refuse "%s: the pin sends bit %d of the data inverted, at cycle %d" what index cycle
  | _ ->
    (match why () with
     | [] -> refuse "%s: the pin is unknown at cycle %d" what cycle
     | causes ->
       refuse
         "%s: the pin is unknown at cycle %d: it depends on %s"
         what
         cycle
         (String.concat ~sep:"; " causes))
;;

let read ?(limit = 1 lsl 16) sim ~(ports : Ports.t) =
  let open Or_error.Let_syntax in
  let circuit = Bit_sim.circuit sim in
  let input_width name =
    List.find_map (Circuit.inputs circuit) ~f:(fun s ->
      Option.some_if (List.mem (Signal.names s) name ~equal:String.equal) (Signal.width s))
  in
  let%bind () =
    if List.exists (Circuit.outputs circuit) ~f:(fun o ->
         List.mem (Signal.names o) ports.pin ~equal:String.equal)
    then Ok ()
    else refuse "no output %s" ports.pin
  in
  let%bind () =
    match input_width ports.valid with
    | Some 1 -> Ok ()
    | Some w -> refuse "valid %s is %d bits, not one" ports.valid w
    | None -> refuse "no input %s" ports.valid
  in
  let%bind data_width =
    match input_width ports.data with
    | Some w when w <= Isa.data_bits -> Ok w
    | Some w ->
      refuse "data %s is %d bits, more than the tx fifo's %d" ports.data w Isa.data_bits
    | None -> refuse "no input %s" ports.data
  in
  let%bind () =
    List.map ports.tied ~f:(fun (name, value) ->
      match input_width name with
      | Some w when w = Bits.width value -> Ok ()
      | Some w -> refuse "%s is %d bits, tied to %d" name w (Bits.width value)
      | None -> refuse "no input %s to tie" name)
    |> Or_error.all_unit
  in
  let inputs ~reset ~valid ~data name =
    if Option.exists ports.reset ~f:(fun (r, _) -> String.equal r name)
    then (
      let level = Option.value_map ports.reset ~default:Level.High ~f:snd in
      let active = Bool.equal reset (Level.equal level High) in
      Some (Bit_sim.Value.of_bits (Bits.of_bool active)))
    else if String.equal name ports.valid
    then Some valid
    else if String.equal name ports.data
    then Some data
    else
      List.Assoc.find ports.tied name ~equal:String.equal
      |> Option.map ~f:Bit_sim.Value.of_bits
  in
  let low = Bit_sim.Value.of_bits Bits.gnd in
  let high = Bit_sim.Value.of_bits Bits.vdd in
  let no_data = Bit_sim.Value.unknown ~width:data_width in
  let waiting ~reset = inputs ~reset ~valid:low ~data:no_data in
  let take =
    inputs ~reset:false ~valid:high ~data:(Bit_sim.Value.data ~width:data_width)
  in
  let busy = inputs ~reset:false ~valid:(Bit_sim.Value.unknown ~width:1) ~data:no_data in
  let pin_of = pin_of ~ports in
  (* from [start], [inputs] in each cycle, until a cycle changes nothing *)
  let settle ~start ~inputs ~from =
    let rec go states state cycle =
      let _, next = Bit_sim.step sim state ~inputs:(inputs cycle) in
      if cycle > from && Bit_sim.State.equal next state
      then Ok (List.rev (state :: states))
      else if cycle >= limit
      then Error (changed sim state next)
      else go (state :: states) next (cycle + 1)
    in
    go [] start 0
  in
  let%bind warm_up =
    settle ~start:(Bit_sim.initial sim) ~from:0 ~inputs:(fun cycle ->
      waiting ~reset:(cycle = 0))
    |> Result.map_error ~f:(fun registers ->
      Error.createf
        "with %s low the circuit does not settle in %d cycles: %s keep changing"
        ports.valid
        limit
        (names sim registers))
  in
  let after_reset = List.last_exn warm_up in
  let settled_at = List.length warm_up - 1 in
  let why ~after_frame = function
    | `Input input ->
      let name = List.hd_exn (Signal.names input) in
      if String.equal name ports.valid
      then [%string "%{Bit_sim.describe sim input}, which it reads while it sends"]
      else if String.equal name ports.data
      then [%string "%{Bit_sim.describe sim input} after the take"]
      else
        [%string
          "input %{Bit_sim.describe sim input}, which is not reset, valid or data: tie \
           it with -tie %{name}=VALUE"]
    | `Register r ->
      let was = Bit_sim.State.find after_reset r in
      (match after_frame with
       | Some after_frame
         when Bit_sim.Value.is_known was
              && not (Bit_sim.Value.equal was (Bit_sim.State.find after_frame r)) ->
         [%string
           "%{Bit_sim.describe sim r}, which waits as %{Bit_sim.Value.to_string was} \
            after reset and as %{Bit_sim.Value.to_string (Bit_sim.State.find after_frame \
            r)} after a frame"]
       | _ -> [%string "%{Bit_sim.describe sim r}, which reset leaves unknown"])
  in
  (* blamed from reset, so a register is one reset leaves unknown, not one that came to be *)
  let blame_from_reset ~after ~cycle () =
    blame
      sim
      ~ports
      ~start:(Bit_sim.initial sim)
      ~inputs:(fun c ->
        if c < settled_at then waiting ~reset:(c = 0) else after (c - settled_at))
      ~cycle:(settled_at + cycle)
      ~why:(why ~after_frame:None)
  in
  let idle_inputs = waiting ~reset:false in
  let%bind (_ : Symbol.t) =
    let outputs, _ = Bit_sim.step sim after_reset ~inputs:idle_inputs in
    symbol_of
      ~cycle:0
      ~what:"while it waits"
      (pin_of outputs)
      ~why:(blame_from_reset ~after:(fun _ -> idle_inputs) ~cycle:0)
  in
  (* where it waits after a frame, which the next frame starts from: the take, then valid
     low *)
  let first_inputs cycle = if cycle = 0 then take else idle_inputs in
  let%bind after_frame =
    let rec go state cycle =
      let outputs, next = Bit_sim.step sim state ~inputs:(first_inputs cycle) in
      let%bind (_ : Symbol.t) =
        symbol_of
          ~cycle
          ~what:"in the first frame"
          (pin_of outputs)
          ~why:(blame_from_reset ~after:first_inputs ~cycle)
      in
      if cycle > 1 && Bit_sim.State.equal next state
      then Ok state
      else if cycle >= limit
      then
        refuse
          "after a frame, with %s low, the circuit does not settle in %d cycles: %s keep \
           changing"
          ports.valid
          limit
          (names sim (changed sim state next))
      else go next (cycle + 1)
    in
    go after_reset 0
  in
  let why = why ~after_frame:(Some after_frame) in
  let differ state idle =
    List.filter (Bit_sim.registers sim) ~f:(fun r ->
      not (Bit_sim.Value.within (Bit_sim.State.find state r) (Bit_sim.State.find idle r)))
  in
  (* the take, then valid unknown until the circuit is back in the idle state *)
  let frame_inputs cycle = if cycle = 0 then take else busy in
  (* a cycle after the take that reads valid as a take would, and is not idle *)
  let waits_elsewhere ~idle states =
    List.find_mapi states ~f:(fun cycle state ->
      let next ~valid =
        snd (Bit_sim.step sim state ~inputs:(inputs ~reset:false ~valid ~data:no_data))
      in
      let stays = next ~valid:low in
      Option.some_if
        (cycle > 0
         && (not (Bit_sim.State.equal (next ~valid:high) stays))
         && Bit_sim.State.within stays idle)
        (cycle, state))
  in
  let frame ~idle =
    let rec run states pins state cycle =
      let outputs, next = Bit_sim.step sim state ~inputs:(frame_inputs cycle) in
      let states = state :: states in
      let waits () = waits_elsewhere ~idle (List.rev states) in
      let unknown = Bit_sim.Value.equal (pin_of outputs) [| Unknown |] in
      match if unknown then waits () else None with
      | Some waits -> Ok (`Waits waits)
      | None ->
        let%bind symbol =
          symbol_of ~cycle ~what:"in the frame" (pin_of outputs) ~why:(fun () ->
            blame sim ~ports ~start:idle ~inputs:frame_inputs ~cycle ~why)
        in
        let pins = symbol :: pins in
        if cycle > 0 && Bit_sim.State.within state idle
        then Ok (`Frame (List.rev states, List.rev pins))
        else if cycle >= limit
        then (
          match waits () with
          | Some waits -> Ok (`Waits waits)
          | None ->
            refuse
              "the frame does not come back to the idle state in %d cycles: %s differ"
              limit
              (names sim (differ state idle)))
        else run states pins next (cycle + 1)
    in
    run [] [] idle 0
  in
  (* the idle state is what every state it waits for valid in shares *)
  let widenings = 4 in
  let%bind idle, states, pins =
    let rec widen idle tries =
      match%bind frame ~idle with
      | `Frame (states, pins) -> Ok (idle, states, pins)
      | `Waits (_, state) when tries > 0 ->
        widen (Bit_sim.State.merge idle state) (tries - 1)
      | `Waits (cycle, state) ->
        refuse
          "it waits for %s in more than %d states: at cycle %d of the frame %s"
          ports.valid
          (widenings + 1)
          cycle
          (differ state idle
           |> List.map ~f:(fun r ->
             [%string
               "%{Bit_sim.describe sim r} is %{Bit_sim.Value.to_string \
                (Bit_sim.State.find state r)}, %{Bit_sim.Value.to_string \
                (Bit_sim.State.find idle r)} when idle"])
           |> String.concat ~sep:", ")
    in
    widen (Bit_sim.State.merge after_reset after_frame) widenings
  in
  let%bind pin_idle =
    let outputs, _ = Bit_sim.step sim idle ~inputs:idle_inputs in
    let%bind symbol =
      symbol_of ~cycle:0 ~what:"while it waits" (pin_of outputs) ~why:(fun () ->
        blame sim ~ports ~start:idle ~inputs:(fun _ -> idle_inputs) ~cycle:0 ~why)
    in
    match symbol with
    | Level b -> Ok b
    | Data _ -> refuse "the pin is the data while the circuit waits"
  in
  let states = Array.of_list states in
  let pins = Array.of_list pins in
  let length = Array.length states - 1 in
  let%map () =
    if Symbol.equal pins.(length) (Level pin_idle)
    then Ok ()
    else refuse "the pin is not at its idle level when the frame ends"
  in
  { Frame.warm_up = Array.of_list warm_up
  ; idle
  ; pin_idle
  ; states
  ; pins
  ; length
  ; data_width
  }
;;

module Line = struct
  type t =
    { text : string
    ; comment : string
    }

  let create ?(comment = "") text = { text; comment }

  let to_string t =
    if String.is_empty t.comment
    then "    " ^ t.text
    else sprintf "    %-16s; %s" t.text t.comment
  ;;
end

module Item = struct
  type t =
    | Run of
        { start : int
        ; length : int option (** [None] for the last, which lasts. *)
        ; symbol : Symbol.t
        }
    | Loop of
        { start : int
        ; first : int
        ; count : int
        }
end

(* the commonest run length, the shorter of a tie *)
let commonest lengths =
  List.sort_and_group lengths ~compare:Int.compare
  |> List.max_elt ~compare:(fun a b ->
    match Int.compare (List.length a) (List.length b) with
    | 0 -> Int.compare (List.hd_exn b) (List.hd_exn a)
    | c -> c)
  |> Option.value_exn
  |> List.hd_exn
;;

let items ~period runs =
  let rec group = function
    | [] -> []
    | (start, length, Symbol.Data first) :: rest
      when Option.equal Int.equal length (Some period) ->
      let rec take count = function
        | (_, length, Symbol.Data i) :: rest
          when i = first + count && Option.equal Int.equal length (Some period) ->
          take (count + 1) rest
        | rest -> count, rest
      in
      let count, rest = take 1 rest in
      if count >= 2
      then Item.Loop { start; first; count } :: group rest
      else Item.Run { start; length; symbol = Data first } :: group rest
    | (start, length, symbol) :: rest -> Item.Run { start; length; symbol } :: group rest
  in
  group runs
;;

let first_bit (item : Item.t) =
  match item with
  | Run { symbol = Data i; _ } -> Some i
  | Loop { first; _ } -> Some first
  | Run { symbol = Level _; _ } -> None
;;

(* [t] moved on by [by] cycles more than the [wait t+] gave it *)
let adjust ~period ~by =
  let rec adds n =
    if n = 0
    then []
    else (
      let step = Int.min n 7 in
      Line.create [%string "add t, %{step#Int}"] :: adds (n - step))
  in
  let rec subs n =
    if n = 0
    then []
    else (
      let step = Int.min n 7 in
      Line.create [%string "sub t, %{step#Int}"] :: subs (n - step))
  in
  if by >= 0
  then List.init (by / period) ~f:(fun _ -> Line.create "wait t+") @ adds (by mod period)
  else subs (-by)
;;

let source ~(ports : Ports.t) ~period ~first_deadline ~pin_idle runs =
  let open Or_error.Let_syntax in
  let items = items ~period runs in
  (* before an item: skip to its first bit, and load x for a loop *)
  let prepare ~shifted (item : Item.t option) =
    let%map skip =
      match Option.bind item ~f:first_bit with
      | Some bit when bit < shifted ->
        refuse "the pin sends data bit %d after bit %d: LSB first only" bit (shifted - 1)
      | Some bit when bit > shifted ->
        Ok [ Line.create [%string "out null, %{bit - shifted#Int}"] ~comment:"skip" ]
      | _ -> Ok []
    in
    let load =
      match item with
      | Some (Loop { count; _ }) ->
        [ Line.create [%string "set x, %{count - 1#Int}"] ~comment:"loop count" ]
      | _ -> []
    in
    skip @ load
  in
  let range start length =
    match length with
    | Some length -> [%string "cycles %{start#Int}-%{start + length - 1#Int}"]
    | None -> [%string "from cycle %{start#Int}"]
  in
  let rec emit ~shifted ~loops = function
    | [] -> Ok []
    | (item : Item.t) :: rest ->
      let next = List.hd rest in
      (match item with
       | Run { start; length; symbol } ->
         let pin_op, shifted =
           match symbol with
           | Level b ->
             ( Line.create
                 [%string "set pins, %{Bool.to_int b#Int}"]
                 ~comment:(range start length ^ ": " ^ Symbol.to_string symbol)
             , shifted )
           | Data i ->
             ( Line.create
                 "out pins, 1"
                 ~comment:(range start length ^ [%string ": d%{i#Int}"])
             , i + 1 )
         in
         let%bind prepared = prepare ~shifted next in
         let tail =
           match length with
           | Some length -> adjust ~period ~by:(length - period) @ prepared
           | None -> [ Line.create "jmp idle" ]
         in
         let%map rest = emit ~shifted ~loops rest in
         [ `Line (Line.create "wait t+"); `Line pin_op ]
         @ List.map tail ~f:(fun l -> `Line l)
         @ rest
       | Loop { start; first; count } ->
         let label = [%string "loop%{loops#Int}"] in
         let shifted = first + count in
         let%bind prepared = prepare ~shifted next in
         let%map rest = emit ~shifted ~loops:(loops + 1) rest in
         [ `Label label
         ; `Line (Line.create "wait t+")
         ; `Line
             (Line.create
                "out pins, 1"
                ~comment:
                  [%string
                    "cycles %{start#Int}-%{start + (count * period) - 1#Int}: \
                     d%{first#Int}-d%{first + count - 1#Int}"])
         ; `Line (Line.create [%string "jmp x--, %{label}"])
         ]
         @ List.map prepared ~f:(fun l -> `Line l)
         @ rest)
  in
  let%bind first = prepare ~shifted:0 (List.hd items) in
  let%map body = emit ~shifted:0 ~loops:0 items in
  let period_lines =
    if period_from_host period
    then
      [ Line.create "wait tx"
      ; Line.create "pull" ~comment:[%string "the host sends the period, %{period#Int}"]
      ; Line.create "mov p, osr"
      ]
    else [ Line.create [%string "set p, %{period#Int}"] ]
  in
  let header =
    [ [%string "; %{ports.pin} is pin OUT0, %{ports.data} comes through the tx fifo"]
    ; [%string "; cycles count from the one %{ports.valid} is taken in"]
    ]
  in
  let prologue =
    period_lines
    @ [ Line.create
          [%string "set pins, %{Bool.to_int pin_idle#Int}"]
          ~comment:"the idle level"
      ]
  in
  let take =
    [ Line.create "wait tx" ~comment:[%string "until %{ports.valid}"]
    ; Line.create "pull" ~comment:[%string "osr <- %{ports.data}"]
    ; Line.create "mov t, now"
    ]
    @ adjust ~period:Int.max_value ~by:first_deadline
    @ first
  in
  header
  @ List.map prologue ~f:Line.to_string
  @ ("idle:" :: List.map take ~f:Line.to_string)
  @ List.map body ~f:(function
    | `Label l -> l ^ ":"
    | `Line l -> Line.to_string l)
  |> String.concat_lines
;;

module Timing = struct
  type t =
    { lag : int
    ; first_take : int
    ; gap : int
    ; shortest : int
    ; settled : int
    }
  [@@deriving sexp_of]
end

type t =
  { frame : Frame.t
  ; firmware : Fsm_compiler.Firmware.t
  ; timing : Timing.t
  }

let running = 3

let engine_states (firmware : Fsm_compiler.Firmware.t) ~takes ~cycles =
  let words = Asm.Program.words firmware.program |> ok_exn in
  let initial = Machine.create ~config:firmware.config ~program:words |> ok_exn in
  let initial =
    if firmware.period_from_host
    then Machine.write_tx initial firmware.period |> ok_exn
    else initial
  in
  let states = Array.create ~len:(Int.max cycles (running + 1)) initial in
  for cycle = running to cycles - 2 do
    let stepped = Machine.step states.(cycle) ~inputs:0 in
    states.(cycle + 1)
    <- (match List.Assoc.find takes cycle ~equal:Int.equal with
        | Some word -> Machine.write_tx stepped word |> ok_exn
        | None -> stepped)
  done;
  states
;;

let engine_pin (firmware : Fsm_compiler.Firmware.t) (m : Machine.t) =
  (m.pin_out lsr firmware.config.out_base) land 1 = 1
;;

(* the circuit's pin in each cycle for these takes, [None] before it is known *)
let circuit_pins (frame : Frame.t) ~takes ~cycles =
  let warm_up = Array.length frame.warm_up - 1 in
  Array.init cycles ~f:(fun cycle ->
    let last =
      List.filter takes ~f:(fun (at, _) -> at <= cycle)
      |> List.max_elt ~compare:(Comparable.lift Int.compare ~f:fst)
    in
    match last with
    | Some (at, byte) when cycle - at <= frame.length ->
      (match frame.pins.(cycle - at) with
       | Level b -> Some b
       | Data i -> Some ((byte lsr i) land 1 = 1))
    | _ -> Option.some_if (cycle >= warm_up) frame.pin_idle)
;;

let bytes width =
  let mask = (1 lsl width) - 1 in
  List.map [ 0x5555; 0xaaaa; 0x0f0f; 0xf0f0; 0x3c3c; 0; 0xffff ] ~f:(fun b -> b land mask)
;;

(* the engine's pin is the circuit's [lag] cycles before, from [from] to the end *)
let follows ~lag ~from engine circuit =
  Array.for_alli engine ~f:(fun cycle e ->
    cycle < from
    || cycle - lag < 0
    ||
    match circuit.(cycle - lag) with
    | None -> false
    | Some c -> Bool.equal e c)
;;

let timing (frame : Frame.t) (firmware : Fsm_compiler.Firmware.t) =
  let open Or_error.Let_syntax in
  let margin = 64 in
  let trial ~takes ~cycles =
    let engine =
      engine_states firmware ~takes ~cycles |> Array.map ~f:(engine_pin firmware)
    in
    engine, circuit_pins frame ~takes ~cycles
  in
  let words = bytes frame.data_width in
  let late = Array.length frame.warm_up + margin in
  let cycles = late + frame.length + (2 * margin) in
  let%bind lag =
    List.range 0 margin
    |> List.find ~f:(fun lag ->
      List.for_all words ~f:(fun byte ->
        let engine, circuit = trial ~takes:[ late, byte ] ~cycles in
        follows ~lag ~from:late engine circuit))
    |> Or_error.of_option
         ~error:(Error.of_string "BUG: the engine does not follow the circuit at any lag")
  in
  let matches ~takes ~from =
    List.for_all words ~f:(fun byte ->
      let takes = List.map takes ~f:(fun at -> at, byte) in
      let engine, circuit =
        trial ~takes ~cycles:(List.last_exn takes |> fst |> ( + ) (frame.length + margin))
      in
      follows ~lag ~from engine circuit)
  in
  let claim_from = Array.length frame.warm_up - 1 + lag in
  let%bind first_take =
    List.range (Array.length frame.warm_up - 1) late
    |> List.find ~f:(fun at ->
      (* every later first take too *)
      List.for_all (List.range at late) ~f:(fun at ->
        matches ~takes:[ at ] ~from:claim_from))
    |> Or_error.of_option ~error:(Error.of_string "BUG: no first take the engine follows")
  in
  let at = late in
  let%bind gap =
    List.range frame.length (frame.length + margin)
    |> List.find ~f:(fun gap ->
      List.for_all
        (List.range gap (gap + margin))
        ~f:(fun gap -> matches ~takes:[ at; at + gap ] ~from:claim_from))
    |> Or_error.of_option
         ~error:(Error.of_string "BUG: no gap between takes the engine follows")
  in
  (* both wait as they will until the next take *)
  let engine = engine_states firmware ~takes:[ at, 0 ] ~cycles in
  let still (a : Machine.t) (b : Machine.t) =
    a.pc = b.pc
    && a.x = b.x
    && a.osr = b.osr
    && a.osr_count = b.osr_count
    && a.stall = b.stall
    && a.t = b.t
    && a.pin_out = b.pin_out
    && List.is_empty a.tx_fifo
    && List.is_empty b.tx_fifo
  in
  let%map settled =
    List.range frame.length (cycles - at - 1)
    |> List.find ~f:(fun k ->
      List.for_all
        (List.range k (cycles - at - 1))
        ~f:(fun k -> still engine.(at + k) engine.(at + k + 1)))
    |> Or_error.of_option ~error:(Error.of_string "BUG: the engine does not settle")
  in
  { Timing.lag; first_take; gap = Int.max gap settled; shortest = gap; settled }
;;

let compile ?limit sim ~ports =
  let open Or_error.Let_syntax in
  let%bind frame = read ?limit sim ~ports in
  let runs = Frame.runs frame in
  let%bind runs =
    match runs with
    | [] | [ _ ] -> refuse "the pin never moves in a frame"
    | _ :: runs ->
      Ok
        (List.mapi runs ~f:(fun i (start, symbol) ->
           let length =
             List.nth runs (i + 1) |> Option.map ~f:(fun (next, _) -> next - start)
           in
           start, length, symbol))
  in
  let period = commonest (List.filter_map runs ~f:(fun (_, l, _) -> l)) in
  let%bind () =
    if period >= 1 lsl Isa.data_bits
    then refuse "a run of %d cycles does not fit in p" period
    else Ok ()
  in
  let assemble first_deadline =
    let%bind source =
      source ~ports ~period ~first_deadline ~pin_idle:frame.pin_idle runs
    in
    let%bind program = Asm.assemble source in
    let config = Asm.Program.configure program Program_config.default in
    let period_from_host = period_from_host period in
    let%map (_ : Analyser.Verdict.t) =
      Analyser.check ?period:(Option.some_if period_from_host period) ~config program
    in
    { Fsm_compiler.Firmware.source; program; config; period; period_from_host }
  in
  (* the bit order, which no deadline changes *)
  let%bind (_ : string) =
    source ~ports ~period ~first_deadline:1 ~pin_idle:frame.pin_idle runs
  in
  (* the earliest first deadline the code before it reaches in time *)
  let%bind firmware =
    match List.find_map (List.range 1 64) ~f:(fun d -> Result.ok (assemble d)) with
    | Some firmware -> Ok firmware
    | None ->
      (match assemble 64 with
       | Ok firmware -> Ok firmware
       | Error e ->
         let shortest =
           List.filter_map runs ~f:(fun (_, l, _) -> l)
           |> List.min_elt ~compare:Int.compare
           |> Option.value ~default:0
         in
         Error
           (Error.tag
              e
              ~tag:
                [%string
                  "the shortest run, %{shortest#Int} cycles, is too short for the code \
                   that sends it"]))
  in
  let%map timing = timing frame firmware in
  { frame; firmware; timing }
;;
