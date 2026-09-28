open! Core
open! Hardcaml

module Term = struct
  type t =
    | Const of Bits.t
    | Reg of string
    | Input of string
    | Op2 of Signal.Type.Op.t * t * t
    | Not of t
    | Select of t * int * int
    | Cat of t list
    | Mux of t * t list
  [@@deriving equal, sexp_of]

  let is_zero = function
    | Const b -> Bits.to_unsigned_int b = 0
    | _ -> false
  ;;

  let rec to_string t =
    match t with
    | Const b -> Int.to_string (Bits.to_unsigned_int b)
    | Reg name | Input name -> name
    | Op2 (op, a, b) ->
      let op : string =
        match op with
        | Add -> "+"
        | Sub -> "-"
        | Mulu | Muls -> "*"
        | And -> "&"
        | Or -> "|"
        | Xor -> "^"
        | Eq -> "=="
        | Lt -> "<"
      in
      [%string "(%{to_string a} %{op} %{to_string b})"]
    | Not a -> "~" ^ to_string a
    | Select (a, high, low) when high = low -> [%string "%{to_string a}[%{high#Int}]"]
    | Select (a, high, low) -> [%string "%{to_string a}[%{high#Int}:%{low#Int}]"]
    | Cat [ zero; Select (a, _, by) ] when is_zero zero ->
      [%string "(%{to_string a} >> %{by#Int})"]
    | Cat ts -> "{" ^ String.concat ~sep:", " (List.map ts ~f:to_string) ^ "}"
    | Mux (c, [ f; t ]) -> [%string "(%{to_string c} ? %{to_string t} : %{to_string f})"]
    | Mux (c, cases) ->
      [%string
        "mux(%{to_string c}, %{String.concat ~sep:\", \" (List.map cases ~f:to_string)})"]
  ;;

  let fold (op : Signal.Type.Op.t) a b =
    match op with
    | Add -> Bits.(a +: b)
    | Sub -> Bits.(a -: b)
    | Mulu -> Bits.(a *: b)
    | Muls -> Bits.(a *+ b)
    | And -> Bits.(a &: b)
    | Or -> Bits.(a |: b)
    | Xor -> Bits.(a ^: b)
    | Eq -> Bits.(a ==: b)
    | Lt -> Bits.(a <: b)
  ;;

  let is_one = function
    | Const b -> Bits.to_unsigned_int b = 1
    | _ -> false
  ;;

  let is_bit value = function
    | Const b -> Bits.width b = 1 && Bits.to_unsigned_int b = value
    | _ -> false
  ;;

  (* Constant folding, and the identities [Always.compile] leaves behind. *)
  let simplify t =
    match t with
    | Op2 (op, Const a, Const b) -> Const (fold op a b)
    | Op2 (And, one, x) when is_bit 1 one -> x
    | Op2 (And, x, one) when is_bit 1 one -> x
    | Op2 (Or, zero, x) when is_bit 0 zero -> x
    | Op2 (Or, x, zero) when is_bit 0 zero -> x
    | Not (Const a) -> Const Bits.(~:a)
    | Not (Not a) -> a
    | Select (Const a, high, low) -> Const (Bits.select a ~high ~low)
    | Cat ts
      when List.for_all ts ~f:(function
             | Const _ -> true
             | _ -> false) ->
      Const
        (Bits.concat_msb
           (List.map ts ~f:(function
             | Const b -> b
             | _ -> assert false)))
    | Mux (Const select, cases) ->
      List.nth_exn cases (Int.min (Bits.to_unsigned_int select) (List.length cases - 1))
    | Mux (_, case :: cases) when List.for_all cases ~f:(equal case) -> case
    | Mux (c, [ zero; one ]) when is_bit 0 zero && is_bit 1 one -> c
    | Mux (c, [ one; zero ]) when is_bit 0 zero && is_bit 1 one -> Not c
    | t -> t
  ;;
end

let refuse fmt = Printf.ksprintf (fun s -> Or_error.error_string s) fmt

let rec behind_wires (s : Signal.t) =
  match Signal.Type.wire_driver s with
  | Some d -> behind_wires d
  | None -> s
;;

let uid s = Signal.Type.Uid.to_int (Signal.uid s)

(* The next value of every register when the state register holds [state]. *)
let specialise ~names ~(state_reg : Signal.t) ~state (s : Signal.t) =
  let memo = Hashtbl.create (module Int) in
  let rec go (s : Signal.t) =
    match Hashtbl.find memo (uid s) with
    | Some t -> t
    | None ->
      let t = compute s in
      Hashtbl.set memo ~key:(uid s) ~data:t;
      t
  and compute (s : Signal.t) : Term.t =
    match s with
    | Const { constant; _ } -> Const constant
    | Wire _ ->
      (match Signal.Type.wire_driver s with
       | Some d -> go d
       | None -> Input (List.hd_exn (Signal.names s)))
    | Reg _ when uid s = uid state_reg -> Const state
    | Reg _ -> Reg (Map.find_exn names (uid s))
    | Op2 { op; arg_a; arg_b; _ } -> Term.simplify (Op2 (op, go arg_a, go arg_b))
    | Not { arg; _ } -> Term.simplify (Not (go arg))
    | Select { arg; high; low; _ } -> Term.simplify (Select (go arg, high, low))
    | Cat { args; _ } -> Term.simplify (Cat (List.map args ~f:go))
    | Mux { select; cases; _ } -> Term.simplify (Mux (go select, List.map cases ~f:go))
    | Cases { select; cases; default; _ } ->
      (match go select with
       | Const v ->
         (match
            List.find cases ~f:(fun (k, _) ->
              match go k with
              | Const k -> Bits.equal k v
              | _ -> false)
          with
          | Some (_, case) -> go case
          | None -> go default)
       | select ->
         raise_s
           [%message "a case on something other than the state" (Term.to_string select)])
    | Empty | Multiport_mem _ | Mem_read_port _ | Inst _ ->
      raise_s [%message "memories and instances are outside the subset"]
  in
  go s
;;

module Reg_info = struct
  type t =
    { name : string
    ; signal : Signal.t
    ; width : int
    }
end

type circuit =
  { state_reg : Signal.t
  ; states : (Bits.t * string) list
  ; initial : Bits.t
  ; regs : Reg_info.t list
  ; line : Reg_info.t (** The register driving the output. *)
  ; line_clear : Bits.t
  ; names : string Int.Map.t
  }

let clear_to (s : Signal.t) =
  match s with
  | Reg { register = { clear; enable; _ }; _ } ->
    (match enable, clear with
     | Some e, _ when not (Signal.Type.is_vdd e) ->
       refuse "register %s has an enable" (Signal.Type.to_string s)
     | _, None -> Ok (Bits.zero (Signal.width s))
     | _, Some { clear_to; _ } ->
       (match behind_wires clear_to with
        | Const { constant; _ } -> Ok constant
        | _ -> refuse "register %s clears to a signal" (Signal.Type.to_string s)))
  | _ -> Ok (Bits.zero (Signal.width s))
;;

(* Hierarchy puts the instance name in front, after a [$]. *)
let short_name name =
  match String.rsplit2 name ~on:'$' with
  | Some (_, name) -> name
  | None -> name
;;

let read_circuit circuit =
  let open Or_error.Let_syntax in
  let graph = Circuit.signal_graph circuit in
  let%bind port, driver =
    match Circuit.outputs circuit with
    | [ o ] ->
      let port = List.hd_exn (Signal.names o) in
      let driver = behind_wires o in
      if Signal.Type.is_reg driver && Signal.width driver = 1
      then Ok (port, driver)
      else refuse "output %s is not a one bit register" port
    | _ -> refuse "one output, so one pin, for now"
  in
  let%bind state_reg, states =
    match
      Signal_graph.filter graph ~f:(fun s ->
        match Signal.Type.get_wave_format s with
        | Map _ -> Signal.Type.is_reg (behind_wires s)
        | _ -> false)
    with
    | [ s ] ->
      (match Signal.Type.get_wave_format s with
       | Map states -> Ok (behind_wires s, states)
       | _ -> assert false)
    | [] -> refuse "no Always.State_machine with its state names in the waveform format"
    | _ -> refuse "more than one state machine"
  in
  let signals = Signal_graph.filter graph ~f:Signal.Type.is_reg in
  let names =
    List.map signals ~f:(fun s ->
      let name =
        match Signal.names s with
        | name :: _ -> short_name name
        | [] -> if uid s = uid driver then port else "_" ^ Int.to_string (uid s)
      in
      uid s, name)
    |> Int.Map.of_alist_reduce ~f:Fn.const
  in
  let%bind initial = clear_to state_reg in
  let%bind line_clear = clear_to driver in
  let%map regs =
    List.filter signals ~f:(fun s -> uid s <> uid state_reg)
    |> List.map ~f:(fun signal ->
      let%map (_ : Bits.t) = clear_to signal in
      { Reg_info.name = Map.find_exn names (uid signal)
      ; signal
      ; width = Signal.width signal
      })
    |> Or_error.all
  in
  let line = List.find_exn regs ~f:(fun r -> uid r.signal = uid driver) in
  { state_reg; states; initial; regs; line; line_clear; names }
;;

let reg_d (s : Signal.t) =
  match s with
  | Reg { d; _ } -> d
  | _ -> assert false
;;

module Tick = struct
  type t =
    { counter : string
    ; condition : Term.t
    ; period : int
    }

  (* A register counting up to a constant and back to zero. *)
  let of_term ~counter (term : Term.t) =
    match term with
    | Mux
        ( (Op2 (Eq, (Op2 (Add, Reg name, one) as count), Const n) as condition)
        , [ count'; zero ] )
      when String.equal name counter
           && Term.is_one one
           && Term.equal count count'
           && Term.is_zero zero ->
      Some { counter; condition; period = Bits.to_unsigned_int n }
    | _ -> None
  ;;
end

module Guard = struct
  type t =
    | Tick
    | Input of string
    | Every_cycle
  [@@deriving compare, sexp_of]
end

module Kind = struct
  type t =
    | Ticked
    | Polled of string
end

module State = struct
  type t =
    { name : string
    ; label : string
    ; kind : Kind.t
    ; effects : (string * Term.t) list
    ; next : Term.t option (** [None] stays put. *)
    }
end

(* Splits a next value into what it waits for and what it becomes. *)
let strip ~(tick : Tick.t) ~hold term =
  (* folding turned a one bit [mux c [0; 1]] into [c]; put it back *)
  let term : Term.t =
    match (term : Term.t) with
    | (Input _ | Op2 (Eq, _, _)) when Term.is_bit 0 hold ->
      Mux (term, [ hold; Const Bits.vdd ])
    | Not ((Input _ | Op2 (Eq, _, _)) as c) when Term.is_bit 1 hold ->
      Mux (c, [ hold; Const Bits.gnd ])
    | term -> term
  in
  if Term.equal term hold
  then None
  else (
    match term with
    | Mux (condition, [ hold'; value ])
      when Term.equal hold hold' && Term.equal condition tick.condition ->
      Some (Guard.Tick, value)
    | Mux (Input valid, [ hold'; value ]) when Term.equal hold hold' ->
      Some (Input valid, value)
    | value -> Some (Every_cycle, value))
;;

let rec mentions name (term : Term.t) =
  match term with
  | Const _ | Input _ -> false
  | Reg r -> String.equal r name
  | Op2 (_, a, b) -> mentions name a || mentions name b
  | Not a | Select (a, _, _) -> mentions name a
  | Cat ts -> List.exists ts ~f:(mentions name)
  | Mux (c, ts) -> List.exists (c :: ts) ~f:(mentions name)
;;

let next_value c ~state (r : Signal.t) =
  specialise ~names:c.names ~state_reg:c.state_reg ~state (reg_d r)
;;

let find_tick c =
  List.find_map c.states ~f:(fun (state, _) ->
    List.find_map c.regs ~f:(fun r ->
      Tick.of_term ~counter:r.name (next_value c ~state r.signal)))
  |> Or_error.of_option
       ~error:(Error.of_string "no register counts to a constant to make the tick")
;;

let read_state c ~(tick : Tick.t) ~state ~name =
  let open Or_error.Let_syntax in
  let next = next_value c ~state in
  let%bind restarts =
    let r = List.find_exn c.regs ~f:(fun r -> String.equal r.name tick.counter) in
    let term = next r.signal in
    if Term.is_zero term
    then Ok true
    else if Option.exists (Tick.of_term ~counter:r.name term) ~f:(fun t ->
              Term.equal t.condition tick.condition)
    then Ok false
    else
      refuse
        "state %s: %s <- %s, where the tick counter should count or restart"
        name
        r.name
        (Term.to_string term)
  in
  let effects =
    List.filter_map c.regs ~f:(fun r ->
      if String.equal r.name tick.counter
      then None
      else
        strip ~tick ~hold:(Reg r.name) (next r.signal)
        |> Option.map ~f:(fun (guard, value) -> r.name, guard, value))
  in
  let transition = strip ~tick ~hold:(Const state) (next c.state_reg) in
  let guards =
    List.map effects ~f:(fun (_, guard, _) -> guard)
    @ Option.to_list (Option.map transition ~f:fst)
    |> List.dedup_and_sort ~compare:Guard.compare
  in
  let every_cycle_is_idempotent () =
    List.filter_map effects ~f:(fun (reg, guard, value) ->
      match guard with
      | Every_cycle when String.equal reg c.line.name || mentions reg value ->
        Some
          (refuse
             "state %s: %s <- %s every cycle while it waits"
             name
             reg
             (Term.to_string value))
      | _ -> None)
    |> Or_error.all_unit
  in
  let%map kind =
    match guards with
    | [ Tick ] when restarts -> refuse "state %s restarts the tick it waits for" name
    | [ Tick ] -> Ok Kind.Ticked
    | ([ Input valid ] | [ Input valid; Every_cycle ]) when restarts ->
      let%map () = every_cycle_is_idempotent () in
      Kind.Polled valid
    | [ Input _ ] | [ Input _; Every_cycle ] ->
      refuse "state %s waits for an input without restarting the tick" name
    | _ -> refuse "state %s waits for neither the tick nor one input" name
  in
  { State.name
  ; label = String.lowercase name
  ; kind
  ; effects = List.map effects ~f:(fun (reg, _, value) -> reg, value)
  ; next = Option.map transition ~f:snd
  }
;;

module Roles = struct
  type t =
    { shift : Reg_info.t option
    ; counter : (string * int) option (** The register and the value it leaves at. *)
    }

  let is_shift t name = Option.exists t.shift ~f:(fun r -> String.equal r.name name)
  let is_counter t name = Option.exists t.counter ~f:(fun (r, _) -> String.equal r name)
end

let infer_roles c (states : State.t list) =
  let open Or_error.Let_syntax in
  let loads =
    List.concat_map states ~f:(fun s -> s.effects)
    |> List.filter_map ~f:(fun (reg, value) ->
      match value with
      | Input _ -> Some reg
      | _ -> None)
    |> List.dedup_and_sort ~compare:String.compare
  in
  let%bind shift =
    match loads with
    | [] -> Ok None
    | [ reg ] -> Ok (List.find c.regs ~f:(fun r -> String.equal r.name reg))
    | _ -> refuse "more than one register loads an input"
  in
  let compares =
    List.filter_map states ~f:(fun s ->
      match s.next with
      | Some (Mux (Op2 (Eq, Reg reg, Const leave), _)) ->
        Some (reg, Bits.to_unsigned_int leave)
      | _ -> None)
    |> List.dedup_and_sort ~compare:[%compare: string * int]
  in
  let%map counter =
    match compares with
    | [] -> Ok None
    | [ counter ] -> Ok (Some counter)
    | _ -> refuse "more than one loop counter"
  in
  { Roles.shift; counter }
;;

module Line = struct
  type t =
    { text : string
    ; comment : string
    ; cycles : int
    }

  let create ?(cycles = 1) ?(comment = "") text = { text; comment; cycles }

  let to_string t =
    if String.is_empty t.comment
    then "    " ^ t.text
    else sprintf "    %-16s; %s" t.text t.comment
  ;;
end

let is_shift_right (shift : Reg_info.t) (term : Term.t) =
  match term with
  | Cat [ zero; Select (Reg name, high, 1) ] ->
    Term.is_zero zero && String.equal name shift.name && high = shift.width - 1
  | _ -> false
;;

let goto ~after target =
  if Option.exists after ~f:(String.equal target)
  then []
  else [ Line.create ~cycles:Isa.jmp_cycles [%string "jmp %{target}"] ]
;;

let cost lines = List.sum (module Int) lines ~f:(fun (l : Line.t) -> l.cycles)

(* A state's code and, per exit, the cycles from its anchor: [wait t+] on the tick,
   [mov t, now] when polling. *)
let emit c (roles : Roles.t) ~label_of ~after (s : State.t) =
  let open Or_error.Let_syntax in
  let effect reg = List.Assoc.find s.effects reg ~equal:String.equal in
  let%bind () =
    List.map s.effects ~f:(fun (reg, value) ->
      let is_line = String.equal reg c.line.name in
      match value with
      | Const _ when is_line -> Ok ()
      | Select (Reg shift, 0, 0) when is_line && Roles.is_shift roles shift -> Ok ()
      | Input _ when Roles.is_shift roles reg -> Ok ()
      | value
        when Roles.is_shift roles reg
             && is_shift_right (Option.value_exn roles.shift) value -> Ok ()
      | Const _ when Roles.is_counter roles reg -> Ok ()
      | Op2 (Add, Reg reg', one)
        when Roles.is_counter roles reg && String.equal reg reg' && Term.is_one one ->
        Ok ()
      | value ->
        refuse
          "state %s: %s <- %s is outside the subset"
          s.name
          reg
          (Term.to_string value))
    |> Or_error.all_unit
  in
  let line = c.line.name in
  let pin =
    match effect line with
    | Some (Const v) ->
      let v = Bits.to_unsigned_int v in
      [ Line.create
          [%string "set pins, %{v#Int}"]
          ~comment:[%string "%{line} <- %{v#Int}"]
      ]
    | Some (Select (Reg shift, _, _)) ->
      [ Line.create
          "out pins, 1"
          ~comment:[%string "%{line} <- %{shift}[0], %{shift} <- %{shift} >> 1"]
      ]
    | _ -> []
  in
  let%bind shift =
    match roles.shift with
    | None -> Ok []
    | Some shift ->
      (match effect shift.name, effect line, s.kind with
       | None, _, _ | Some _, Some (Select _), _ -> Ok []
       | Some (Input data), _, Polled _ ->
         Ok [ Line.create "pull" ~comment:[%string "%{shift.name} <- %{data}"] ]
       | Some (Input _), _, Ticked ->
         refuse "state %s loads %s on the tick" s.name shift.name
       | Some _, _, _ ->
         Ok
           [ Line.create
               "out null, 1"
               ~comment:[%string "%{shift.name} <- %{shift.name} >> 1"]
           ])
  in
  let counter, counts =
    match roles.counter with
    | None -> [], false
    | Some (counter, leave) ->
      (match effect counter with
       | Some (Const v) ->
         let v = Bits.to_unsigned_int v in
         ( [ Line.create
               [%string "set x, %{leave - v#Int}"]
               ~comment:[%string "%{counter} <- %{v#Int}, leaving at %{leave#Int}"]
           ]
         , false )
       | Some _ -> [], true
       | None -> [], false)
  in
  let%bind exits =
    match s.next with
    | None -> Ok [ goto ~after:None s.label, s.label ]
    | Some (Const v) ->
      let target = label_of v in
      Ok [ goto ~after target, target ]
    | Some (Mux (Op2 (Eq, Reg reg, Const _), [ Const stay; Const leave ]))
      when counts && Roles.is_counter roles reg ->
      let stay = label_of stay in
      let leave = label_of leave in
      let jmp =
        Line.create
          ~cycles:Isa.jmp_cycles
          [%string "jmp x--, %{stay}"]
          ~comment:[%string "%{reg} <- %{reg} + 1"]
      in
      Ok [ [ jmp ], stay; jmp :: goto ~after leave, leave ]
    | Some next ->
      refuse "state %s: next state %s is outside the subset" s.name (Term.to_string next)
  in
  let%bind () =
    if counts && List.length exits <> 2
    then refuse "state %s counts but does not leave on the count" s.name
    else Ok ()
  in
  let waits, anchored =
    match s.kind with
    | Ticked -> [], (Line.create "wait t+" ~comment:"the tick" :: pin) @ shift @ counter
    | Polled valid ->
      ( Line.create "wait tx" ~comment:[%string "until %{valid}"] :: shift
      , (Line.create "mov t, now" ~comment:"restart the tick" :: pin)
        @ (Line.create "add t, p" :: counter) )
  in
  let leaving =
    match exits with
    | [ (path, _) ] -> path
    | [ (stay, _); (leave, _) ] -> stay @ List.drop leave (List.length stay)
    | _ -> []
  in
  let paths =
    List.map exits ~f:(fun (path, target) -> cost anchored + cost path, target)
  in
  return (waits @ anchored @ leaving, paths)
;;

(* [set] takes five bits; longer periods come from the host, which the analyser bounds *)
let period_from_host period = period >= 1 lsl Isa.Field.set_value.width

let set_period period =
  if period_from_host period
  then
    [ Line.create "wait tx"
    ; Line.create "pull" ~comment:[%string "the host sends the tick, %{period#Int}"]
    ; Line.create "mov p, osr"
    ]
  else [ Line.create [%string "set p, %{period#Int}"] ]
;;

module Firmware = struct
  type t =
    { source : string
    ; program : Asm.Program.t
    ; config : Program_config.t
    ; period : int
    ; period_from_host : bool
    }
end

let compile circuit =
  let open Or_error.Let_syntax in
  Or_error.try_with_join (fun () ->
    let%bind c = read_circuit circuit in
    let%bind tick = find_tick c in
    let%bind states =
      List.map c.states ~f:(fun (state, name) -> read_state c ~tick ~state ~name)
      |> Or_error.all
    in
    let label_of v =
      List.find_map_exn c.states ~f:(fun (b, name) ->
        Option.some_if (Bits.equal b v) (String.lowercase name))
    in
    let%bind () =
      match List.find states ~f:(fun s -> String.equal s.label (label_of c.initial)) with
      | Some { kind = Polled _; _ } -> Ok ()
      | _ -> refuse "the state after clear should wait for an input"
    in
    let%bind roles = infer_roles c states in
    let labels = List.map states ~f:(fun s -> s.label) in
    let%bind code =
      List.mapi states ~f:(fun i s ->
        let%map lines, paths =
          emit c roles ~label_of ~after:(List.nth labels (i + 1)) s
        in
        s, lines, paths)
      |> Or_error.all
    in
    let is_ticked label =
      List.exists states ~f:(fun s ->
        String.equal s.label label
        &&
        match s.kind with
        | Ticked -> true
        | Polled _ -> false)
    in
    let%bind () =
      List.map code ~f:(fun ((s : State.t), _, paths) ->
        match
          List.filter_map paths ~f:(fun (cycles, target) ->
            Option.some_if (is_ticked target) cycles)
          |> List.max_elt ~compare
        with
        | Some needs when needs > tick.period ->
          refuse "state %s needs %d cycles, tick is %d" s.name needs tick.period
        | _ -> Ok ())
      |> Or_error.combine_errors_unit
    in
    let%bind () =
      if tick.period < 1 || tick.period >= 1 lsl Isa.data_bits
      then refuse "a tick of %d cycles does not fit in p" tick.period
      else Ok ()
    in
    let clear = Bits.to_unsigned_int c.line_clear in
    let header =
      [ [%string "; %{tick.counter} counts to %{tick.period#Int}: the tick is wait t+"]
      ; [%string "; %{c.line.name} is pin OUT0"]
      ]
      @ Option.value_map roles.shift ~default:[] ~f:(fun r ->
        [ [%string "; %{r.name} is osr"] ])
      @ Option.value_map roles.counter ~default:[] ~f:(fun (r, _) ->
        [ [%string "; %{r} is x, counting down"] ])
    in
    let prologue =
      set_period tick.period
      @ [ Line.create
            [%string "set pins, %{clear#Int}"]
            ~comment:[%string "%{c.line.name} clears to %{clear#Int}"]
        ]
    in
    let source =
      header
      @ List.map prologue ~f:Line.to_string
      @ List.concat_map code ~f:(fun (s, lines, _) ->
        (s.label ^ ":") :: List.map lines ~f:Line.to_string)
      |> String.concat_lines
    in
    let%map program = Asm.assemble source in
    { Firmware.source
    ; program
    ; config = Asm.Program.configure program Program_config.default
    ; period = tick.period
    ; period_from_host = period_from_host tick.period
    })
;;
