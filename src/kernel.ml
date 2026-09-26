open! Core
open! Hardcaml

module Row = struct
  type 'a t =
    { phase_lo : 'a [@bits Isa.timer_bits]
    ; phase_hi : 'a [@bits Isa.timer_bits]
    ; period_lo : 'a [@bits Isa.data_bits]
    ; period_hi : 'a [@bits Isa.data_bits]
    }
  [@@deriving hardcaml]
end

module Step = struct
  type 'a t =
    { next_phase : 'a [@bits Isa.timer_bits]
    ; bounded : 'a
    ; may_carry : 'a
    ; next_period : 'a [@bits Isa.data_bits]
    ; period_known : 'a
    ; halts : 'a
    }
  [@@deriving hardcaml]
end

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

  let timer x = uresize x ~width:Isa.timer_bits

  (* the classes the analyser's transfer function tells apart *)
  module Class = struct
    type t =
      { cycles : Comb.t
      ; deadline : Comb.t
      ; advance : Comb.t
      ; anchor : Comb.t (** [mov t, now] *)
      ; add_imm : Comb.t
      ; add_p : Comb.t
      ; sub_imm : Comb.t
      ; imm : Comb.t
      ; bounded : Comb.t
      ; jump : Comb.t
      ; always : Comb.t (** a jump that cannot fall through *)
      ; halts : Comb.t
      ; set_p : Comb.t
      ; set_value : Comb.t
      ; writes_p : Comb.t
      }

    let of_word ~side_set_count word =
      let d = Decoder.decode ~side_set_count word in
      let is op = Opcode.is d.opcode op in
      let jump = is Jmp in
      let deadline = is Wait &: Wait_source.is d.wait_source Deadline in
      let alu_t = is Alu &: Alu_dest.is d.alu_dest T in
      let add = Alu_op.is d.alu_op Add in
      let add_imm = alu_t &: add &: ~:(d.alu_is_reg) in
      let add_p = alu_t &: add &: d.alu_is_reg &: Alu_reg.is d.alu_reg P in
      let sub_imm = alu_t &: Alu_op.is d.alu_op Sub &: ~:(d.alu_is_reg) in
      let mov_t = is Mov &: Mov_dest.is d.mov_dest T in
      let anchor = mov_t &: Mov_op.is d.mov_op Copy &: Mov_source.is d.mov_source Now in
      let unbounded =
        is Wait
        &: ~:deadline
        |: (mov_t &: ~:anchor)
        |: (is Out &: Out_dest.is d.out_dest T)
        |: (alu_t &: ~:(add_imm |: add_p |: sub_imm))
      in
      { cycles =
          mux2 jump (of_unsigned_int ~width:Isa.timer_bits Isa.jmp_cycles)
          @@ (timer d.delay +:. 1)
      ; deadline
      ; advance = deadline &: d.wait_polarity
      ; anchor
      ; add_imm
      ; add_p
      ; sub_imm
      ; imm = timer d.alu_imm
      ; bounded = ~:unbounded
      ; jump
      ; always = jump &: Jmp_cond.is d.jmp_cond Always
      ; halts = ~:(d.valid) |: (is Sys &: Sys_op.is d.sys_op Halt)
      ; set_p = is Set &: Set_dest.is d.set_dest P
      ; set_value = uresize d.set_value ~width:Isa.data_bits
      ; writes_p =
          is Mov
          &: Mov_dest.is d.mov_dest P
          |: (is Out &: Out_dest.is d.out_dest P)
          |: (is Alu &: Alu_dest.is d.alu_dest P)
      }
    ;;
  end

  let step ~side_set_count ~fraction ~word ~phase ~period =
    let c = Class.of_word ~side_set_count word in
    let released = mux2 (msb phase) (zero Isa.timer_bits) phase in
    let next_phase =
      priority_select_with_default
        ~default:(phase +: c.cycles)
        [ { With_valid.valid = c.anchor; value = c.cycles }
        ; { valid = c.advance; value = released +: c.cycles -: timer period }
        ; { valid = c.deadline; value = released +: c.cycles }
        ; { valid = c.add_imm; value = phase +: c.cycles -: c.imm }
        ; { valid = c.add_p; value = phase +: c.cycles -: timer period }
        ; { valid = c.sub_imm; value = phase +: c.cycles +: c.imm }
        ]
    in
    { Step.next_phase
    ; bounded = c.bounded
    ; may_carry = c.advance &: fraction
    ; next_period = mux2 c.set_p c.set_value period
    ; period_known = ~:(c.writes_p)
    ; halts = c.halts
    }
  ;;

  (* two bits wider, so a bound that leaves the timer's range shows *)
  let wide_bits = Isa.timer_bits + 2
  let wide x = sresize x ~width:wide_bits
  let wide_period x = uresize x ~width:wide_bits
  let timer_min = of_signed_int ~width:wide_bits (-(1 lsl (Isa.timer_bits - 1)))
  let timer_max = of_signed_int ~width:wide_bits ((1 lsl (Isa.timer_bits - 1)) - 1)
  let is_empty (r : _ Row.t) = r.phase_lo >+ r.phase_hi |: (r.period_lo >: r.period_hi)

  let is_full (r : _ Row.t) =
    wide r.phase_lo ==: timer_min &: (wide r.phase_hi ==: timer_max)
  ;;

  let accepts ~side_set_count ~fraction ~word ~(row : _ Row.t) ~(next : _ Row.t) ~target =
    let c = Class.of_word ~side_set_count word in
    let lo = wide row.phase_lo in
    let hi = wide row.phase_hi in
    let released x = mux2 (x <+ zero wide_bits) (zero wide_bits) x in
    let cycles = uresize c.cycles ~width:wide_bits in
    let imm = uresize c.imm ~width:wide_bits in
    let p_lo = wide_period row.period_lo in
    let p_hi = wide_period row.period_hi in
    let carry = uresize (c.advance &: fraction) ~width:wide_bits in
    let image_lo, image_hi =
      let base_lo = mux2 c.anchor (zero wide_bits) @@ mux2 c.deadline (released lo) lo in
      let base_hi = mux2 c.anchor (zero wide_bits) @@ mux2 c.deadline (released hi) hi in
      let less_lo =
        mux2 (c.advance |: c.add_p) (p_hi +: carry)
        @@ mux2 c.add_imm imm
        @@ mux2 c.sub_imm (negate imm) (zero wide_bits)
      in
      let less_hi =
        mux2 (c.advance |: c.add_p) p_lo
        @@ mux2 c.add_imm imm
        @@ mux2 c.sub_imm (negate imm) (zero wide_bits)
      in
      base_lo +: cycles -: less_lo, base_hi +: cycles -: less_hi
    in
    let fits = image_lo >=+ timer_min &: (image_hi <=+ timer_max) in
    let period_lo = mux2 c.set_p c.set_value row.period_lo in
    let period_hi = mux2 c.set_p c.set_value row.period_hi in
    let holds (s : _ Row.t) =
      let phase =
        is_full s
        |: (c.bounded
            &: fits
            &: (wide s.phase_lo <=+ image_lo)
            &: (image_hi <=+ wide s.phase_hi))
      in
      let period =
        mux2
          c.writes_p
          (s.period_lo ==:. 0 &: (s.period_hi ==: ones Isa.data_bits))
          (s.period_lo <=: period_lo &: (period_hi <=: s.period_hi))
      in
      phase &: period
    in
    let in_time = ~:(c.deadline) |: (row.phase_hi <=+ zero Isa.timer_bits) in
    is_empty row
    |: c.halts
    |: (in_time &: (c.always |: holds next) &: (~:(c.jump) |: holds target))
  ;;

  let following ~wrap_top ~wrap_bottom pc = mux2 (pc ==: wrap_top) wrap_bottom (pc +:. 1)
end

module Table = struct
  type t = Bits.t Row.t array

  let full_phase = Interval.top

  let row ~(phase : Interval.t) ~(period : Interval.t) =
    let signed n = Bits.of_signed_int ~width:Isa.timer_bits n in
    let unsigned n = Bits.of_unsigned_int ~width:Isa.data_bits n in
    let half = 1 lsl (Isa.timer_bits - 1) in
    (* an open end is the whole range, since the timer wraps *)
    let phase_lo, phase_hi =
      match phase.lo, phase.hi with
      | Some lo, Some hi -> lo, hi
      | _ -> -half, half - 1
    in
    { Row.phase_lo = signed phase_lo
    ; phase_hi = signed phase_hi
    ; period_lo = unsigned (Option.value period.lo ~default:0)
    ; period_hi = unsigned (Option.value period.hi ~default:((1 lsl Isa.data_bits) - 1))
    }
  ;;

  let unreached =
    { Row.phase_lo = Bits.of_signed_int ~width:Isa.timer_bits 1
    ; phase_hi = Bits.zero Isa.timer_bits
    ; period_lo = Bits.zero Isa.data_bits
    ; period_hi = Bits.zero Isa.data_bits
    }
  ;;

  let of_analyser (rows : Analyser.Row.t list) =
    let table = Array.create ~len:(1 lsl Isa.pc_bits) unreached in
    List.iter rows ~f:(fun r -> table.(r.pc) <- row ~phase:r.phase ~period:r.period);
    table.(0) <- row ~phase:full_phase ~period:Interval.top;
    table
  ;;
end

module K = Make (Bits)

let check ~(config : Program_config.t) ~words (table : Table.t) =
  let size = 1 lsl Isa.pc_bits in
  let words = Array.of_list words in
  let word pc =
    Bits.of_unsigned_int
      ~width:Isa.data_bits
      (if pc < Array.length words then words.(pc) else 0)
  in
  let side_set_count = Bits.of_unsigned_int ~width:2 config.side_set_count in
  let fraction = Bits.of_bool (config.period_fraction <> 0) in
  let starts_open =
    Bits.to_bool (K.is_full table.(0))
    && Bits.to_unsigned_int table.(0).period_lo = 0
    && Bits.to_unsigned_int table.(0).period_hi = (1 lsl Isa.data_bits) - 1
  in
  let following pc =
    if pc = config.wrap_top then config.wrap_bottom else (pc + 1) % size
  in
  let rejected =
    List.filter (List.range 0 size) ~f:(fun pc ->
      let w = word pc in
      let target =
        Bits.to_unsigned_int (Isa.Field.select (module Bits) Isa.Field.jmp_target w)
      in
      not
        (Bits.to_bool
           (K.accepts
              ~side_set_count
              ~fraction
              ~word:w
              ~row:table.(pc)
              ~next:table.(following pc)
              ~target:table.(target))))
  in
  match starts_open, rejected with
  | true, [] -> Ok ()
  | false, _ -> Or_error.error_s [%message "the row at pc 0 must be the full range"]
  | true, pcs -> Or_error.error_s [%message "rows the kernel rejects" (pcs : int list)]
;;

module I = struct
  type 'a t =
    { side_set_count : 'a [@bits 2]
    ; fraction : 'a
    ; word : 'a [@bits Isa.data_bits]
    ; phase : 'a [@bits Isa.timer_bits]
    ; period : 'a [@bits Isa.data_bits]
    }
  [@@deriving hardcaml]
end

module O = Step

let create (_scope : Scope.t) (i : Signal.t I.t) =
  let module K = Make (Signal) in
  K.step
    ~side_set_count:i.side_set_count
    ~fraction:i.fraction
    ~word:i.word
    ~phase:i.phase
    ~period:i.period
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"kernel_step" create i
;;
