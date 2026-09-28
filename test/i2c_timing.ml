open! Core
open Protocol_emulator

module Edge = struct
  type t =
    | Scl_rise
    | Scl_fall
    | Data
    | Start
    | Stop
  [@@deriving sexp_of, equal]
end

module Timing = struct
  type t =
    { name : string
    ; from : Edge.t
    ; until : Edge.t
    ; through : Edge.t list
    ; min_ns : int
    }
end

let timing name ~from ~until ?(through = []) min_ns =
  { Timing.name; from; until; through; min_ns }
;;

let fast_mode_plus =
  [ timing
      "SCL period"
      ~from:Scl_rise
      ~until:Scl_rise
      ~through:[ Scl_fall; Data; Start; Stop ]
      1000
  ; timing "tLOW" ~from:Scl_fall ~until:Scl_rise ~through:[ Data ] 500
  ; timing "tHIGH" ~from:Scl_rise ~until:Scl_fall ~through:[ Start; Stop ] 260
  ; timing "tHD;STA" ~from:Start ~until:Scl_fall 260
  ; timing "tSU;STA" ~from:Scl_rise ~until:Start 260
  ; timing "tHD;DAT" ~from:Scl_fall ~until:Data 0
  ; timing "tSU;DAT" ~from:Data ~until:Scl_rise 50
  ; timing "tSU;STO" ~from:Scl_rise ~until:Stop 260
  ; timing "tBUF" ~from:Stop ~until:Start 500
  ]
;;

module Bound = struct
  type t =
    { timing : Timing.t
    ; cycles : Interval.t option
    ; met : bool
    }
end

(* An instruction's bus edges given SCL before it, and SCL after. Edges show the cycle
   after issue. *)
let bus_edges (instruction : Isa.t) ~scl =
  match instruction with
  | Jmp _ -> [], scl
  | Op { op; side_set; _ } ->
    let released = side_set = 0 in
    let sda : Edge.t list =
      match op with
      | Set { dest = Pindirs; value } when scl ->
        if value land 1 = 1 then [ Start ] else [ Stop ]
      | (Mov { dest = Pindirs; _ } | Out { dest = Pindirs; _ }) when scl ->
        [ Start; Stop ]
      | Set { dest = Pindirs; _ } | Mov { dest = Pindirs; _ } | Out { dest = Pindirs; _ }
        -> [ Data ]
      | _ -> []
    in
    let scl_edge : Edge.t list =
      if Bool.equal released scl
      then []
      else if released
      then [ Scl_rise ]
      else [ Scl_fall ]
    in
    sda @ scl_edge, released
;;

(* the later of two times, an end that is [None] being as early or as late as can be *)
let later (a : Interval.t) (b : Interval.t) : Interval.t =
  { lo = Option.merge a.lo b.lo ~f:Int.max; hi = Option.map2 a.hi b.hi ~f:Int.max }
;;

let unbounded (i : Interval.t) = { i with hi = None }

(* where [t] is after an instruction that issues at [entry], with [p] on the way in *)
let deadline_after (op : Isa.Op.t) ~entry ~t ~p =
  match op with
  | Mov { dest = T; op = Copy; source = Now } -> Some entry
  | Mov { dest = T; _ } | Out { dest = T; _ } -> None
  | Alu { dest = T; op = Add; operand = Imm n } ->
    Option.map t ~f:(Fn.flip Interval.shift n)
  | Alu { dest = T; op = Sub; operand = Imm n } ->
    Option.map t ~f:(Fn.flip Interval.shift (-n))
  | Alu { dest = T; op = Add; operand = Reg P } -> Option.map t ~f:(Interval.plus p)
  | Alu { dest = T; _ } -> None
  | _ -> t
;;

(* which ways a jump may go, as far as the analyser knows the counters *)
let ways (row : Analyser.Row.t) (cond : Isa.Jmp_cond.Cases.t) =
  let counter (i : Interval.t) =
    not ([%equal: Interval.t] i (Interval.exactly 0)), Interval.contains i 0
  in
  match cond with
  | Always -> true, false
  | X_dec -> counter row.x
  | Y_dec -> counter row.y
  | _ -> true, true
;;

module Way = struct
  type t =
    { pc : int
    ; scl : bool
    ; entry : Interval.t (** When it issues first, from the edge the timing starts on. *)
    ; t : Interval.t option (** The deadline, on the same clock. *)
    ; passed : Int.Set.t
    }
end

let check ~clock_mhz ~config (program : Asm.Program.t) timings =
  let config = Asm.Program.configure program config in
  if config.side_set_count <> 1 || not config.side_set_pindirs
  then raise_s [%message "BUG: SCL has to be the one side-set pin, as a direction"];
  let instructions = Array.of_list program.instructions in
  let n = Array.length instructions in
  let rows = Array.create ~len:n None in
  List.iter
    (Analyser.analyse ~config program.instructions)
    ~f:(fun (row : Analyser.Row.t) -> if row.pc < n then rows.(row.pc) <- Some row);
  let following pc = if pc = config.wrap_top then config.wrap_bottom else pc + 1 in
  let successors pc (row : Analyser.Row.t) =
    match instructions.(pc) with
    | Jmp { cond; target } ->
      let taken, untaken = ways row cond in
      List.filter_opt
        [ Option.some_if taken target; Option.some_if untaken (following pc) ]
    | Op { op = Sys Halt; _ } -> []
    | Op _ -> [ following pc ]
  in
  (* every instruction with the level SCL has on the way in, from the pins let go *)
  let levels =
    let seen = Hash_set.Poly.create () in
    let rec visit pc ~scl =
      if pc < n && Option.is_some rows.(pc) && not (Hash_set.mem seen (pc, scl))
      then (
        Hash_set.add seen (pc, scl);
        let _, scl' = bus_edges instructions.(pc) ~scl in
        List.iter (successors pc (Option.value_exn rows.(pc))) ~f:(visit ~scl:scl'))
    in
    visit 0 ~scl:true;
    Hash_set.to_list seen
  in
  (* Cycles from [timing.from] at [pc] to each [timing.until] reached, joined, and whether
     some path looped before getting there. *)
  let from (timing : Timing.t) pc ~scl =
    let row = Option.value_exn rows.(pc) in
    let edges, _ = bus_edges instructions.(pc) ~scl in
    let at =
      match timing.from with
      | Scl_rise | Scl_fall -> Option.map row.side_event ~f:(fun side -> side.at)
      | Data | Start | Stop ->
        (match row.pin_event with
         | Some (Edge at) -> Some at
         | Some (Sample _) | None -> None)
    in
    match List.mem edges timing.from ~equal:Edge.equal, at with
    | false, _ | _, None -> None
    | true, Some at ->
      let found = ref None in
      let came_round = ref false in
      let record time =
        found := Some (Option.value_map !found ~default:time ~f:(Interval.join time))
      in
      let rec follow (way : Way.t) ~first =
        match if way.pc < n then rows.(way.pc) else None with
        | None -> ()
        | Some row ->
          let edges, scl = bus_edges instructions.(way.pc) ~scl:way.scl in
          (* the edge the timing starts on is not one it can end on *)
          let edges =
            if first
            then (
              let before, rest =
                List.split_while edges ~f:(Fn.non (Edge.equal timing.from))
              in
              before @ List.drop rest 1)
            else edges
          in
          (* the edges of one instruction are at once, and may be one or another *)
          let meets =
            if List.mem edges timing.until ~equal:Edge.equal
            then `Ends
            else if List.for_all edges ~f:(List.mem timing.through ~equal:Edge.equal)
            then `Goes_on
            else `Stops
          in
          (match meets with
           | `Ends -> record (Interval.shift way.entry 1)
           | `Stops -> ()
           | `Goes_on when (not first) && Set.mem way.passed way.pc -> came_round := true
           | `Goes_on ->
             let go ~entry ~t =
               List.iter (successors way.pc row) ~f:(fun pc ->
                 follow
                   { pc; scl; entry; t; passed = Set.add way.passed way.pc }
                   ~first:false)
             in
             (match instructions.(way.pc) with
              | Jmp _ -> go ~entry:(Interval.shift way.entry Isa.jmp_cycles) ~t:way.t
              | Op { op = Wait (Deadline { advance }); delay; _ } ->
                let release =
                  Option.value_map
                    way.t
                    ~default:(unbounded way.entry)
                    ~f:(later way.entry)
                in
                let t =
                  if advance
                  then Option.map way.t ~f:(Interval.plus row.period)
                  else way.t
                in
                go ~entry:(Interval.shift release (1 + delay)) ~t
              | Op { op = Wait _; delay; _ } ->
                go ~entry:(Interval.shift (unbounded way.entry) (1 + delay)) ~t:way.t
              | Op { op; delay; _ } ->
                go
                  ~entry:(Interval.shift way.entry (1 + delay))
                  ~t:(deadline_after op ~entry:way.entry ~t:way.t ~p:row.period)))
      in
      (* the edge shows at [at] from the deadline and a cycle after the issue *)
      let entry = Interval.exactly (-1) in
      let t =
        Option.both at.lo at.hi
        |> Option.map ~f:(fun (lo, hi) -> { Interval.lo = Some (-hi); hi = Some (-lo) })
      in
      follow { pc; scl; entry; t; passed = Int.Set.empty } ~first:true;
      Some (!found, !came_round)
  in
  List.map timings ~f:(fun (timing : Timing.t) ->
    let bounds = List.filter_map levels ~f:(fun (pc, scl) -> from timing pc ~scl) in
    let cycles =
      List.filter_map bounds ~f:fst
      |> List.reduce ~f:Interval.join
      |> Option.map ~f:(fun (cycles : Interval.t) ->
        if List.exists bounds ~f:snd then unbounded cycles else cycles)
    in
    let min_cycles = ((timing.min_ns * clock_mhz) + 999) / 1000 in
    let met =
      Option.value_map cycles ~default:true ~f:(fun (cycles : Interval.t) ->
        Option.value_map cycles.lo ~default:false ~f:(fun lo -> lo >= min_cycles))
    in
    { Bound.timing; cycles; met })
;;
