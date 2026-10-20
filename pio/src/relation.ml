open! Core
open Protocol_emulator

module Site = struct
  type t =
    | Pc of int
    | Exec of
        { entry : int
        ; return : int
        }
  [@@deriving sexp_of, compare, equal, hash]
end

module Step = struct
  type t =
    { site : Site.t
    ; side : int
    ; markers : int list
    }
  [@@deriving sexp_of]
end

type t =
  { period : int
  ; per_cycle : int
  ; steps : Step.t list
  ; entry : Site.t
  ; side_init : int
  ; side_by_set : bool
  }
[@@deriving sexp_of]

let cycles (instruction : Pioasm.Instruction.t) =
  match instruction.op with
  (* an exec'd instruction's delay applies, the [out exec]'s own does not *)
  | Out { destination = Exec; _ } | Mov { destination = Exec; _ } -> 1
  | _ -> 1 + instruction.delay
;;

let following (program : Pioasm.Program.t) pc =
  if pc = program.wrap then program.wrap_target else pc + 1
;;

let instruction (program : Pioasm.Program.t) ~exec (site : Site.t) =
  match site with
  | Pc pc -> program.instructions.(pc)
  | Exec { entry; _ } -> exec.(entry)
;;

let successors program ~exec (site : Site.t) =
  let after =
    match site with
    | Pc pc -> following program pc
    | Exec { return; _ } -> return
  in
  match (instruction program ~exec site).op with
  | Jmp { condition = Always; target } -> [ Site.Pc target ]
  | Jmp { target; _ } -> [ Pc target; Pc after ]
  | Out { destination = Exec; _ } ->
    List.init (Array.length exec) ~f:(fun entry -> Site.Exec { entry; return = after })
  | Irq { mode = Raise_and_wait; _ } -> []
  | _ -> [ Pc after ]
;;

(* What a word does to the pins, side-set aside. *)
module Effect = struct
  type t =
    | Write of
        { dirs : bool
        ; what : string
        }
    | Sample of string
  [@@deriving sexp_of, compare, equal]
end

let source_name (source : Pioasm.Source.t) =
  match source with
  | Pins -> "pins"
  | X -> "x"
  | Y -> "y"
  | Null -> "null"
  | Status -> "status"
  | Isr -> "isr"
  | Osr -> "osr"
;;

let op_name (op : Pioasm.Mov_op.t) =
  match op with
  | Copy -> ""
  | Invert -> "!"
  | Reverse -> "::"
;;

let ours (word : Isa.t) : Effect.t list =
  let name (type a) (module Cases : Isa.Cases with type t = a) case =
    Sexp.to_string (Cases.sexp_of_t case) |> String.lowercase
  in
  match word with
  | Jmp { cond = Pin | Not_pin; _ } -> [ Sample "jmp pin" ]
  | Jmp _ -> []
  | Op { op; _ } ->
    (match op with
     | Set { dest = (Pins | Pindirs) as dest; value } ->
       [ Write
           { dirs = Isa.Set_dest.Cases.equal dest Pindirs; what = sprintf "set %d" value }
       ]
     | Out { dest = (Pins | Pindirs) as dest; count } ->
       [ Write
           { dirs = Isa.Out_dest.Cases.equal dest Pindirs; what = sprintf "out %d" count }
       ]
     | Mov { dest; op; source } ->
       let write =
         match dest with
         | Pins | Pindirs ->
           [ Effect.Write
               { dirs = Isa.Mov_dest.Cases.equal dest Pindirs
               ; what =
                   sprintf
                     "mov %s%s"
                     (match op with
                      | Copy -> ""
                      | Invert -> "!"
                      | Reverse -> "::")
                     (name (module Isa.Mov_source.Cases) source)
               }
           ]
         | _ -> []
       in
       let sample =
         match source with
         | Pins -> [ Effect.Sample "mov pins" ]
         | _ -> []
       in
       write @ sample
     | In { source = Pins; count } -> [ Sample (sprintf "in %d" count) ]
     | Wait (Pin_level { pin; level }) ->
       [ Sample (sprintf "wait %d pin %d" (Bool.to_int level) pin) ]
     | _ -> [])
;;

let expected
  ~(config : Program_config.t)
  ~dirs_inverted
  (instruction : Pioasm.Instruction.t)
  : Effect.t list
  =
  let pin n = (config.in_base + n) % Isa.pin_space in
  match instruction.op with
  | Set { destination = Pins; value } ->
    [ Write { dirs = false; what = sprintf "set %d" value } ]
  | Set { destination = Pindirs; value } ->
    let value =
      if dirs_inverted then lnot value land ((1 lsl config.set_count) - 1) else value
    in
    [ Write { dirs = true; what = sprintf "set %d" value } ]
  | Out { destination = (Pins | Pindirs) as destination; bits } ->
    [ Write
        { dirs = Pioasm.Destination.equal destination Pindirs
        ; what = sprintf "out %d" bits
        }
    ]
  | Mov { destination; op; source } ->
    let write =
      match destination with
      | Pins | Pindirs ->
        [ Effect.Write
            { dirs = Pioasm.Destination.equal destination Pindirs
            ; what = sprintf "mov %s%s" (op_name op) (source_name source)
            }
        ]
      | _ -> []
    in
    let sample =
      match source with
      | Pins -> [ Effect.Sample "mov pins" ]
      | _ -> []
    in
    write @ sample
  | In { source = Pins; bits } -> [ Sample (sprintf "in %d" bits) ]
  | Jmp { condition = Pin; _ } -> [ Sample "jmp pin" ]
  | Wait { polarity; source = Pin n } ->
    [ Sample (sprintf "wait %d pin %d" (Bool.to_int polarity) (pin n)) ]
  | Wait { polarity; source = Jmp_pin } ->
    [ Sample (sprintf "wait %d pin %d" (Bool.to_int polarity) config.jmp_pin) ]
  | _ -> []
;;

(* The waits a step may stall on: the PIO's own wait, a blocking fifo access, or the
   autopull before an out. *)
let may_stall
  ~(config : Program_config.t)
  (instruction : Pioasm.Instruction.t)
  (word : Isa.t)
  =
  match instruction.op, word with
  | Wait _, Op { op = Wait (Pin_level _); _ } -> true
  | Pull { block = true; _ }, Op { op = Wait (Fifo Tx_not_empty); _ } -> true
  | Out _, Op { op = Wait (Fifo Tx_not_empty); _ } -> config.autopull
  | Push { block = true; _ }, Op { op = Wait (Fifo Rx_not_full); _ } -> true
  | _ -> false
;;

let word_cycles (word : Isa.t) =
  match word with
  | Jmp _ -> Isa.jmp_cycles
  | Op { delay; _ } -> 1 + delay
;;

module Walk = struct
  type t =
    { at : int
    ; cycle : int (** The word's issue, from the marker's release or the stall's. *)
    ; waits : int
    ; stalled : bool
    ; completing : int option
    (** The cycle the PIO instruction completes after a stall. *)
    ; read_now : int option (** The cycle of the re-anchor's [mov t, now]. *)
    ; added : bool
    ; adjusted : int option (** What an immediate added to [t] after [p]. *)
    ; p : int option
    ; effects : (Effect.t * int * bool) list (** With its cycle, and if after a stall. *)
    ; first_word : Isa.t option (** At cycle 1. *)
    ; length : int
    }
end

let check
  (program : Pioasm.Program.t)
  ~exec
  ~dirs_inverted
  ~(config : Program_config.t)
  words
  t
  =
  let words = Array.of_list words in
  let size = Array.length words in
  let word at = if at < size then words.(at) else Isa.Jmp { cond = Always; target = 0 } in
  let marker_of = Hashtbl.create (module Int) in
  List.iter t.steps ~f:(fun (step : Step.t) ->
    List.iter step.markers ~f:(fun at -> Hashtbl.set marker_of ~key:at ~data:step));
  let error fmt = ksprintf Or_error.error_string fmt in
  let side_of (w : Isa.t) =
    match w with
    | Jmp _ -> None
    | Op { side_set; _ } -> Some side_set
  in
  let sided = config.side_set_count > 0 in
  (* side-set as the core writes it: a set direction bit drives low *)
  let ours_side side =
    if dirs_inverted && program.side_set.pindirs
    then lnot side land ((1 lsl program.side_set.count) - 1)
    else side
  in
  let is_deadline_wait advance (w : Isa.t) =
    match w with
    | Op { op = Wait (Deadline { advance = a }); _ } -> Bool.equal a advance
    | _ -> false
  in
  let check_step (step : Step.t) =
    let instruction = instruction program ~exec step.site in
    let waits = (cycles instruction * t.per_cycle) - 1 in
    let side_out =
      match instruction.side with
      | Some side when not t.side_by_set -> side
      | _ -> step.side
    in
    let successors = successors program ~exec step.site in
    (* side-set by [set] is a write of its own *)
    let side_write =
      match instruction.side with
      | Some side when t.side_by_set ->
        [ Effect.Write
            { dirs = program.side_set.pindirs; what = sprintf "set %d" (ours_side side) }
        ]
      | _ -> []
    in
    let expected =
      side_write @ expected ~config ~dirs_inverted instruction
      |> List.sort ~compare:Effect.compare
    in
    let where = Sexp.to_string (Site.sexp_of_t step.site) in
    (* after a stall, t is the PIO instruction's completion, less a cycle, plus p *)
    let anchor (w : Walk.t) =
      match w.stalled, w.completing, w.read_now with
      | false, _, _ -> Ok ()
      | true, Some completing, Some read_now when w.added ->
        let adjusted = Option.value w.adjusted ~default:0 in
        if adjusted = completing - 1 - read_now
        then Ok ()
        else
          error
            "%s: re-anchors %d cycles on, not %d"
            where
            adjusted
            (completing - 1 - read_now)
      | true, _, _ -> error "%s: a stall without its re-anchor" where
    in
    let rec walk (w : Walk.t) =
      let open Or_error.Let_syntax in
      let here = word w.at in
      let fail fmt =
        ksprintf
          (fun s -> Or_error.error_string (sprintf "%s, word %d: %s" where w.at s))
          fmt
      in
      if w.length > (4 * size) + 64
      then fail "a loop with no marker in it"
      else (
        match Hashtbl.find marker_of w.at with
        | Some next when w.length > 0 -> finish w next
        | _ ->
          let%bind () =
            match side_of here, w.length with
            | Some side, 0 when sided && side <> ours_side step.side ->
              fail "the marker drives side-set %d, not %d" side (ours_side step.side)
            | Some side, n when sided && n > 0 && side <> ours_side side_out ->
              fail "drives side-set %d inside the step, not %d" side (ours_side side_out)
            | _ -> return ()
          in
          let first_word =
            match w.first_word with
            | None when w.cycle = 1 && w.length > 0 -> Some here
            | first_word -> first_word
          in
          let effects = List.map (ours here) ~f:(fun e -> e, w.cycle, w.stalled) in
          let step_on ?(cycles = word_cycles here) ?(at = w.at + 1) (w : Walk.t) =
            { w with
              at
            ; cycle = w.cycle + cycles
            ; length = w.length + 1
            ; first_word
            ; effects = effects @ w.effects
            }
          in
          (match here with
           | Jmp { cond = Always; target } -> walk (step_on w ~at:target)
           | Jmp { target; _ } ->
             let%bind () = walk (step_on w ~at:target) in
             walk (step_on w)
           | Op { op; _ } ->
             (match op with
              | Wait (Deadline { advance = true }) when w.length = 0 ->
                walk { (step_on w) with cycle = 1 }
              | Wait (Deadline { advance = true }) ->
                (match w.p, anchor w with
                 | Some p, Ok () when p = t.period ->
                   walk { (step_on w) with waits = w.waits + 1 }
                 | _, Error error -> Error error
                 | _ -> fail "a deadline wait with p not the period")
              | Wait (Deadline { advance = false }) -> fail "a deadline wait that keeps t"
              | Wait _ ->
                if w.stalled || w.waits > 0
                then fail "a second stall, or one after a delay"
                else if not (may_stall ~config instruction here)
                then fail "a stall the PIO instruction cannot make"
                else (
                  (* a wait completes as it releases; the rest at their own word *)
                  let completing =
                    match instruction.op with
                    | Wait _ -> Some 0
                    | _ -> None
                  in
                  walk { (step_on w) with cycle = 1; stalled = true; completing })
              | (Sys Pull | Sys Push | Out _)
                when w.stalled && Option.is_none w.completing ->
                walk { (step_on w) with completing = Some w.cycle }
              | Mov { dest = T; op = Copy; source = Now }
                when w.stalled && Option.is_none w.read_now ->
                walk { (step_on w) with read_now = Some w.cycle }
              | Alu { dest = T; op = Add; operand = Reg P }
                when Option.is_some w.read_now && not w.added ->
                if [%equal: int option] w.p (Some t.period)
                then walk { (step_on w) with added = true }
                else fail "re-anchors with p not the period"
              | Alu { dest = T; op = (Add | Sub) as op; operand = Imm c }
                when w.added && Option.is_none w.adjusted ->
                let c =
                  match op with
                  | Sub -> -c
                  | _ -> c
                in
                walk { (step_on w) with adjusted = Some c }
              | Mov { dest = T; _ } | Out { dest = T; _ } | Alu { dest = T; _ } ->
                fail "writes t"
              | Mov { dest = P; _ } | Out { dest = P; _ } ->
                walk { (step_on w) with p = None }
              | Set { dest = P; value } -> walk { (step_on w) with p = Some value }
              | Alu { dest = P; op; operand } ->
                let operand =
                  match operand with
                  | Imm n -> Some n
                  | Reg P -> w.p
                  | Reg _ -> None
                in
                let p =
                  match w.p, operand with
                  | Some p, Some n ->
                    Some
                      ((match op with
                        | Add -> p + n
                        | Sub -> p - n
                        | Xor -> p lxor n)
                       land 0xffff)
                  | _ -> None
                in
                walk { (step_on w) with p }
              | Sys Halt ->
                (* an irq wait, or an exec entry its guard keeps out *)
                (match instruction.op with
                 | Irq { mode = Raise_and_wait; _ } | Out { destination = Exec; _ } ->
                   return ()
                 | _ -> fail "halts")
              | _ -> walk (step_on w))))
    and finish (w : Walk.t) (next : Step.t) =
      let fail fmt =
        ksprintf
          (fun s -> Or_error.error_string (sprintf "%s, to word %d: %s" where w.at s))
          fmt
      in
      let effects =
        List.map w.effects ~f:(fun (e, _, _) -> e) |> List.sort ~compare:Effect.compare
      in
      let on_time =
        List.for_all w.effects ~f:(fun (e, cycle, after_stall) ->
          match e, after_stall with
          | _, true -> [%equal: int option] (Some cycle) w.completing
          | Sample "jmp pin", false ->
            cycle = 1
            || (cycle = 2
                &&
                  (match w.first_word with
                  | Some (Op { op = Sys Nop; _ }) -> true
                  | _ -> false))
          | _, false -> cycle = 1)
      in
      let stall_wait_early =
        (* the stall wait carries the side-set and issues where the event would *)
        match instruction.op with
        | Wait _ ->
          (match w.first_word with
           | Some (Op { op = Wait (Pin_level _); _ }) -> true
           | _ -> false)
        | _ -> true
      in
      let side_on_time =
        (not sided)
        || ours_side side_out = ours_side step.side
        ||
        match w.first_word with
        | Some (Op _) -> true
        | _ -> false
      in
      if not (List.mem successors next.site ~equal:Site.equal)
      then fail "goes to %s" (Sexp.to_string (Site.sexp_of_t next.site))
      else if next.side <> side_out
      then fail "arrives with side-set %d, not %d" next.side side_out
      else if w.waits <> waits
      then fail "takes %d waits after its marker, not %d" w.waits waits
      else if not ([%equal: Effect.t list] effects expected)
      then
        fail
          "pins %s, not %s"
          (Sexp.to_string ([%sexp_of: Effect.t list] effects))
          (Sexp.to_string ([%sexp_of: Effect.t list] expected))
      else if not on_time
      then fail "a pin event off its cycle"
      else if not stall_wait_early
      then fail "the wait is not the step's first word"
      else if not side_on_time
      then fail "side-set does not change the cycle after the marker"
      else (
        match instruction.op, w.stalled with
        | Wait _, false -> fail "a wait that does not stall"
        | _ -> anchor w)
    in
    match step.markers with
    | [] -> error "%s has no marker" where
    | markers ->
      Or_error.all_unit
        (List.map markers ~f:(fun at ->
           if not (is_deadline_wait true (word at))
           then error "%s: word %d is not a wait t+" where at
           else
             walk
               { at
               ; cycle = 0
               ; waits = 0
               ; stalled = false
               ; completing = None
               ; read_now = None
               ; added = false
               ; adjusted = None
               ; p = Some t.period
               ; effects = []
               ; first_word = None
               ; length = 0
               }))
  in
  (* from address 0 the prologue sets p and t, then reaches the entry step *)
  let rec prologue ~at ~p ~length =
    if length > size + 1
    then error "the prologue loops"
    else (
      match Hashtbl.find marker_of at with
      | Some (step : Step.t) ->
        if not (Site.equal step.site t.entry && step.side = t.side_init)
        then error "the prologue reaches the wrong step"
        else if not ([%equal: int option] p (Some t.period))
        then error "the prologue leaves p not the period"
        else Ok ()
      | None ->
        (match word at with
         | Jmp { cond = Always; target } -> prologue ~at:target ~p ~length:(length + 1)
         | Jmp { target; _ } ->
           Or_error.all_unit
             [ prologue ~at:target ~p ~length:(length + 1)
             ; prologue ~at:(at + 1) ~p ~length:(length + 1)
             ]
         | Op { op = Wait _ | Sys Halt; _ } -> error "the prologue waits"
         | Op { op = Set { dest = P; value }; _ } ->
           prologue ~at:(at + 1) ~p:(Some value) ~length:(length + 1)
         | Op { op = Alu { dest = P; op = Add; operand }; _ } ->
           let p =
             match p, operand with
             | Some p, Imm n -> Some (p + n)
             | Some p, Reg P -> Some (p + p)
             | _ -> None
           in
           prologue ~at:(at + 1) ~p ~length:(length + 1)
         | Op { op = Alu { dest = P; _ } | Mov { dest = P; _ } | Out { dest = P; _ }; _ }
           -> prologue ~at:(at + 1) ~p:None ~length:(length + 1)
         | Op _ -> prologue ~at:(at + 1) ~p ~length:(length + 1)))
  in
  Or_error.all_unit (prologue ~at:0 ~p:None ~length:0 :: List.map t.steps ~f:check_step)
;;
