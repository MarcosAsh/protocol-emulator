open! Core
open! Hardcaml
open Kernel_types

module Make_timer (Timer : Engine.Timer) = struct
  open Kernel_types.Make_timer (Timer)
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

      let map t ~f =
        { cycles = f t.cycles
        ; deadline = f t.deadline
        ; advance = f t.advance
        ; anchor = f t.anchor
        ; add_imm = f t.add_imm
        ; add_p = f t.add_p
        ; add_x = f t.add_x
        ; add_y = f t.add_y
        ; sub_imm = f t.sub_imm
        ; imm = f t.imm
        ; bounded = f t.bounded
        ; jump = f t.jump
        ; always = f t.always
        ; x_dec = f t.x_dec
        ; y_dec = f t.y_dec
        ; x_ne_y = f t.x_ne_y
        ; halts = f t.halts
        ; set_value = f t.set_value
        ; set_p = f t.set_p
        ; writes_p = f t.writes_p
        ; set_x = f t.set_x
        ; writes_x = f t.writes_x
        ; set_y = f t.set_y
        ; writes_y = f t.writes_y
        ; arm = f t.arm
        ; capturing = f t.capturing
        ; pin_or_fifo_wait = f t.pin_or_fifo_wait
        ; from_capture = f t.from_capture
        ; decoded = Decoded.map t.decoded ~f
        }
      ;;
    end

    (* Whether [pin] is in the run of [count] pins from [base], wrapping at the pin space
       as [Pins.write] does, and the bit of [value] it takes there. The pin space is all
       of a pin's five bits, so the offset wraps with it. *)
    let in_run ~pin ~base ~count ~value =
      let six x = uresize x ~width:6 in
      let offset = six (pin -: base) in
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
            (pin >=:. Isa.first_output_pin &: (pin <:. Isa.first_status_pin))
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
      ~(loaded : _ Loaded.t)
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
      ; period_known = ~:(c.writes_p) |: (loaded.valid &: ~:(loaded.floor))
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
  end

  module I = struct
    type 'a t =
      { side_set_count : 'a [@bits 2]
      ; fraction : 'a
      ; loaded : 'a Loaded.t
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
end
