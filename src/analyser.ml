open! Core

module State = struct
  type t =
    { phase : Interval.t
    ; period : Interval.t
    ; x : Interval.t
    ; y : Interval.t
    ; since_arm : Interval.t option
    }
  [@@deriving sexp_of, compare, equal]

  let initial =
    { phase = Interval.top
    ; period = Interval.top
    ; x = Interval.top
    ; y = Interval.top
    ; since_arm = None
    }
  ;;

  let join a b =
    { phase = Interval.join a.phase b.phase
    ; period = Interval.join a.period b.period
    ; x = Interval.join a.x b.x
    ; y = Interval.join a.y b.y
    ; since_arm =
        (match a.since_arm, b.since_arm with
         | Some a, Some b -> Some (Interval.join a b)
         | _ -> None)
    }
  ;;

  let widen ~old t =
    { phase = Interval.widen ~old:old.phase t.phase
    ; period = Interval.widen ~old:old.period t.period
    ; x = Interval.widen ~old:old.x t.x
    ; y = Interval.widen ~old:old.y t.y
    ; since_arm =
        Option.map2 old.since_arm t.since_arm ~f:(fun old t -> Interval.widen ~old t)
    }
  ;;

  let elapse t n =
    { t with
      phase = Interval.shift t.phase n
    ; since_arm = Option.map t.since_arm ~f:(fun s -> Interval.shift s n)
    }
  ;;
end

module Row = struct
  type t =
    { pc : int
    ; instruction : Isa.t
    ; phase : Interval.t
    ; slack : Interval.t option
    ; may_miss : bool
    }
  [@@deriving sexp_of]
end

let max_passes = 32

(* Successors of [pc] with the state after the instruction. A wait on a pin or a fifo can
   take any time, so the phase only gets a lower bound. *)
let captures (c : Program_config.t) (wait : Isa.Wait.t) =
  match wait with
  | Pin_level { pin; level } -> pin = c.capture_pin && Bool.equal level c.capture_rising
  | Pin_edge { pin; rising } -> pin = c.capture_pin && Bool.equal rising c.capture_rising
  | Deadline _ | Fifo _ -> false
;;

let step ~config (s : State.t) pc (t : Isa.t) =
  match t with
  | Jmp { cond; target } ->
    let s = State.elapse s Isa.jmp_cycles in
    (match cond with
     | Always -> [ target, s ]
     | X_dec ->
       let s = { s with x = Interval.shift s.x (-1) } in
       [ target, s; pc + 1, s ]
     | Y_dec ->
       let s = { s with y = Interval.shift s.y (-1) } in
       [ target, s; pc + 1, s ]
     | _ -> [ target, s; pc + 1, s ])
  | Op { op; delay; _ } ->
    let next = delay + 1 in
    let after (s : State.t) = [ pc + 1, State.elapse s next ] in
    (match op with
     | Wait (Deadline { advance }) ->
       let stall = Interval.clamp_low (Interval.minus (Interval.exactly 0) s.phase) 0 in
       let released = Interval.clamp_low s.phase 0 in
       let phase = if advance then Interval.minus released s.period else released in
       let since_arm = Option.map s.since_arm ~f:(fun a -> Interval.plus a stall) in
       after { s with phase; since_arm }
     | Wait ((Pin_level _ | Pin_edge _ | Fifo _) as wait) ->
       let unbounded (i : Interval.t) = { i with hi = None } in
       let since_arm =
         match s.since_arm with
         | Some since when captures config wait ->
           Some { Interval.lo = Some 0; hi = Option.map since.hi ~f:(( + ) 0) }
         | since -> Option.map since ~f:unbounded
       in
       after { s with phase = unbounded s.phase; since_arm }
     | Mov { dest = T; op = Copy; source = Now } ->
       after { s with phase = Interval.exactly 0 }
     | Mov { dest = T; op = Copy; source = Capture } ->
       let phase =
         match s.since_arm with
         | Some since -> Interval.clamp_low since 0
         | None -> Interval.at_least 0
       in
       after { s with phase }
     | Mov { dest = T; _ } | Out { dest = T; _ } -> after { s with phase = Interval.top }
     | Alu { dest = T; op = Add; operand } ->
       let amount =
         match operand with
         | Imm n -> Interval.exactly n
         | Reg P -> s.period
         | Reg X -> s.x
         | Reg Y -> s.y
         | Reg (Isr | Osr) -> Interval.top
       in
       after { s with phase = Interval.minus s.phase amount }
     | Alu { dest = T; op = Sub; operand = Imm n } -> after (State.elapse s n)
     | Alu { dest = T; _ } -> after { s with phase = Interval.top }
     | Set { dest = P; value } -> after { s with period = Interval.exactly value }
     | Set { dest = X; value } -> after { s with x = Interval.exactly value }
     | Set { dest = Y; value } -> after { s with y = Interval.exactly value }
     | Mov { dest = P; _ } | Out { dest = P; _ } | Alu { dest = P; _ } ->
       after { s with period = Interval.top }
     | Mov { dest = X; _ } | Out { dest = X; _ } | Alu { dest = X; _ } ->
       after { s with x = Interval.top }
     | Mov { dest = Y; _ } | Out { dest = Y; _ } | Alu { dest = Y; _ } ->
       after { s with y = Interval.top }
     | Sys Capture_arm -> after { s with since_arm = Some (Interval.exactly 0) }
     | Sys Halt -> []
     | _ -> after s)
;;

let analyse ~config (program : Isa.t list) =
  let program = Array.of_list program in
  let n = Array.length program in
  let entry = Array.create ~len:n None in
  let passes = Array.create ~len:n 0 in
  let work = Queue.create () in
  let visit pc s =
    if pc < n
    then (
      let s' =
        match entry.(pc) with
        | None -> s
        | Some old ->
          let joined = State.join old s in
          if passes.(pc) > max_passes then State.widen ~old joined else joined
      in
      if not (Option.equal State.equal entry.(pc) (Some s'))
      then (
        entry.(pc) <- Some s';
        passes.(pc) <- passes.(pc) + 1;
        Queue.enqueue work pc))
  in
  visit 0 State.initial;
  while not (Queue.is_empty work) do
    let pc = Queue.dequeue_exn work in
    let s = Option.value_exn entry.(pc) in
    List.iter (step ~config s pc program.(pc)) ~f:(fun (pc, s) -> visit pc s)
  done;
  Array.to_list program
  |> List.filter_mapi ~f:(fun pc instruction ->
    Option.map entry.(pc) ~f:(fun (s : State.t) ->
      let slack, may_miss =
        match instruction with
        | Op { op = Wait (Deadline _); _ } ->
          ( Some (Interval.minus (Interval.exactly 0) s.phase)
          , Option.value_map s.phase.hi ~default:true ~f:(fun hi -> hi > 0) )
        | _ -> None, false
      in
      { Row.pc; instruction; phase = s.phase; slack; may_miss }))
;;

let to_string ~side_set_count rows =
  List.map rows ~f:(fun (r : Row.t) ->
    let text = Asm.to_string ~side_set_count r.instruction in
    let slack =
      match r.slack with
      | None -> ""
      | Some s ->
        [%string
          "  slack %{Interval.to_string s}%{if r.may_miss then \"  MAY MISS\" else \"\"}"]
    in
    sprintf "%3d  %-28s phase %s%s" r.pc text (Interval.to_string r.phase) slack)
  |> String.concat ~sep:"\n"
;;
