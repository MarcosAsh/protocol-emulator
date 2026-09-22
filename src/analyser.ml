open! Core

module State = struct
  type t =
    { phase : Interval.t
    ; period : Interval.t
    ; x : Interval.t
    ; y : Interval.t
    ; since_arm : Interval.t option
    ; since_edge : Interval.t (** Cycles since the last pin edge showed. *)
    ; side_set : int option
    ; flip : bool option (** Whether a Manchester bit waits for its second half. *)
    }
  [@@deriving sexp_of, compare, equal]

  let initial =
    { phase = Interval.top
    ; period = Interval.top
    ; x = Interval.top
    ; y = Interval.top
    ; since_arm = None
    ; since_edge = Interval.top
    ; side_set = None
    ; flip = Some false
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
    ; since_edge = Interval.join a.since_edge b.since_edge
    ; side_set =
        Option.bind a.side_set ~f:(fun a ->
          Option.some_if ([%equal: int option] (Some a) b.side_set) a)
    ; flip =
        Option.bind a.flip ~f:(fun a ->
          Option.some_if ([%equal: bool option] (Some a) b.flip) a)
    }
  ;;

  let widen ~old t =
    { phase = Interval.widen ~old:old.phase t.phase
    ; period = Interval.widen ~old:old.period t.period
    ; x = Interval.widen ~old:old.x t.x
    ; y = Interval.widen ~old:old.y t.y
    ; since_arm =
        Option.map2 old.since_arm t.since_arm ~f:(fun old t -> Interval.widen ~old t)
    ; since_edge = Interval.widen ~old:old.since_edge t.since_edge
    ; side_set = t.side_set
    ; flip = t.flip
    }
  ;;

  let elapse t n =
    { t with
      phase = Interval.shift t.phase n
    ; since_arm = Option.map t.since_arm ~f:(fun s -> Interval.shift s n)
    ; since_edge = Interval.shift t.since_edge n
    }
  ;;
end

module Pin_event = struct
  type t =
    | Edge of Interval.t
    | Sample of Interval.t
  [@@deriving sexp_of]

  let with_jitter name (i : Interval.t) =
    let jitter =
      match i.lo, i.hi with
      | Some lo, Some hi when hi = lo -> ""
      | Some lo, Some hi -> [%string "  jitter %{hi - lo#Int}"]
      | _ -> "  jitter ?"
    in
    [%string "  %{name} %{Interval.to_string i}%{jitter}"]
  ;;

  let to_string = function
    | Edge i -> with_jitter "edge" i
    | Sample i -> with_jitter "sample" i
  ;;
end

module Side_event = struct
  type t =
    { at : Interval.t
    ; changes : bool
    }
  [@@deriving sexp_of]
end

module Row = struct
  type t =
    { pc : int
    ; instruction : Isa.t
    ; phase : Interval.t
    ; slack : Interval.t option
    ; may_miss : bool
    ; pin_event : Pin_event.t option
    ; side_event : Side_event.t option
    ; flip : Interval.t option
    ; gaps : (int * Interval.t) list
    }
  [@@deriving sexp_of]
end

let max_passes = 256
let program_size = 1 lsl Isa.pc_bits

let captures (c : Program_config.t) (wait : Isa.Wait.t) =
  match wait with
  | Pin_level { pin; level } -> pin = c.capture_pin && Bool.equal level c.capture_rising
  | Pin_edge { pin; rising } -> pin = c.capture_pin && Bool.equal rising c.capture_rising
  | Deadline _ | Fifo _ -> false
;;

(* A write to the pins side-set drives leaves them at a level the analysis does not
   follow. *)
let writes_side_set (c : Program_config.t) (op : Isa.Op.t) =
  let overlaps ~base ~count =
    List.exists (List.range 0 count) ~f:(fun i ->
      List.exists (List.range 0 c.side_set_count) ~f:(fun j ->
        (base + i) % Isa.pin_space = (c.side_set_base + j) % Isa.pin_space))
  in
  let to_pins = not c.side_set_pindirs in
  match op with
  | Set { dest = Pins; _ } -> to_pins && overlaps ~base:c.set_base ~count:c.set_count
  | Set { dest = Pindirs; _ } ->
    c.side_set_pindirs && overlaps ~base:c.set_base ~count:c.set_count
  | Out { dest = Pins; count } -> to_pins && overlaps ~base:c.out_base ~count
  | Out { dest = Pindirs; count } ->
    c.side_set_pindirs && overlaps ~base:c.out_base ~count
  | Mov { dest = Pins; _ } -> to_pins && overlaps ~base:c.out_base ~count:c.out_count
  | Mov { dest = Pindirs; _ } ->
    c.side_set_pindirs && overlaps ~base:c.out_base ~count:c.out_count
  | _ -> false
;;

let writes_pins (op : Isa.Op.t) =
  match op with
  | Set { dest = Pins | Pindirs; _ }
  | Out { dest = Pins | Pindirs; _ }
  | Mov { dest = Pins | Pindirs; _ } -> true
  | _ -> false
;;

(* Whether an instruction arriving in [s] makes a pin edge, the cycle after it issues: a
   pin write always does, and so does the second half of a Manchester bit it brings. *)
let makes_edge (s : State.t) (t : Isa.t) =
  match t, s.flip with
  | Op { op; _ }, _ when writes_pins op -> Some true
  | _, flip -> flip
;;

(* The edge shows the cycle after the issue, so from then on the count starts at -1. *)
let at_issue (s : State.t) (t : Isa.t) =
  match makes_edge s t with
  | Some true -> { s with since_edge = Interval.exactly (-1) }
  | None -> { s with since_edge = Interval.join (Interval.exactly (-1)) s.since_edge }
  | Some false -> s
;;

(* A Manchester [out] leaves its second half to the next instruction to issue. *)
let starts_flip (c : Program_config.t) (op : Isa.Op.t) =
  c.manchester
  &&
  match op with
  | Out { dest = Pins; count = 1 } -> true
  | _ -> false
;;

(* [jmp x--] jumps on a register that is not zero and leaves zero at all ones: the
   register after the jump, and after falling through, where each can happen. *)
let count_down (r : Interval.t) =
  let nonzero =
    if [%equal: int option] r.lo (Some 0) then { r with lo = Some 1 } else r
  in
  let taken =
    Option.some_if
      (not ([%equal: Interval.t] r (Interval.exactly 0)))
      (Interval.shift nonzero (-1))
  in
  let falls =
    Option.some_if (Interval.contains r 0) (Interval.exactly ((1 lsl Isa.data_bits) - 1))
  in
  taken, falls
;;

(* Successors of [pc] with the state after the instruction. A wait on a pin or a fifo can
   take any time, so the phase only gets a lower bound. *)
let step ?period ?(single_capture_edge = false) ~config (s : State.t) pc (t : Isa.t) =
  let loaded_period = Option.value_map period ~default:Interval.top ~f:Interval.exactly in
  (* the wrap is an edge of the graph like any other and takes no cycles *)
  let following =
    if pc = config.Program_config.wrap_top
    then config.wrap_bottom
    else (pc + 1) % program_size
  in
  let s = at_issue s t in
  match t with
  | Jmp { cond; target } ->
    let s = State.elapse { s with flip = Some false } Isa.jmp_cycles in
    (match cond with
     | Always -> [ target, s ]
     | X_dec ->
       let taken, falls = count_down s.x in
       Option.to_list (Option.map taken ~f:(fun x -> target, { s with x }))
       @ Option.to_list (Option.map falls ~f:(fun x -> following, { s with x }))
     | Y_dec ->
       let taken, falls = count_down s.y in
       Option.to_list (Option.map taken ~f:(fun y -> target, { s with y }))
       @ Option.to_list (Option.map falls ~f:(fun y -> following, { s with y }))
     | X_ne_y ->
       (match s.x, s.y with
        | { lo = Some a; hi = Some b }, { lo = Some c; hi = Some d } when a = b && c = d
          -> [ (if a = c then following else target), s ]
        | x, y when Interval.disjoint x y -> [ target, s ]
        | _ -> [ target, s; following, s ])
     | _ -> [ target, s; following, s ])
  | Op { op; delay; side_set } ->
    let s =
      if config.side_set_count = 0
      then s
      else { s with side_set = Option.some_if (not (writes_side_set config op)) side_set }
    in
    let s = { s with flip = Some (starts_flip config op) } in
    let next = delay + 1 in
    let after (s : State.t) = [ following, State.elapse s next ] in
    (match op with
     | Wait (Deadline { advance }) ->
       let stall = Interval.clamp_low (Interval.minus (Interval.exactly 0) s.phase) 0 in
       let released = Interval.clamp_low s.phase 0 in
       (* a fractional period carries a cycle into some of the steps and not others *)
       let period =
         if config.period_fraction = 0
         then s.period
         else Interval.plus s.period { lo = Some 0; hi = Some 1 }
       in
       let phase = if advance then Interval.minus released period else released in
       let since_arm = Option.map s.since_arm ~f:(fun a -> Interval.plus a stall) in
       after { s with phase; since_arm; since_edge = Interval.plus s.since_edge stall }
     | Wait ((Pin_level _ | Pin_edge _ | Fifo _) as wait) ->
       let unbounded (i : Interval.t) = { i with hi = None } in
       (* The capture is the edge the wait releases on, or an earlier one since the arm,
          but only if the line made one edge; otherwise it can be any age. *)
       let since_arm =
         match s.since_arm with
         | Some since when single_capture_edge && captures config wait ->
           Some { since with lo = Some 0 }
         | since -> Option.map since ~f:unbounded
       in
       after
         { s with
           phase = unbounded s.phase
         ; since_arm
         ; since_edge = unbounded s.since_edge
         }
     | Mov { dest = T; op = Copy; source = Now } ->
       after { s with phase = Interval.exactly 0 }
     | Mov { dest = T; op = Copy; source = Capture } ->
       (* the capture is at least a cycle old, since a register shows the cycle after it
          is written, and at most as old as the arm when the line made one edge *)
       let phase =
         { Interval.lo = Some 1; hi = Option.bind s.since_arm ~f:(fun since -> since.hi) }
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
     (* an earlier deadline, not time passing: only the phase moves *)
     | Alu { dest = T; op = Sub; operand = Imm n } ->
       after { s with phase = Interval.shift s.phase n }
     | Alu { dest = T; _ } -> after { s with phase = Interval.top }
     | Set { dest = P; value } -> after { s with period = Interval.exactly value }
     | Set { dest = X; value } -> after { s with x = Interval.exactly value }
     | Set { dest = Y; value } -> after { s with y = Interval.exactly value }
     | Mov { dest = P; _ } | Out { dest = P; _ } | Alu { dest = P; _ } ->
       after { s with period = loaded_period }
     | Mov { dest = X; _ } | Out { dest = X; _ } | Alu { dest = X; _ } ->
       after { s with x = Interval.top }
     | Mov { dest = Y; _ } | Out { dest = Y; _ } | Alu { dest = Y; _ } ->
       after { s with y = Interval.top }
     | Sys Capture_arm -> after { s with since_arm = Some (Interval.exactly 0) }
     | Sys Halt -> []
     | _ -> after s)
;;

let analyse ?period ?single_capture_edge ~config (program : Isa.t list) =
  (* past the program the memory reads zero, [jmp 0], and the pc wraps at its end *)
  let program =
    Array.of_list
      (program
       @ List.init
           (program_size - List.length program)
           ~f:(fun _ -> Isa.Jmp { cond = Always; target = 0 }))
  in
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
    List.iter
      (step ?period ?single_capture_edge ~config s pc program.(pc))
      ~f:(fun (pc, s) -> visit pc s)
  done;
  (* Side-set makes an edge only on the ways in that leave its pins at another level, so
     the edge is placed by those ways alone and not by the join of all of them. *)
  let side_edge = Array.create ~len:n None in
  (* likewise the second half of a Manchester bit, on the ways in that bring one *)
  let flip_edge = Array.create ~len:n None in
  (* and the cycles since the edge before, for each instruction a way in comes from *)
  let gaps = Array.create ~len:n [] in
  let arrive ?from pc (s : State.t) =
    let add edges =
      edges.(pc) <- Some (Option.fold edges.(pc) ~init:s.phase ~f:Interval.join)
    in
    Option.iter from ~f:(fun from ->
      if not ([%equal: bool option] (makes_edge s program.(pc)) (Some false))
      then (
        let gap = Interval.shift s.since_edge 1 in
        let before = List.Assoc.find gaps.(pc) from ~equal:Int.equal in
        gaps.(pc)
        <- (from, Option.fold before ~init:gap ~f:Interval.join)
           :: List.Assoc.remove gaps.(pc) from ~equal:Int.equal));
    (match program.(pc) with
     | Op { side_set; _ }
       when config.Program_config.side_set_count > 0
            && not ([%equal: int option] s.side_set (Some side_set)) -> add side_edge
     | _ -> ());
    if not ([%equal: bool option] s.flip (Some false)) then add flip_edge
  in
  arrive 0 State.initial;
  Array.iteri entry ~f:(fun pc s ->
    Option.iter s ~f:(fun s ->
      List.iter
        (step ?period ?single_capture_edge ~config s pc program.(pc))
        ~f:(fun (next, s) -> if next < n then arrive ~from:pc next s)));
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
      (* a pin write shows on the pin the cycle after it issues; a read samples the pins
         in the cycle it issues *)
      let pin_event =
        match instruction with
        | Op
            { op =
                ( Set { dest = Pins | Pindirs; _ }
                | Out { dest = Pins | Pindirs; _ }
                | Mov { dest = Pins | Pindirs; _ } )
            ; _
            } -> Some (Pin_event.Edge (Interval.shift s.phase 1))
        | Op { op = In { source = Pins; _ } | Mov { source = Pins; _ }; _ } ->
          Some (Pin_event.Sample s.phase)
        | _ -> None
      in
      (* side-set is driven when the instruction issues, which for a wait is when it is
         reached and not when it releases, and shows on the pin the cycle after *)
      let side_event =
        match instruction with
        | Op _ when config.side_set_count > 0 ->
          Some
            { Side_event.at =
                Interval.shift (Option.value side_edge.(pc) ~default:s.phase) 1
            ; changes = Option.is_some side_edge.(pc)
            }
        | _ -> None
      in
      (* it shows the cycle after the next instruction issues, as the out's own half did *)
      let flip = Option.map flip_edge.(pc) ~f:(fun at -> Interval.shift at 1) in
      let gaps = List.sort gaps.(pc) ~compare:(fun (a, _) (b, _) -> Int.compare b a) in
      { Row.pc
      ; instruction
      ; phase = s.phase
      ; slack
      ; may_miss
      ; pin_event
      ; side_event
      ; flip
      ; gaps
      }))
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
    let pin_event = Option.value_map r.pin_event ~default:"" ~f:Pin_event.to_string in
    let side_event =
      match r.side_event with
      | Some { at; changes = true } -> Pin_event.with_jitter "side" at
      | _ -> ""
    in
    let flip = Option.value_map r.flip ~default:"" ~f:(Pin_event.with_jitter "flip") in
    (* one gap when every way in agrees, else each with where it comes from *)
    let gap =
      match List.dedup_and_sort (List.map r.gaps ~f:snd) ~compare:Interval.compare with
      | [] -> ""
      | [ gap ] -> [%string "  gap %{Interval.to_string gap}"]
      | _ ->
        "  gap "
        ^ String.concat
            ~sep:", "
            (List.map r.gaps ~f:(fun (from, gap) ->
               [%string "%{Interval.to_string gap} from %{from#Int}"]))
    in
    sprintf
      "%3d  %-28s phase %s%s%s%s%s%s"
      r.pc
      text
      (Interval.to_string r.phase)
      slack
      pin_event
      side_event
      flip
      gap)
  |> String.concat ~sep:"\n"
;;

module Verdict = struct
  type t =
    { words : int
    ; deadline_waits : int
    ; worst_slack : int option
    }
  [@@deriving sexp_of]

  let to_string t =
    let slack =
      Option.value_map t.worst_slack ~default:"" ~f:(fun s ->
        [%string ", worst slack %{s#Int}"])
    in
    let waits = if t.deadline_waits = 1 then "wait" else "waits" in
    [%string "%{t.words#Int} words, %{t.deadline_waits#Int} deadline %{waits}%{slack}"]
  ;;
end

let check ?period ?single_capture_edge ~config (program : Asm.Program.t) =
  let rows =
    analyse
      ?period
      ?single_capture_edge
      ~config:(Asm.Program.configure program config)
      program.instructions
  in
  let waits = List.filter rows ~f:(fun r -> Option.is_some r.slack) in
  match List.filter waits ~f:(fun r -> r.may_miss) with
  | [] ->
    let worst_slack =
      List.filter_map waits ~f:(fun r -> Option.bind r.slack ~f:(fun s -> s.lo))
      |> List.min_elt ~compare:Int.compare
    in
    Ok
      { Verdict.words = List.length program.instructions
      ; deadline_waits = List.length waits
      ; worst_slack
      }
  | misses ->
    let unbounded = List.exists misses ~f:(fun r -> Option.is_none r.phase.hi) in
    [ [ [%string
          "%{List.length misses#Int} of %{List.length waits#Int} deadline waits may be \
           missed"]
      ; to_string ~side_set_count:program.side_set_count misses
      ]
    ; (if unbounded
       then
         [ "a bound of ? means none: the way here has a wait for a pin or a fifo, a \
            capture nothing is assumed about, a period the host loads, or a loop that \
            falls further behind on every pass"
         ]
       else [])
    ]
    |> List.concat
    |> String.concat ~sep:"\n"
    |> Or_error.error_string
;;
