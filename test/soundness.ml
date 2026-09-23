open! Core
open Protocol_emulator

module Stimulus = struct
  type t =
    { cycles : int
    ; inputs : int -> int
    ; host : int -> Machine.t -> Machine.t
    }

  let random ~seed ~cycles =
    let random = Splittable_random.of_int seed in
    let int hi = Splittable_random.int random ~lo:0 ~hi in
    let host _ (m : Machine.t) =
      let m =
        if int 3 = 0 && List.length m.tx_fifo < Machine.fifo_depth
        then Machine.write_tx m (int 0xffff) |> ok_exn
        else m
      in
      if int 3 = 0
      then (
        match Machine.read_rx m with
        | Some (_, popped) -> popped
        | None -> m)
      else m
    in
    { cycles; inputs = (fun _ -> int ((1 lsl Isa.pin_space) - 1)); host }
  ;;
end

type t =
  { issues : int
  ; side_edges : int
  ; flips : int
  ; gaps : int
  ; reached : int
  ; violations : (int * int * int * int) list
  }

let phase (m : Machine.t) =
  let d = (m.now - m.t) land ((1 lsl Isa.timer_bits) - 1) in
  if d >= 1 lsl (Isa.timer_bits - 1) then d - (1 lsl Isa.timer_bits) else d
;;

(* Only the pins side-set can move: outputs, bidirectionals and wires for levels, the
   bidirectionals for directions. *)
let side_set_moves (c : Program_config.t) (m : Machine.t) value =
  let level = if c.side_set_pindirs then m.pin_dir else m.pin_out in
  List.init c.side_set_count ~f:Fn.id
  |> List.exists ~f:(fun j ->
    let pin = (c.side_set_base + j) % Isa.pin_space in
    let movable =
      if c.side_set_pindirs
      then pin >= Isa.first_bidir_pin && pin < Isa.num_pins
      else pin >= Isa.first_output_pin
    in
    movable && (level lsr pin) land 1 <> (value lsr j) land 1)
;;

let check ?period ?single_capture_edge ?(preload = []) ~config stimuli words =
  (* the memory past the program reads zero, as the machine's does *)
  let instructions =
    words @ List.init ((1 lsl Isa.pc_bits) - List.length words) ~f:(fun _ -> 0)
    |> List.map ~f:(fun w ->
      Isa.of_word ~side_set_count:config.Program_config.side_set_count w |> ok_exn)
    |> Array.of_list
  in
  let rows = Array.create ~len:(Array.length instructions) None in
  List.iter
    (Analyser.analyse ?period ?single_capture_edge ~config (Array.to_list instructions))
    ~f:(fun row -> rows.(row.pc) <- Some row);
  let issues = ref 0 in
  let side_edges = ref 0 in
  let flips = ref 0 in
  let gaps = ref 0 in
  let reached = Array.create ~len:(Array.length instructions) false in
  let violations = ref [] in
  List.iteri stimuli ~f:(fun run (stimulus : Stimulus.t) ->
    let m = ref (Machine.create ~config ~program:words |> ok_exn) in
    List.iter preload ~f:(fun w -> m := Machine.write_tx !m w |> ok_exn);
    let last = ref None in
    let came_from = ref None in
    let last_edge = ref None in
    for cycle = 0 to stimulus.cycles - 1 do
      let t = !m in
      if (not t.halted) && t.stall = 0
      then (
        (* an edge shows the cycle after the issue that makes it, a write or a flip, and
           has to be as far from the edge before as the row says for where it came from *)
        let new_pc =
          not (Option.equal [%equal: int * int] !last (Some (cycle - 1, t.pc)))
        in
        let edge =
          Option.is_some t.flip
          ||
          match instructions.(t.pc) with
          | Op { op = Set { dest = Pins | Pindirs; _ }; _ }
          | Op { op = Out { dest = Pins | Pindirs; _ }; _ }
          | Op { op = Mov { dest = Pins | Pindirs; _ }; _ } -> new_pc
          | _ -> false
        in
        if edge
        then (
          (match !came_from, !last_edge, rows.(t.pc) with
           | Some from, Some at, Some row ->
             Int.incr gaps;
             let ok =
               match List.Assoc.find row.gaps from ~equal:Int.equal with
               | Some gap -> Interval.contains gap (cycle + 1 - at)
               | None -> false
             in
             if not ok
             then violations := (run, cycle, t.pc, cycle + 1 - at) :: !violations
           | _ -> ());
          last_edge := Some (cycle + 1));
        if new_pc then came_from := Some t.pc;
        (* the second half of a Manchester bit comes with this issue *)
        (match t.flip with
         | Some _ when not (config.break_enable && t.pc = config.break_pc && not t.resumed)
           ->
           Int.incr flips;
           let ok =
             match rows.(t.pc) with
             | Some { flip = Some at; _ } -> Interval.contains at (phase t + 1)
             | _ -> false
           in
           if not ok then violations := (run, cycle, t.pc, phase t + 1) :: !violations
         | _ -> ());
        let entry =
          not (Option.equal [%equal: int * int] !last (Some (cycle - 1, t.pc)))
        in
        last := Some (cycle, t.pc);
        if entry
        then (
          Int.incr issues;
          reached.(t.pc) <- true;
          let ok =
            match rows.(t.pc) with
            | Some row -> Interval.contains row.phase (phase t)
            | None -> false
          in
          if not ok then violations := (run, cycle, t.pc, phase t) :: !violations);
        (* a data pull the machine is about to refuse must be one the row warns of *)
        (match instructions.(t.pc) with
         | Op { op = Out _; _ }
           when config.autopull
                && config.autopull_data
                && t.osr_count >= config.pull_threshold
                && t.data_age + 1 < Isa.data_settle ->
           let ok =
             match rows.(t.pc) with
             | Some row -> row.may_underrun
             | None -> false
           in
           if not ok then violations := (run, cycle, t.pc, phase t) :: !violations
         | _ -> ());
        match instructions.(t.pc) with
        | Op { side_set; _ } when side_set_moves config t side_set ->
          Int.incr side_edges;
          let ok =
            match rows.(t.pc) with
            | Some { side_event = Some { at; changes = true }; _ } ->
              Interval.contains at (phase t + 1)
            | _ -> false
          in
          if not ok then violations := (run, cycle, t.pc, phase t + 1) :: !violations
        | _ -> ());
      (* the host goes first, then the pins, whichever of them draws at random *)
      let t = stimulus.host cycle t in
      let inputs = stimulus.inputs cycle in
      m := Machine.step t ~inputs
    done);
  { issues = !issues
  ; side_edges = !side_edges
  ; flips = !flips
  ; gaps = !gaps
  ; reached = Array.count reached ~f:Fn.id
  ; violations = List.rev !violations
  }
;;
