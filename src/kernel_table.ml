open! Core
open! Hardcaml

module Make (Rows : Kernel_intf.Rows) = struct
  open Rows
  module K = Kernel_comb.Make (Rows) (Bits)

  type t = Bits.t Row.t array

  (* bounds nothing *)
  let no_edge =
    let held =
      { Held.may = Bits.vdd; since = Bits.zero Isa.data_bits; mark = K.mark_none }
    in
    { Pin.at0 = held; at1 = held; fresh = Bits.gnd }
  ;;

  let full_phase = Interval.top

  (* the timer's signed values are [-half, half - 1] *)
  let half = 1 lsl (timer_bits - 1)

  (* an offset, or a slope, that the timer's width cannot hold says nothing *)
  let offset_bounds ~slope (offset : Interval.t) =
    let fits n = n >= -half && n < half in
    match offset.lo, offset.hi with
    | Some lo, Some hi when slope <> 0 && fits slope && fits lo && fits hi ->
      Some (slope, lo, hi)
    | _ -> None
  ;;

  let row
    ~(phase : Interval.t)
    ~slope
    ~(offset : Interval.t)
    ~(period : Interval.t)
    ~(x : Interval.t)
    ~(y : Interval.t)
    ~(since_arm : Interval.t option)
    ~captured
    ~awaiting
    =
    let signed n = Bits.of_signed_int ~width:timer_bits n in
    let data_max = (1 lsl Isa.data_bits) - 1 in
    (* the analyser's register bounds are the value's, so clamp them to its width *)
    let data bound ~default =
      Bits.of_unsigned_int
        ~width:Isa.data_bits
        (Int.clamp_exn (Option.value bound ~default) ~min:0 ~max:data_max)
    in
    let arm_lo, arm_hi =
      let unsigned n = Bits.of_unsigned_int ~width:timer_bits n in
      match since_arm with
      | Some { lo = Some lo; hi = Some hi } when lo >= 0 && hi < half ->
        unsigned lo, unsigned hi
      | _ -> unsigned 0, Bits.ones timer_bits
    in
    (* an open end, or one the timer's width cannot hold, is the whole range, since the
       timer wraps *)
    let phase_lo, phase_hi =
      match phase.lo, phase.hi with
      | Some lo, Some hi when lo >= -half && hi < half -> lo, hi
      | _ -> -half, half - 1
    in
    let slope, offset_lo, offset_hi =
      offset_bounds ~slope offset |> Option.value ~default:(0, -half, half - 1)
    in
    { Row.phase_lo = signed phase_lo
    ; phase_hi = signed phase_hi
    ; slope = signed slope
    ; offset_lo = signed offset_lo
    ; offset_hi = signed offset_hi
    ; period_lo = data period.lo ~default:0
    ; period_hi = data period.hi ~default:data_max
    ; x_lo = data x.lo ~default:0
    ; x_hi = data x.hi ~default:data_max
    ; y_lo = data y.lo ~default:0
    ; y_hi = data y.hi ~default:data_max
    ; arm_lo
    ; arm_hi
    ; captured = Bits.of_bool captured
    ; awaiting = Bits.of_bool awaiting
    ; a = no_edge
    ; b = no_edge
    }
  ;;

  let unreached =
    { Row.phase_lo = Bits.of_signed_int ~width:timer_bits 1
    ; phase_hi = Bits.zero timer_bits
    ; slope = Bits.zero timer_bits
    ; offset_lo = Bits.of_signed_int ~width:timer_bits (-half)
    ; offset_hi = Bits.of_signed_int ~width:timer_bits (half - 1)
    ; period_lo = Bits.zero Isa.data_bits
    ; period_hi = Bits.zero Isa.data_bits
    ; x_lo = Bits.zero Isa.data_bits
    ; x_hi = Bits.zero Isa.data_bits
    ; y_lo = Bits.zero Isa.data_bits
    ; y_hi = Bits.zero Isa.data_bits
    ; arm_lo = Bits.zero timer_bits
    ; arm_hi = Bits.zero timer_bits
    ; captured = Bits.gnd
    ; awaiting = Bits.gnd
    ; a = no_edge
    ; b = no_edge
    }
  ;;

  let of_analyser (rows : Analyser.Row.t list) =
    let table = Array.create ~len:(1 lsl Isa.pc_bits) unreached in
    List.iter rows ~f:(fun r ->
      table.(r.pc)
      <- row
           ~phase:r.phase
           ~slope:r.slope
           ~offset:r.offset
           ~period:r.period
           ~x:r.x
           ~y:r.y
           ~since_arm:r.since_arm
           ~captured:r.captured
           ~awaiting:r.awaiting);
    table.(0)
    <- row
         ~phase:full_phase
         ~slope:0
         ~offset:Interval.top
         ~period:Interval.top
         ~x:Interval.top
         ~y:Interval.top
         ~since_arm:None
         ~captured:false
         ~awaiting:false;
    table
  ;;

  (* Where either may be: the least of their counts and marks at each bit. A bit it may
     not hold reads the top of both, so that joining comes to a fixed point. *)
  let join (p : _ Pin.t) (q : _ Pin.t) =
    let held (h : _ Held.t) (g : _ Held.t) =
      let top = { Held.may = Bits.gnd; since = K.since_limit; mark = K.mark_max } in
      let h = if Bits.to_bool h.may then h else top in
      let g = if Bits.to_bool g.may then g else top in
      { Held.may = Bits.(h.may |: g.may)
      ; since = (if Bits.(to_bool (h.since <: g.since)) then h.since else g.since)
      ; mark = (if Bits.(to_bool (h.mark <+ g.mark)) then h.mark else g.mark)
      }
    in
    { Pin.at0 = held p.at0 q.at0
    ; at1 = held p.at1 q.at1
    ; fresh = Bits.(p.fresh &: q.fresh)
    }
  ;;

  (* after [Row_table.fixpoint]'s joins at a pc run out, its marks bound nothing, so a
     mark that falls round a loop cannot keep it going *)
  let forget_marks (p : _ Pin.t) =
    let held (h : _ Held.t) = { h with mark = K.mark_none } in
    { p with at0 = held p.at0; at1 = held p.at1 }
  ;;

  let with_edges
    ?(single_capture_edge = false)
    (table : t)
    ~(config : Program_config.t)
    ~spacing
    ~words
    =
    let size = Array.length table in
    let words = Array.of_list words in
    let side_set_count = Bits.of_unsigned_int ~width:2 config.side_set_count in
    let fraction = Bits.of_bool (config.period_fraction <> 0) in
    let capture =
      { Capture.pin =
          Bits.of_unsigned_int ~width:Isa.Field.wait_index.width config.capture_pin
      ; rising = Bits.of_bool config.capture_rising
      ; single_edge = Bits.of_bool single_capture_edge
      }
    in
    let spacing = { With_valid.valid = Bits.vdd; value = spacing } in
    let reached pc = not (Bits.to_bool (K.is_empty table.(pc))) in
    (* the pair's bounds after the word at [pc], to each pc it may go to *)
    let visit pc state =
      match state with
      | Some (a, b) when reached pc ->
        let w = Row_table.word words pc in
        let a, b =
          K.edge_images
            ~side_set_count
            ~fraction
            ~capture
            ~spacing
            ~word:w
            ~row:{ (table.(pc)) with a; b }
        in
        let target = Isa.Field.select (module Bits) Isa.Field.jmp_target w in
        let following =
          if pc = config.wrap_top then config.wrap_bottom else (pc + 1) % size
        in
        let successors =
          match
            Isa.of_word ~side_set_count:config.side_set_count (Bits.to_unsigned_int w)
          with
          | Error _ | Ok (Op { op = Sys Halt; _ }) -> []
          | Ok (Jmp { cond = Always; _ }) -> [ Bits.to_unsigned_int target ]
          | Ok (Jmp _) -> [ Bits.to_unsigned_int target; following ]
          | Ok (Op _) -> [ following ]
        in
        List.map successors ~f:(fun next -> next, (a, b))
      | _ -> []
    in
    let join_pair state (a, b) =
      match state with
      | None -> Some (join a a, join b b)
      | Some (a', b') -> Some (join a a', join b b')
    in
    let starting =
      let held = { Held.may = Bits.vdd; since = K.since_limit; mark = K.mark_max } in
      { Pin.at0 = held; at1 = held; fresh = Bits.vdd }
    in
    let init = Array.create ~len:size None in
    init.(0) <- Some (starting, starting);
    let state =
      Row_table.fixpoint
        init
        ~visit
        ~join:join_pair
        ~widen:(Option.map ~f:(fun (a, b) -> forget_marks a, forget_marks b))
        ~equal:[%equal: (Bits.t Pin.t * Bits.t Pin.t) option]
    in
    Array.mapi table ~f:(fun pc row ->
      match state.(pc) with
      | Some (a, b) when reached pc -> { row with a; b }
      | _ -> row)
  ;;
end
