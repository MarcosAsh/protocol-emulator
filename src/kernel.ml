open! Core
open! Hardcaml

module Edge = struct
  type 'a t =
    { since : 'a [@bits Isa.data_bits]
    ; level : 'a
    ; fresh : 'a
    }
  [@@deriving hardcaml]
end

module Spacing = struct
  type 'a t =
    { a : 'a [@bits Isa.Field.wait_index.width]
    ; b : 'a [@bits Isa.Field.wait_index.width]
    ; dirs : 'a
    ; side_set_base : 'a [@bits Isa.Field.wait_index.width]
    ; side_set_pindirs : 'a
    ; set_base : 'a [@bits Isa.Field.wait_index.width]
    ; set_count : 'a [@bits 3]
    ; out_base : 'a [@bits Isa.Field.wait_index.width]
    ; out_count : 'a [@bits Isa.count_bits]
    ; hold_a : 'a list [@length 4] [@bits Isa.data_bits]
    ; apart_a : 'a list [@length 4] [@bits Isa.data_bits]
    ; hold_b : 'a list [@length 4] [@bits Isa.data_bits]
    ; apart_b : 'a list [@length 4] [@bits Isa.data_bits]
    }
  [@@deriving hardcaml]

  module Spec = struct
    type t =
      { a : int
      ; b : int
      ; dirs : bool
      ; hold_a : own:bool -> other:bool -> int
      ; apart_a : own:bool -> other:bool -> int
      ; hold_b : own:bool -> other:bool -> int
      ; apart_b : own:bool -> other:bool -> int
      }
  end

  let of_spec (config : Program_config.t) (spec : Spec.t) =
    let pin n = Bits.of_unsigned_int ~width:Isa.Field.wait_index.width n in
    let cycles f =
      List.init 4 ~f:(fun i ->
        Bits.of_unsigned_int
          ~width:Isa.data_bits
          (f ~own:(i lsr 1 = 1) ~other:(i land 1 = 1)))
    in
    { a = pin spec.a
    ; b = pin spec.b
    ; dirs = Bits.of_bool spec.dirs
    ; side_set_base = pin config.side_set_base
    ; side_set_pindirs = Bits.of_bool config.side_set_pindirs
    ; set_base = pin config.set_base
    ; set_count = Bits.of_unsigned_int ~width:3 config.set_count
    ; out_base = pin config.out_base
    ; out_count = Bits.of_unsigned_int ~width:Isa.count_bits config.out_count
    ; hold_a = cycles spec.hold_a
    ; apart_a = cycles spec.apart_a
    ; hold_b = cycles spec.hold_b
    ; apart_b = cycles spec.apart_b
    }
  ;;
end

module Spaced = With_valid.Wrap.Make (Spacing)

module Make_timer (Timer : Engine.Timer) = struct
  let timer_bits = Timer.timer_bits

  (* an instruction's cycles, [1 lsl Isa.delay_bits] at most, stay below [arm_limit] *)
  let () =
    if timer_bits < Isa.delay_bits + 2
    then
      raise_s [%message "BUG: the timer is too narrow for the kernel" (timer_bits : int)]
  ;;

  (* wide enough for a count of cycles, 16 bits, less a phase *)
  let mark_bits = Int.max timer_bits (Isa.data_bits + 1) + 2

  module Held = struct
    type 'a t =
      { may : 'a
      ; since : 'a [@bits Isa.data_bits]
      ; mark : 'a [@bits mark_bits]
      }
    [@@deriving hardcaml]
  end

  module Pin = struct
    type 'a t =
      { at0 : 'a Held.t
      ; at1 : 'a Held.t
      ; fresh : 'a
      }
    [@@deriving hardcaml]
  end

  module Row = struct
    type 'a t =
      { phase_lo : 'a [@bits timer_bits]
      ; phase_hi : 'a [@bits timer_bits]
      ; slope : 'a [@bits timer_bits]
      ; offset_lo : 'a [@bits timer_bits]
      ; offset_hi : 'a [@bits timer_bits]
      ; period_lo : 'a [@bits Isa.data_bits]
      ; period_hi : 'a [@bits Isa.data_bits]
      ; x_lo : 'a [@bits Isa.data_bits]
      ; x_hi : 'a [@bits Isa.data_bits]
      ; y_lo : 'a [@bits Isa.data_bits]
      ; y_hi : 'a [@bits Isa.data_bits]
      ; arm_lo : 'a [@bits timer_bits]
      ; arm_hi : 'a [@bits timer_bits]
      ; captured : 'a
      ; awaiting : 'a
      ; a : 'a Pin.t
      ; b : 'a Pin.t
      }
    [@@deriving hardcaml]
  end

  module Capture = struct
    type 'a t =
      { pin : 'a [@bits Isa.Field.wait_index.width]
      ; rising : 'a
      ; single_edge : 'a
      }
    [@@deriving hardcaml]
  end

  module Holds = struct
    type 'a t =
      { phase : 'a
      ; offset : 'a
      ; period : 'a
      ; x : 'a
      ; y : 'a
      ; arm : 'a
      ; captured : 'a
      ; awaiting : 'a
      ; edge_a : 'a
      ; edge_b : 'a
      }
    [@@deriving hardcaml]
  end

  module Conjuncts = struct
    type 'a t =
      { in_time : 'a
      ; wide_a : 'a
      ; wide_b : 'a
      ; next : 'a Holds.t
      ; target : 'a Holds.t
      }
    [@@deriving hardcaml]
  end

  module Step = struct
    type 'a t =
      { next_phase : 'a [@bits timer_bits]
      ; bounded : 'a
      ; may_carry : 'a
      ; next_period : 'a [@bits Isa.data_bits]
      ; period_known : 'a
      ; next_x : 'a [@bits Isa.data_bits]
      ; x_known : 'a
      ; next_y : 'a [@bits Isa.data_bits]
      ; y_known : 'a
      ; taken : 'a
      ; taken_known : 'a
      ; next_arm : 'a [@bits timer_bits]
      ; next_arm_known : 'a
      ; next_captured : 'a
      ; next_awaiting : 'a
      ; capture_bounded : 'a
      ; next_a : 'a Edge.t
      ; next_b : 'a Edge.t
      ; wide_a : 'a
      ; wide_b : 'a
      ; halts : 'a
      }
    [@@deriving hardcaml]
  end

  module Decoded = Decoder.Decoded

  module Make (Comb : Comb.S) = struct
    open Comb
    module Decoder = Decoder.Make (Comb)
    module Opcode = Isa.Opcode.Make_comb (Comb)
    module Jmp_cond = Isa.Jmp_cond.Make_comb (Comb)
    module Wait_source = Isa.Wait_source.Make_comb (Comb)
    module Out_dest = Isa.Out_dest.Make_comb (Comb)
    module Mov_dest = Isa.Mov_dest.Make_comb (Comb)
    module Mov_op = Isa.Mov_op.Make_comb (Comb)
    module Mov_source = Isa.Mov_source.Make_comb (Comb)
    module Set_dest = Isa.Set_dest.Make_comb (Comb)
    module Alu_dest = Isa.Alu_dest.Make_comb (Comb)
    module Alu_op = Isa.Alu_op.Make_comb (Comb)
    module Alu_reg = Isa.Alu_reg.Make_comb (Comb)
    module Sys_op = Isa.Sys_op.Make_comb (Comb)

    let timer x = uresize x ~width:timer_bits

    (* the classes the analyser's transfer function tells apart *)
    module Class = struct
      type t =
        { cycles : Comb.t
        ; deadline : Comb.t
        ; advance : Comb.t
        ; anchor : Comb.t (** [mov t, now] *)
        ; add_imm : Comb.t
        ; add_p : Comb.t
        ; add_x : Comb.t
        ; add_y : Comb.t
        ; sub_imm : Comb.t
        ; imm : Comb.t
        ; bounded : Comb.t
        ; jump : Comb.t
        ; always : Comb.t
        ; x_dec : Comb.t
        ; y_dec : Comb.t
        ; x_ne_y : Comb.t
        ; halts : Comb.t
        ; set_value : Comb.t
        ; set_p : Comb.t
        ; writes_p : Comb.t
        ; set_x : Comb.t
        ; writes_x : Comb.t
        ; set_y : Comb.t
        ; writes_y : Comb.t
        ; arm : Comb.t
        ; capturing : Comb.t (** a wait for the captured edge, under the assumption *)
        ; pin_or_fifo_wait : Comb.t
        ; from_capture : Comb.t (** [mov t, capture] *)
        ; decoded : Comb.t Decoded.t
        }

      let of_word ~side_set_count ~(capture : _ Capture.t) word =
        let d = Decoder.decode ~side_set_count word in
        let is op = Opcode.is d.opcode op in
        let jump = is Jmp in
        let deadline = is Wait &: Wait_source.is d.wait_source Deadline in
        let alu_t = is Alu &: Alu_dest.is d.alu_dest T in
        let add = Alu_op.is d.alu_op Add in
        let add_reg r = alu_t &: add &: d.alu_is_reg &: Alu_reg.is d.alu_reg r in
        let add_imm = alu_t &: add &: ~:(d.alu_is_reg) in
        let sub_imm = alu_t &: Alu_op.is d.alu_op Sub &: ~:(d.alu_is_reg) in
        let mov_t = is Mov &: Mov_dest.is d.mov_dest T in
        let anchor = mov_t &: Mov_op.is d.mov_op Copy &: Mov_source.is d.mov_source Now in
        let unbounded =
          is Wait
          &: ~:deadline
          |: (mov_t &: ~:anchor)
          |: (is Out &: Out_dest.is d.out_dest T)
          |: (alu_t &: ~:(add_imm |: add_reg P |: add_reg X |: add_reg Y |: sub_imm))
        in
        let writes (mov : Isa.Mov_dest.Cases.t) out alu =
          is Mov
          &: Mov_dest.is d.mov_dest mov
          |: (is Out &: Out_dest.is d.out_dest out)
          |: (is Alu &: Alu_dest.is d.alu_dest alu)
        in
        let cond c = jump &: Jmp_cond.is d.jmp_cond c in
        let pin_wait =
          is Wait
          &: (Wait_source.is d.wait_source Pin_level
              |: Wait_source.is d.wait_source Pin_edge)
        in
        let capturing =
          pin_wait
          &: capture.single_edge
          &: (d.wait_index ==: capture.pin)
          &: (d.wait_polarity ==: capture.rising)
        in
        { cycles =
            mux2 jump (of_unsigned_int ~width:timer_bits Isa.jmp_cycles)
            @@ (timer d.delay +:. 1)
        ; deadline
        ; advance = deadline &: d.wait_polarity
        ; anchor
        ; add_imm
        ; add_p = add_reg P
        ; add_x = add_reg X
        ; add_y = add_reg Y
        ; sub_imm
        ; imm = timer d.alu_imm
        ; bounded = ~:unbounded
        ; jump
        ; always = cond Always
        ; x_dec = cond X_dec
        ; y_dec = cond Y_dec
        ; x_ne_y = cond X_ne_y
        ; halts = ~:(d.valid) |: (is Sys &: Sys_op.is d.sys_op Halt)
        ; set_value = uresize d.set_value ~width:Isa.data_bits
        ; set_p = is Set &: Set_dest.is d.set_dest P
        ; writes_p = writes P P P
        ; set_x = is Set &: Set_dest.is d.set_dest X
        ; writes_x = writes X X X
        ; set_y = is Set &: Set_dest.is d.set_dest Y
        ; writes_y = writes Y Y Y
        ; arm = is Sys &: Sys_op.is d.sys_op Capture_arm
        ; capturing
        ; pin_or_fifo_wait = is Wait &: ~:deadline
        ; from_capture =
            mov_t &: Mov_op.is d.mov_op Copy &: Mov_source.is d.mov_source Capture
        ; decoded = d
        }
      ;;
    end

    (* Whether [pin] is in the run of [count] pins from [base], wrapping at the pin space
       as [Pins.write] does, and the bit of [value] it takes there. *)
    let in_run ~pin ~base ~count ~value =
      let space = Isa.pin_space in
      let six x = uresize x ~width:6 in
      let base = mux2 (base >=:. space) (base -:. space) base in
      let offset =
        mux2 (pin >=: base) (six pin -: six base) (six pin +:. space -: six base)
      in
      ( offset <: six count &: (offset <:. Isa.data_bits)
      , mux offset (bits_lsb (uresize value ~width:Isa.data_bits)) )
    ;;

    (* What the word does to the watched bit of [pin], as the core's pin writes do:
       side-set, then a set, out or mov, where the pin takes that register. [data]: out or
       mov data writes it. *)
    module Watched = struct
      type t =
        { written : Comb.t
        ; bit : Comb.t
        ; data : Comb.t
        }

      let of_word ~side_set_count ~(spacing : _ Spacing.t) (d : _ Decoded.t) ~pin =
        let is op = Opcode.is d.opcode op in
        let takes =
          mux2
            spacing.dirs
            (pin >=:. Isa.first_bidir_pin &: (pin <:. Isa.num_pins))
            (pin >=:. Isa.first_output_pin &: (pin <:. Isa.pin_space))
        in
        let run = in_run ~pin in
        let side_hit, side_bit =
          run ~base:spacing.side_set_base ~count:side_set_count ~value:d.side_set
        in
        let set_hit, set_bit =
          run ~base:spacing.set_base ~count:spacing.set_count ~value:d.set_value
        in
        let out_hit, _ = run ~base:spacing.out_base ~count:d.shift_count ~value:gnd in
        let mov_hit, _ = run ~base:spacing.out_base ~count:spacing.out_count ~value:gnd in
        let to_dirs dirs pins = mux2 spacing.dirs dirs pins in
        let sided =
          ~:(is Jmp) &: (spacing.side_set_pindirs ==: spacing.dirs) &: side_hit
        in
        let set =
          is Set
          &: to_dirs (Set_dest.is d.set_dest Pindirs) (Set_dest.is d.set_dest Pins)
          &: set_hit
        in
        let out =
          to_dirs (Out_dest.is d.out_dest Pindirs) (Out_dest.is d.out_dest Pins)
        in
        let mov =
          to_dirs (Mov_dest.is d.mov_dest Pindirs) (Mov_dest.is d.mov_dest Pins)
        in
        let data = is Out &: out &: out_hit |: (is Mov &: mov &: mov_hit) in
        { written = d.valid &: takes &: (sided |: set)
        ; bit = mux2 set set_bit side_bit
        ; data = d.valid &: takes &: data
        }
      ;;
    end

    let since_limit = ones Isa.data_bits

    let saturate since =
      let width = width since in
      mux2
        (since >: uresize since_limit ~width)
        since_limit
        (uresize since ~width:Isa.data_bits)
    ;;

    (* A pin's edge state after the word, [duration] or more cycles on, where out or mov
       data puts [data] on it: the cycles since its last edge count on, or restart where
       it moves. Its first write in a run sets it and is not counted as an edge. *)
    let edge_after (w : Watched.t) (e : _ Edge.t) ~data ~duration =
      let level = mux2 w.data data @@ mux2 w.written w.bit e.level in
      let changes = level <>: e.level in
      let counted = changes &: ~:(e.fresh) in
      (* as wide as a count and as the duration, whichever is wider *)
      let width = Int.max (width duration) (Isa.data_bits + 1) in
      ( changes
      , counted
      , { Edge.since =
            saturate
              (mux2 counted (zero width) (uresize e.since ~width)
               +: uresize duration ~width)
        ; level
        ; fresh = e.fresh &: ~:(w.written |: w.data)
        } )
    ;;

    (* A counted edge of [own] keeps the spacing its bit and [other]'s before it pick;
       [other] moving with it is no time apart. *)
    let spaced
      ~(spacing : _ Spaced.t)
      ~hold
      ~apart
      ~own
      ~own_counted
      ~other
      ~other_changes
      =
      let index = own.Edge.level @: other.Edge.level in
      let apart_by = mux2 other_changes (zero Isa.data_bits) other.since in
      ~:(spacing.valid)
      |: ~:own_counted
      |: (own.since >=: mux index hold &: (apart_by >=: mux index apart))
    ;;

    (* Both pins after the word, and whether each keeps its spacing. *)
    let edges
      ~side_set_count
      ~(spacing : _ Spaced.t)
      ~d
      ~(a : _ Edge.t)
      ~b
      ~data_a
      ~data_b
      ~duration
      =
      let v = spacing.value in
      let watched pin = Watched.of_word ~side_set_count ~spacing:v d ~pin in
      let a_changes, a_counted, next_a =
        edge_after (watched v.a) a ~data:data_a ~duration
      in
      let b_changes, b_counted, next_b =
        edge_after (watched v.b) b ~data:data_b ~duration
      in
      ( next_a
      , next_b
      , spaced
          ~spacing
          ~hold:v.hold_a
          ~apart:v.apart_a
          ~own:a
          ~own_counted:a_counted
          ~other:b
          ~other_changes:b_changes
      , spaced
          ~spacing
          ~hold:v.hold_b
          ~apart:v.apart_b
          ~own:b
          ~own_counted:b_counted
          ~other:a
          ~other_changes:a_changes )
    ;;

    (* Past this, a count of cycles since the arm is taken as lost, so it never wraps. *)
    let arm_limit = 1 lsl (timer_bits - 1)

    let step
      ~side_set_count
      ~fraction
      ~(loaded : _ With_valid.t)
      ~capture
      ~spacing
      ~word
      ~phase
      ~period
      ~x
      ~y
      ~arm
      ~arm_known
      ~captured
      ~awaiting
      ~a
      ~b
      ~data_a
      ~data_b
      =
      let c = Class.of_word ~side_set_count ~capture word in
      (* only the first wait for the edge since the arm sees it *)
      let capturing = c.capturing &: awaiting in
      let other_wait = c.pin_or_fifo_wait &: ~:capturing in
      let released = mux2 (msb phase) (zero timer_bits) phase in
      (* two bits wider, so the count, a stall and the cycles, each under the timer's
         range, cannot wrap *)
      let wide_arm =
        let wide x = uresize x ~width:(timer_bits + 2) in
        mux2 c.arm (wide c.cycles)
        @@ mux2 c.deadline (wide arm +: wide (released -: phase) +: wide c.cycles)
        @@ (wide arm +: wide c.cycles)
      in
      let next_arm = sel_bottom wide_arm ~width:timer_bits in
      (* the cycles to the next entry, at least *)
      let duration =
        let wide x = uresize x ~width:(timer_bits + 2) in
        mux2 c.deadline (wide (released -: phase) +: wide c.cycles) (wide c.cycles)
      in
      let next_a, next_b, wide_a, wide_b =
        edges ~side_set_count ~spacing ~d:c.decoded ~a ~b ~data_a ~data_b ~duration
      in
      let capture_bounded = c.from_capture &: captured &: arm_known in
      let next_phase =
        priority_select_with_default
          ~default:(phase +: c.cycles)
          [ { With_valid.valid = c.anchor; value = c.cycles }
          ; { valid = c.from_capture; value = arm +: c.cycles -:. 1 }
          ; { valid = c.advance; value = released +: c.cycles -: timer period }
          ; { valid = c.deadline; value = released +: c.cycles }
          ; { valid = c.add_imm; value = phase +: c.cycles -: c.imm }
          ; { valid = c.add_p; value = phase +: c.cycles -: timer period }
          ; { valid = c.add_x; value = phase +: c.cycles -: timer x }
          ; { valid = c.add_y; value = phase +: c.cycles -: timer y }
          ; { valid = c.sub_imm; value = phase +: c.cycles +: c.imm }
          ]
      in
      { Step.next_phase
      ; bounded = c.bounded
      ; may_carry = c.advance &: fraction
      ; next_period = mux2 c.set_p c.set_value @@ mux2 c.writes_p loaded.value period
      ; period_known = ~:(c.writes_p) |: loaded.valid
      ; next_x = mux2 c.set_x c.set_value @@ mux2 c.x_dec (x -:. 1) x
      ; x_known = ~:(c.writes_x)
      ; next_y = mux2 c.set_y c.set_value @@ mux2 c.y_dec (y -:. 1) y
      ; y_known = ~:(c.writes_y)
      ; taken =
          c.always
          |: (c.x_dec &: (x <>:. 0))
          |: (c.y_dec &: (y <>:. 0))
          |: (c.x_ne_y &: (x <>: y))
      ; taken_known = c.always |: c.x_dec |: c.y_dec |: c.x_ne_y
      ; next_arm
      ; next_arm_known = c.arm |: (arm_known &: ~:other_wait &: (wide_arm <:. arm_limit))
      ; next_captured = mux2 c.arm gnd (captured |: (capturing &: arm_known))
      ; next_awaiting = mux2 c.arm vdd (awaiting &: ~:(c.capturing))
      ; capture_bounded
      ; next_a
      ; next_b
      ; wide_a
      ; wide_b
      ; halts = c.halts
      }
    ;;

    (* two bits wider, so a bound that leaves the timer's range shows *)
    let wide_bits = timer_bits + 2
    let wide x = sresize x ~width:wide_bits
    let wide_data x = uresize x ~width:wide_bits

    (* wide enough again for an offset less a slope times what [set x] loads *)
    let offset_bits = wide_bits + Isa.Field.set_value.width
    let timer_min = of_signed_int ~width:wide_bits (-(1 lsl (timer_bits - 1)))
    let timer_max = of_signed_int ~width:wide_bits ((1 lsl (timer_bits - 1)) - 1)
    let data_max = ones Isa.data_bits

    let is_empty (r : _ Row.t) =
      r.phase_lo
      >+ r.phase_hi
      |: (r.period_lo >: r.period_hi)
      |: (r.x_lo >: r.x_hi)
      |: (r.y_lo >: r.y_hi)
      |: (r.arm_lo >: r.arm_hi)
    ;;

    let arm_is_full (r : _ Row.t) = r.arm_lo ==:. 0 &: (r.arm_hi ==: ones timer_bits)

    let is_full (r : _ Row.t) =
      wide r.phase_lo ==: timer_min &: (wide r.phase_hi ==: timer_max)
    ;;

    let offset_is_full (r : _ Row.t) =
      wide r.offset_lo ==: timer_min &: (wide r.offset_hi ==: timer_max)
    ;;

    let is_all lo hi = lo ==:. 0 &: (hi ==: data_max)

    (* An unsigned interval that a register's image must fall in, or [any] for a write the
       kernel does not follow. *)
    let contains ~lo ~hi ~any ~image_lo ~image_hi =
      mux2 any (is_all lo hi) (lo <=: image_lo &: (image_hi <=: hi))
    ;;

    (* A row bounds a pin at each bit it may hold by the least cycles since its last edge
       and by [mark], the least of those cycles less the phase, [t] less the edge's entry,
       which the phase's jitter leaves alone. [mark_none] bounds nothing; a mark above
       [mark_max] only a saturated count keeps. *)
    let mark_none = of_signed_int ~width:mark_bits (-(1 lsl (mark_bits - 1)))
    let mark_max = of_signed_int ~width:mark_bits ((1 lsl (timer_bits - 1)) + 0xffff)
    let mark_wide x = sresize x ~width:(mark_bits + 2)

    let clamp_mark x =
      mux2 (x <+ mark_wide mark_none) mark_none
      @@ mux2 (x >+ mark_wide mark_max) mark_max
      @@ sel_bottom x ~width:mark_bits
    ;;

    (* the least cycles since the last edge, at a phase of [phase_lo] or more *)
    let least_since (h : _ Held.t) ~phase_lo =
      let by_mark = mark_wide h.mark +: phase_lo in
      let by_mark =
        mux2 (by_mark <+ zero (width by_mark)) (zero Isa.data_bits) (saturate by_mark)
      in
      mux2 (by_mark >: h.since) by_mark h.since
    ;;

    (* The least of [cases] that apply, each a bound the pin may land in. *)
    let join_held cases =
      let applies (enable, (h : _ Held.t)) = enable &: h.may in
      let least ~lt ~top ~f =
        List.fold cases ~init:top ~f:(fun acc case ->
          let v = f (snd case) in
          mux2 (applies case &: lt v acc) v acc)
      in
      { Held.may = List.map cases ~f:applies |> reduce ~f:( |: )
      ; since = least ~lt:( <: ) ~top:since_limit ~f:(fun h -> h.since)
      ; mark = least ~lt:( <+ ) ~top:mark_max ~f:(fun h -> h.mark)
      }
    ;;

    (* A pin's bounds after the word: at the bit it keeps, the counts go on by the least
       [duration] and the mark by the least move of [t], if known; at the bit it moves to,
       they restart. Where the next phase is known to be [next_phase_hi] or less, the
       count less that bounds the mark too, so a mark lost to a wait comes back. *)
    let pin_image
      (w : Watched.t)
      (r : _ Pin.t)
      ~duration
      ~dt_lo
      ~dt_known
      ~phase_hi
      ~next_phase_hi
      =
      let kept (h : _ Held.t) =
        { h with
          since =
            (let width = Int.max (width duration) (Isa.data_bits + 1) in
             saturate (uresize h.since ~width +: uresize duration ~width))
        ; mark =
            mux2
              (dt_known &: (h.mark <>: mark_none))
              (clamp_mark (mark_wide h.mark +: dt_lo))
              mark_none
        }
      in
      (* a first write is no edge, so a pin not yet written counts on *)
      let moved (h : _ Held.t) =
        let kept = kept h in
        { h with
          since = mux2 r.fresh kept.since (saturate duration)
        ; mark =
            mux2 r.fresh kept.mark
            @@ mux2 dt_known (clamp_mark (dt_lo -: phase_hi)) mark_none
        }
      in
      let rederived (h : _ Held.t) =
        let by_since =
          clamp_mark (uresize h.since ~width:(mark_bits + 2) -: next_phase_hi)
        in
        { h with mark = mux2 (dt_known &: (by_since >+ h.mark)) by_since h.mark }
      in
      let keeps bit = w.data |: ~:(w.written) |: (w.bit ==: bit) in
      let moves bit = w.data |: (w.written &: (w.bit <>: bit)) in
      { Pin.at0 = rederived (join_held [ keeps gnd, kept r.at0; moves vdd, moved r.at1 ])
      ; at1 = rederived (join_held [ keeps vdd, kept r.at1; moves gnd, moved r.at0 ])
      ; fresh = r.fresh &: ~:(w.written |: w.data)
      }
    ;;

    (* Every counted edge [own] may make keeps the spacing at each pair of bits the two
       may hold before it. *)
    let row_spaced
      ~(spacing : _ Spaced.t)
      ~hold
      ~apart
      ~own_w
      ~own
      ~other_w
      ~other
      ~phase_lo
      =
      let ok own_bit other_bit =
        let held (p : _ Pin.t) bit = if bit then p.at1 else p.at0 in
        let h = held own own_bit in
        let g = held other other_bit in
        let moves (w : Watched.t) bit =
          w.data |: (w.written &: (w.bit <>: of_bool bit))
        in
        let i = (2 * Bool.to_int own_bit) + Bool.to_int other_bit in
        let hold = List.nth_exn hold i in
        let apart = List.nth_exn apart i in
        ~:(h.may &: moves own_w own_bit &: g.may)
        |: (least_since h ~phase_lo
            >=: hold
            &: mux2
                 (moves other_w other_bit)
                 (apart ==:. 0)
                 (least_since g ~phase_lo >=: apart))
      in
      ~:(spacing.valid)
      |: own.Pin.fresh
      |: (List.cartesian_product [ false; true ] [ false; true ]
          |> List.map ~f:(fun (own_bit, other_bit) -> ok own_bit other_bit)
          |> reduce ~f:( &: ))
    ;;

    (* The next phase from a phase in [lo, hi], and what the step adds to it. *)
    let phase_image ~fraction ~(c : Class.t) ~(row : _ Row.t) ~capture_bounded =
      let wide_arm x = uresize x ~width:wide_bits in
      let released x = mux2 (x <+ zero wide_bits) (zero wide_bits) x in
      let cycles = uresize c.cycles ~width:wide_bits in
      let imm = uresize c.imm ~width:wide_bits in
      let carry = uresize (c.advance &: fraction) ~width:wide_bits in
      let by_register ~p ~x ~y ~otherwise =
        mux2 (c.advance |: c.add_p) p @@ mux2 c.add_x x @@ mux2 c.add_y y @@ otherwise
      in
      (* what the step adds to the phase, on top of where it starts from *)
      let delta_lo, delta_hi =
        let fixed = mux2 c.add_imm imm @@ mux2 c.sub_imm (negate imm) (zero wide_bits) in
        let less_lo =
          by_register
            ~p:(wide_data row.period_hi +: carry)
            ~x:(wide_data row.x_hi)
            ~y:(wide_data row.y_hi)
            ~otherwise:fixed
        in
        let less_hi =
          by_register
            ~p:(wide_data row.period_lo)
            ~x:(wide_data row.x_lo)
            ~y:(wide_data row.y_lo)
            ~otherwise:fixed
        in
        cycles -: less_lo, cycles -: less_hi
      in
      (* the next phase, from a phase in [lo, hi] *)
      let image ~lo ~hi =
        let base_lo =
          mux2 c.anchor (zero wide_bits)
          @@ mux2 capture_bounded (one wide_bits)
          @@ mux2 c.deadline (released lo) lo
        in
        let base_hi =
          mux2 c.anchor (zero wide_bits)
          @@ mux2 capture_bounded (wide_arm row.arm_hi -:. 1)
          @@ mux2 c.deadline (released hi) hi
        in
        base_lo +: delta_lo, base_hi +: delta_hi
      in
      image, delta_lo, delta_hi
    ;;

    (* whether the next phase is bounded and does not wrap, and its upper end *)
    let phase_fits ~fraction ~(c : Class.t) ~(row : _ Row.t) ~capture_bounded =
      let image, _, _ = phase_image ~fraction ~c ~row ~capture_bounded in
      let image_lo, image_hi = image ~lo:(wide row.phase_lo) ~hi:(wide row.phase_hi) in
      c.bounded &: (image_lo >=+ timer_min) &: (image_hi <=+ timer_max), image_hi
    ;;

    (* Both pins' bounds after the word from the row's, and whether each keeps its
       spacing: the least duration is the cycles and a deadline wait's least stall, and
       [t] moves by the analyser's classes. A mark follows only where [phase_fits]: the
       next phase is bounded, by [image_hi] above, and does not wrap. *)
    let row_edges
      ~side_set_count
      ~(spacing : _ Spaced.t)
      ~(c : Class.t)
      ~(row : _ Row.t)
      ~phase_fits
      ~image_hi
      =
      let v = spacing.value in
      let hi = wide row.phase_hi in
      let stall = negate hi in
      let stall = mux2 (stall <+ zero wide_bits) (zero wide_bits) stall in
      let duration =
        uresize c.cycles ~width:wide_bits +: mux2 c.deadline stall (zero wide_bits)
      in
      let data x = uresize x ~width:(mark_bits + 2) in
      let phase_lo = mark_wide row.phase_lo in
      let dt_lo =
        mux2 c.anchor phase_lo
        @@ mux2 (c.advance |: c.add_p) (data row.period_lo)
        @@ mux2 c.add_x (data row.x_lo)
        @@ mux2 c.add_y (data row.y_lo)
        @@ mux2 c.add_imm (data c.imm)
        @@ mux2 c.sub_imm (negate (data c.imm)) (zero (mark_bits + 2))
      in
      let watched pin = Watched.of_word ~side_set_count ~spacing:v c.decoded ~pin in
      let wa = watched v.a in
      let wb = watched v.b in
      let image w r =
        pin_image
          w
          r
          ~duration
          ~dt_lo
          ~dt_known:phase_fits
          ~phase_hi:(mark_wide row.phase_hi)
          ~next_phase_hi:(mark_wide image_hi)
      in
      ( image wa row.a
      , image wb row.b
      , row_spaced
          ~spacing
          ~hold:v.hold_a
          ~apart:v.apart_a
          ~own_w:wa
          ~own:row.a
          ~other_w:wb
          ~other:row.b
          ~phase_lo
      , row_spaced
          ~spacing
          ~hold:v.hold_b
          ~apart:v.apart_b
          ~own_w:wb
          ~own:row.b
          ~other_w:wa
          ~other:row.a
          ~phase_lo )
    ;;

    (* the pair's bounds after the word, as [conjuncts] makes them, for [Table.with_edges] *)
    let edge_images ~side_set_count ~fraction ~capture ~spacing ~word ~(row : _ Row.t) =
      let c = Class.of_word ~side_set_count ~capture word in
      let capture_bounded = c.from_capture &: row.captured &: ~:(arm_is_full row) in
      let fits, image_hi = phase_fits ~fraction ~c ~row ~capture_bounded in
      let a, b, _, _ =
        row_edges ~side_set_count ~spacing ~c ~row ~phase_fits:fits ~image_hi
      in
      a, b
    ;;

    (* A row's bounds hold of the bounds [image], bit by bit. *)
    let pin_holds (s : _ Pin.t) (image : _ Pin.t) =
      let held (s : _ Held.t) (i : _ Held.t) =
        ~:(i.may) |: (s.may &: (s.since <=: i.since) &: (s.mark <=+ i.mark))
      in
      held s.at0 image.at0 &: held s.at1 image.at1 &: (~:(s.fresh) |: image.fresh)
    ;;

    (* The core's edge state inside a row's bounds, at a phase of [phase]; a saturated
       count keeps any mark. *)
    let pin_within (r : _ Pin.t) (e : _ Edge.t) ~phase =
      let inside (h : _ Held.t) =
        h.may
        &: (h.since <=: e.since)
        &: (e.since
            ==: since_limit
            |: (uresize e.since ~width:(mark_bits + 2) -: mark_wide phase
                >=+ mark_wide h.mark))
      in
      mux2 e.level (inside r.at1) (inside r.at0) &: (~:(r.fresh) |: e.fresh)
    ;;

    let conjuncts
      ~side_set_count
      ~fraction
      ~(loaded : _ With_valid.t)
      ~capture
      ~spacing
      ~word
      ~(row : _ Row.t)
      ~(next : _ Row.t)
      ~target
      =
      let c = Class.of_word ~side_set_count ~capture word in
      let arm_known = ~:(arm_is_full row) in
      let capturing = c.capturing &: row.awaiting in
      let other_wait = c.pin_or_fifo_wait &: ~:capturing in
      let capture_bounded = c.from_capture &: row.captured &: arm_known in
      let wide_arm x = uresize x ~width:wide_bits in
      let lo = wide row.phase_lo in
      let hi = wide row.phase_hi in
      let released x = mux2 (x <+ zero wide_bits) (zero wide_bits) x in
      let cycles = uresize c.cycles ~width:wide_bits in
      let image, delta_lo, delta_hi = phase_image ~fraction ~c ~row ~capture_bounded in
      let image_lo, image_hi = image ~lo ~hi in
      let offset_lo = wide row.offset_lo in
      let offset_hi = wide row.offset_hi in
      (* falling through [jmp x--] leaves x = 0, where the phase lies in the offset too *)
      let fallen_lo, fallen_hi =
        image
          ~lo:(mux2 (lo >+ offset_lo) lo offset_lo)
          ~hi:(mux2 (hi <+ offset_hi) hi offset_hi)
      in
      (* the cycles since the arm; a deadline wait adds its stall, a capturing wait not *)
      let arm_lo, arm_hi =
        let from ~stall a =
          mux2 c.arm cycles
          @@ mux2 c.deadline (wide_arm a +: stall +: cycles) (wide_arm a +: cycles)
        in
        ( from ~stall:(released (negate hi)) row.arm_lo
        , from ~stall:(released (negate lo)) row.arm_hi )
      in
      let arm_image_known =
        c.arm |: (arm_known &: ~:other_wait &: (arm_hi <:. arm_limit))
      in
      let edge_a, edge_b, wide_a, wide_b =
        row_edges
          ~side_set_count
          ~spacing
          ~c
          ~row
          ~phase_fits:(c.bounded &: (image_lo >=+ timer_min) &: (image_hi <=+ timer_max))
          ~image_hi
      in
      let captured_image = mux2 c.arm gnd (row.captured |: (capturing &: arm_known)) in
      let awaiting_image = mux2 c.arm vdd (row.awaiting &: ~:(c.capturing)) in
      let period_image v = mux2 c.set_p c.set_value @@ mux2 c.writes_p loaded.value v in
      let common_lo = mux2 (row.x_lo >: row.y_lo) row.x_lo row.y_lo in
      let common_hi = mux2 (row.x_hi <: row.y_hi) row.x_hi row.y_hi in
      (* a register's image on one way out: a counted jump decrements it on both, and
         falling through [jmp x!=y] leaves x = y, so each lies in both intervals *)
      let counter ~set ~dec ~(taken : bool) lo hi =
        let taken_lo = mux2 (lo ==:. 0) (zero Isa.data_bits) (lo -:. 1) in
        let dec_lo, dec_hi = if taken then taken_lo, hi -:. 1 else data_max, data_max in
        let kept_lo, kept_hi =
          if taken then lo, hi else mux2 c.x_ne_y common_lo lo, mux2 c.x_ne_y common_hi hi
        in
        ( mux2 set c.set_value @@ mux2 dec dec_lo kept_lo
        , mux2 set c.set_value @@ mux2 dec dec_hi kept_hi )
      in
      let phase_known = c.bounded |: capture_bounded in
      (* a step that adds to the phase moves the offset by as much *)
      let adds = c.bounded &: ~:(c.anchor) &: ~:(c.deadline) in
      let moved_lo = offset_lo +: delta_lo in
      let moved_hi = offset_hi +: delta_hi in
      let small_value =
        uresize
          (sel_bottom c.set_value ~width:Isa.Field.set_value.width)
          ~width:(Isa.Field.set_value.width + 1)
      in
      let holds ~taken (s : _ Row.t) =
        let x_lo, x_hi = counter ~set:c.set_x ~dec:c.x_dec ~taken row.x_lo row.x_hi in
        let y_lo, y_hi = counter ~set:c.set_y ~dec:c.y_dec ~taken row.y_lo row.y_hi in
        let image_lo, image_hi =
          if taken
          then image_lo, image_hi
          else mux2 c.x_dec fallen_lo image_lo, mux2 c.x_dec fallen_hi image_hi
        in
        let fits = image_lo >=+ timer_min &: (image_hi <=+ timer_max) in
        (* The offset's image, where [s.slope * x] is known on this way out: after
           [set x], from the phase's image; with the slope the same and x the same, or one
           less on the way a counted jump takes, from this row's offset. *)
        let offset_known, offset_image_lo, offset_image_hi =
          let wider x = sresize x ~width:offset_bits in
          let product = wider (s.slope *+ small_value) in
          let counted moved =
            if taken then mux2 c.x_dec (moved +: wide row.slope) moved else moved
          in
          let follows_x = if taken then ~:(c.writes_x) else ~:(c.writes_x |: c.x_dec) in
          ( mux2 c.set_x phase_known (adds &: follows_x &: (s.slope ==: row.slope))
          , mux2 c.set_x (wider image_lo -: product) (wider (counted moved_lo))
          , mux2 c.set_x (wider image_hi -: product) (wider (counted moved_hi)) )
        in
        { Holds.phase =
            is_full s
            |: (phase_known
                &: fits
                &: (wide s.phase_lo <=+ image_lo)
                &: (image_hi <=+ wide s.phase_hi))
        ; offset =
            offset_is_full s
            |: (offset_known
                &: (sresize s.offset_lo ~width:offset_bits <=+ offset_image_lo)
                &: (offset_image_hi <=+ sresize s.offset_hi ~width:offset_bits))
        ; period =
            contains
              ~lo:s.period_lo
              ~hi:s.period_hi
              ~any:(c.writes_p &: ~:(loaded.valid))
              ~image_lo:(period_image row.period_lo)
              ~image_hi:(period_image row.period_hi)
        ; x = contains ~lo:s.x_lo ~hi:s.x_hi ~any:c.writes_x ~image_lo:x_lo ~image_hi:x_hi
        ; y = contains ~lo:s.y_lo ~hi:s.y_hi ~any:c.writes_y ~image_lo:y_lo ~image_hi:y_hi
        ; arm =
            arm_is_full s
            |: (arm_image_known
                &: (wide_arm s.arm_lo <=: arm_lo)
                &: (arm_hi <=: wide_arm s.arm_hi))
        ; captured = ~:(s.captured) |: captured_image
        ; awaiting = ~:(s.awaiting) |: awaiting_image
        ; edge_a = ~:(spacing.valid) |: pin_holds s.a edge_a
        ; edge_b = ~:(spacing.valid) |: pin_holds s.b edge_b
        }
      in
      let singleton lo hi = lo ==: hi in
      let may_take =
        mux2 c.always vdd
        @@ mux2 c.x_dec (row.x_hi <>:. 0)
        @@ mux2 c.y_dec (row.y_hi <>:. 0)
        @@ mux2
             c.x_ne_y
             ~:(singleton row.x_lo row.x_hi
                &: singleton row.y_lo row.y_hi
                &: (row.x_lo ==: row.y_lo))
             vdd
      in
      let may_fall =
        mux2 c.always gnd
        @@ mux2 c.x_dec (row.x_lo ==:. 0)
        @@ mux2 c.y_dec (row.y_lo ==:. 0)
        @@ mux2 c.x_ne_y (row.x_lo <=: row.y_hi &: (row.y_lo <=: row.x_hi)) vdd
      in
      (* an empty row or a halt asks nothing; each conjunct holds or does not apply *)
      let asks = ~:(is_empty row) &: ~:(c.halts) in
      let only_if needed holds = Holds.map holds ~f:(fun h -> ~:needed |: h) in
      (* a halt's side-set moves the pins too *)
      { Conjuncts.in_time = ~:asks |: ~:(c.deadline) |: (row.phase_hi <=+ zero timer_bits)
      ; wide_a = is_empty row |: wide_a
      ; wide_b = is_empty row |: wide_b
      ; next = only_if (asks &: (~:(c.jump) |: may_fall)) (holds ~taken:false next)
      ; target = only_if (asks &: c.jump &: may_take) (holds ~taken:true target)
      }
    ;;

    let accepts
      ~side_set_count
      ~fraction
      ~loaded
      ~capture
      ~spacing
      ~word
      ~row
      ~next
      ~target
      =
      conjuncts
        ~side_set_count
        ~fraction
        ~loaded
        ~capture
        ~spacing
        ~word
        ~row
        ~next
        ~target
      |> Conjuncts.to_list
      |> reduce ~f:( &: )
    ;;

    let following ~wrap_top ~wrap_bottom pc = mux2 (pc ==: wrap_top) wrap_bottom (pc +:. 1)

    let successors ~wrap_top ~wrap_bottom ~pc ~word =
      ( following ~wrap_top ~wrap_bottom pc
      , Isa.Field.select (module Comb) Isa.Field.jmp_target word )
    ;;

    let within
      (r : _ Row.t)
      ~(spacing : _ Spaced.t)
      ~phase
      ~offset
      ~period
      ~x
      ~y
      ~arm
      ~arm_known
      ~captured
      ~awaiting
      ~a
      ~b
      =
      let inside lo hi v = lo <=: v &: (v <=: hi) in
      { Holds.phase = r.phase_lo <=+ phase &: (phase <=+ r.phase_hi)
      ; offset = r.offset_lo <=+ offset &: (offset <=+ r.offset_hi)
      ; period = inside r.period_lo r.period_hi period
      ; x = inside r.x_lo r.x_hi x
      ; y = inside r.y_lo r.y_hi y
      ; arm = arm_is_full r |: (arm_known &: inside r.arm_lo r.arm_hi arm)
      ; captured = ~:(r.captured) |: captured
      ; awaiting = ~:(r.awaiting) |: awaiting
      ; edge_a = ~:(spacing.valid) |: pin_within r.a a ~phase
      ; edge_b = ~:(spacing.valid) |: pin_within r.b b ~phase
      }
    ;;

    let no_spacing =
      let module Spaced = Spaced.Make_comb (Comb) in
      Spaced.zero ()
    ;;

    let starting ~level = { Edge.since = since_limit; level; fresh = vdd }

    let starts_open (r : _ Row.t) ~(spacing : _ Spaced.t) =
      let edges_open =
        r.a.at0.may &: r.a.at1.may &: r.b.at0.may &: r.b.at1.may |: ~:(spacing.valid)
      in
      is_full r
      &: offset_is_full r
      &: is_all r.period_lo r.period_hi
      &: is_all r.x_lo r.x_hi
      &: is_all r.y_lo r.y_hi
      &: arm_is_full r
      &: ~:(r.captured)
      &: ~:(r.awaiting)
      &: edges_open
    ;;
  end

  module K = Make (Bits)

  module Table = struct
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
      (* an open end is the whole range, since the timer wraps *)
      let phase_lo, phase_hi =
        match phase.lo, phase.hi with
        | Some lo, Some hi -> lo, hi
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

    (* after this many joins at a pc, its marks bound nothing, so a mark that falls round
       a loop cannot keep it going *)
    let widen_after = 64

    let with_edges
      ?(single_capture_edge = false)
      (table : t)
      ~(config : Program_config.t)
      ~spacing
      ~words
      =
      let size = Array.length table in
      let words = Array.of_list words in
      let word pc =
        Bits.of_unsigned_int
          ~width:Isa.data_bits
          (if pc < Array.length words then words.(pc) else 0)
      in
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
      let state = Array.create ~len:size None in
      let joins = Array.create ~len:size 0 in
      let starting =
        let held = { Held.may = Bits.vdd; since = K.since_limit; mark = K.mark_max } in
        { Pin.at0 = held; at1 = held; fresh = Bits.vdd }
      in
      state.(0) <- Some (starting, starting);
      let queue = Queue.of_list [ 0 ] in
      while not (Queue.is_empty queue) do
        let pc = Queue.dequeue_exn queue in
        match state.(pc) with
        | None -> ()
        | Some (a, b) when reached pc ->
          let w = word pc in
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
          List.iter successors ~f:(fun next ->
            let joined =
              match state.(next) with
              | None -> join a a, join b b
              | Some (a', b') -> join a a', join b b'
            in
            let joined =
              if joins.(next) < widen_after
              then joined
              else (
                let widen (p : _ Pin.t) =
                  let held (h : _ Held.t) = { h with mark = K.mark_none } in
                  { p with at0 = held p.at0; at1 = held p.at1 }
                in
                widen (fst joined), widen (snd joined))
            in
            if not
                 ([%equal: (Bits.t Pin.t * Bits.t Pin.t) option]
                    (Some joined)
                    state.(next))
            then (
              joins.(next) <- joins.(next) + 1;
              state.(next) <- Some joined;
              Queue.enqueue queue next))
        | Some _ -> ()
      done;
      Array.mapi table ~f:(fun pc row ->
        match state.(pc) with
        | Some (a, b) when reached pc -> { row with a; b }
        | _ -> row)
    ;;
  end

  module Rejection = struct
    type t =
      { pc : int
      ; fails : string list
      }
    [@@deriving sexp_of]
  end

  (* Whether the row at pc 0 starts open, and the pcs whose conjuncts fail. *)
  let verdicts
    ?period
    ?(single_capture_edge = false)
    ?spacing:spec
    ~(config : Program_config.t)
    ~words
    (table : Table.t)
    =
    let size = 1 lsl Isa.pc_bits in
    let words = Array.of_list words in
    let word pc =
      Bits.of_unsigned_int
        ~width:Isa.data_bits
        (if pc < Array.length words then words.(pc) else 0)
    in
    let side_set_count = Bits.of_unsigned_int ~width:2 config.side_set_count in
    let fraction = Bits.of_bool (config.period_fraction <> 0) in
    let loaded =
      { With_valid.valid = Bits.of_bool (Option.is_some period)
      ; value = Bits.of_unsigned_int ~width:Isa.data_bits (Option.value period ~default:0)
      }
    in
    let capture =
      { Capture.pin =
          Bits.of_unsigned_int ~width:Isa.Field.wait_index.width config.capture_pin
      ; rising = Bits.of_bool config.capture_rising
      ; single_edge = Bits.of_bool single_capture_edge
      }
    in
    let spacing =
      Option.value_map spec ~default:K.no_spacing ~f:(fun spec ->
        { With_valid.valid = Bits.vdd; value = Spacing.of_spec config spec })
    in
    let starts_open = Bits.to_bool (K.starts_open table.(0) ~spacing) in
    let pc_bits n = Bits.of_unsigned_int ~width:Isa.pc_bits n in
    let wrap_top = pc_bits config.wrap_top in
    let wrap_bottom = pc_bits config.wrap_bottom in
    let names =
      let way name = Holds.map Holds.port_names ~f:(fun field -> name ^ " " ^ field) in
      { Conjuncts.in_time = "in time"
      ; wide_a = "a spaced"
      ; wide_b = "b spaced"
      ; next = way "next"
      ; target = way "target"
      }
    in
    let rejected =
      List.filter_map (List.range 0 size) ~f:(fun pc ->
        let w = word pc in
        let next, target = K.successors ~wrap_top ~wrap_bottom ~pc:(pc_bits pc) ~word:w in
        let row pc = table.(Bits.to_unsigned_int pc) in
        let conjuncts =
          K.conjuncts
            ~side_set_count
            ~fraction
            ~loaded
            ~capture
            ~spacing
            ~word:w
            ~row:table.(pc)
            ~next:(row next)
            ~target:(row target)
        in
        let fails =
          List.filter_map
            (Conjuncts.to_list (Conjuncts.zip names conjuncts))
            ~f:(fun (name, holds) -> Option.some_if (not (Bits.to_bool holds)) name)
        in
        Option.some_if (not (List.is_empty fails)) { Rejection.pc; fails })
    in
    starts_open, rejected
  ;;

  let rejections ?period ?single_capture_edge ?spacing ~config ~words table =
    snd (verdicts ?period ?single_capture_edge ?spacing ~config ~words table)
  ;;

  let check
    ?period
    ?single_capture_edge
    ?spacing:spec
    ~(config : Program_config.t)
    ~words
    (table : Table.t)
    =
    let starts_open, rejected =
      verdicts ?period ?single_capture_edge ?spacing:spec ~config ~words table
    in
    (* what formal/phase_spacing.sby proves the spacing for *)
    let proved_spacing =
      Option.for_all spec ~f:(fun { a; b; _ } ->
        a <> b
        && a < Isa.pin_space
        && b < Isa.pin_space
        && (not config.manchester)
        && Array.for_all table ~f:(fun r ->
          Bits.to_bool Bits.(K.offset_is_full r &: (r.slope ==:. 0))))
    in
    match starts_open, rejected with
    | _ when not proved_spacing ->
      Or_error.error_s
        [%message
          "edges are spaced only for two pins, Manchester off and a table of intervals"]
    | true, [] -> Ok ()
    | false, _ -> Or_error.error_s [%message "the row at pc 0 must be the full range"]
    | true, rejected ->
      Or_error.error_s [%message "rows the kernel rejects" (rejected : Rejection.t list)]
  ;;

  module I = struct
    type 'a t =
      { side_set_count : 'a [@bits 2]
      ; fraction : 'a
      ; loaded : 'a With_valid.t [@bits Isa.data_bits]
      ; capture : 'a Capture.t
      ; spacing : 'a Spaced.t
      ; word : 'a [@bits Isa.data_bits]
      ; phase : 'a [@bits timer_bits]
      ; period : 'a [@bits Isa.data_bits]
      ; x : 'a [@bits Isa.data_bits]
      ; y : 'a [@bits Isa.data_bits]
      ; arm : 'a [@bits timer_bits]
      ; arm_known : 'a
      ; captured : 'a
      ; awaiting : 'a
      ; a : 'a Edge.t
      ; b : 'a Edge.t
      ; data_a : 'a
      ; data_b : 'a
      }
    [@@deriving hardcaml]
  end

  module O = Step

  let create (_scope : Scope.t) (i : Signal.t I.t) =
    let module K = Make (Signal) in
    K.step
      ~side_set_count:i.side_set_count
      ~fraction:i.fraction
      ~loaded:i.loaded
      ~capture:i.capture
      ~spacing:i.spacing
      ~word:i.word
      ~phase:i.phase
      ~period:i.period
      ~x:i.x
      ~y:i.y
      ~arm:i.arm
      ~arm_known:i.arm_known
      ~captured:i.captured
      ~awaiting:i.awaiting
      ~a:i.a
      ~b:i.b
      ~data_a:i.data_a
      ~data_b:i.data_b
  ;;

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"kernel_step" create i
  ;;

  module Accepts = struct
    module I = struct
      type 'a t =
        { side_set_count : 'a [@bits 2]
        ; fraction : 'a
        ; loaded : 'a With_valid.t [@bits Isa.data_bits]
        ; capture : 'a Capture.t
        ; spacing : 'a Spaced.t
        ; wrap_top : 'a [@bits Isa.pc_bits]
        ; wrap_bottom : 'a [@bits Isa.pc_bits]
        ; pc : 'a [@bits Isa.pc_bits]
        ; word : 'a [@bits Isa.data_bits]
        ; row : 'a [@bits Row.sum_of_port_widths]
        ; next : 'a [@bits Row.sum_of_port_widths]
        ; target : 'a [@bits Row.sum_of_port_widths]
        ; phase : 'a [@bits timer_bits]
        ; offset : 'a [@bits timer_bits]
        ; period : 'a [@bits Isa.data_bits]
        ; x : 'a [@bits Isa.data_bits]
        ; y : 'a [@bits Isa.data_bits]
        ; arm : 'a [@bits timer_bits]
        ; arm_known : 'a
        ; captured : 'a
        ; awaiting : 'a
        ; a : 'a Edge.t
        ; b : 'a Edge.t
        }
      [@@deriving hardcaml]
    end

    module O = struct
      type 'a t =
        { next_pc : 'a [@bits Isa.pc_bits]
        ; target_pc : 'a [@bits Isa.pc_bits]
        ; accepts : 'a
        ; within : 'a
        ; starts_open : 'a
        }
      [@@deriving hardcaml]
    end

    let create (_scope : Scope.t) (i : Signal.t I.t) =
      let module K = Make (Signal) in
      let row = Row.Of_signal.unpack ~rev:true i.row in
      let next_pc, target_pc =
        K.successors ~wrap_top:i.wrap_top ~wrap_bottom:i.wrap_bottom ~pc:i.pc ~word:i.word
      in
      { O.next_pc
      ; target_pc
      ; accepts =
          K.accepts
            ~side_set_count:i.side_set_count
            ~fraction:i.fraction
            ~loaded:i.loaded
            ~capture:i.capture
            ~spacing:i.spacing
            ~word:i.word
            ~row
            ~next:(Row.Of_signal.unpack ~rev:true i.next)
            ~target:(Row.Of_signal.unpack ~rev:true i.target)
      ; within =
          K.within
            row
            ~spacing:i.spacing
            ~phase:i.phase
            ~offset:i.offset
            ~period:i.period
            ~x:i.x
            ~y:i.y
            ~arm:i.arm
            ~arm_known:i.arm_known
            ~captured:i.captured
            ~awaiting:i.awaiting
            ~a:i.a
            ~b:i.b
          |> Holds.to_list
          |> Signal.reduce ~f:Signal.( &: )
      ; starts_open = K.starts_open row ~spacing:i.spacing
      }
    ;;

    let hierarchical ?instance scope i =
      let module H = Hierarchy.In_scope (I) (O) in
      H.hierarchical ?instance ~scope ~name:"kernel_accepts" create i
    ;;
  end
end

include Make_timer (Isa)
