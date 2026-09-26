open! Core
open! Hardcaml

module Row = struct
  type 'a t =
    { phase_lo : 'a [@bits Isa.timer_bits]
    ; phase_hi : 'a [@bits Isa.timer_bits]
    ; period_lo : 'a [@bits Isa.data_bits]
    ; period_hi : 'a [@bits Isa.data_bits]
    ; x_lo : 'a [@bits Isa.data_bits]
    ; x_hi : 'a [@bits Isa.data_bits]
    ; y_lo : 'a [@bits Isa.data_bits]
    ; y_hi : 'a [@bits Isa.data_bits]
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
    ; next_x : 'a [@bits Isa.data_bits]
    ; x_known : 'a
    ; next_y : 'a [@bits Isa.data_bits]
    ; y_known : 'a
    ; taken : 'a
    ; taken_known : 'a
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
      }

    let of_word ~side_set_count word =
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
      { cycles =
          mux2 jump (of_unsigned_int ~width:Isa.timer_bits Isa.jmp_cycles)
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
      }
    ;;
  end

  let step ~side_set_count ~fraction ~(loaded : _ With_valid.t) ~word ~phase ~period ~x ~y
    =
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
    ; halts = c.halts
    }
  ;;

  (* two bits wider, so a bound that leaves the timer's range shows *)
  let wide_bits = Isa.timer_bits + 2
  let wide x = sresize x ~width:wide_bits
  let wide_data x = uresize x ~width:wide_bits
  let timer_min = of_signed_int ~width:wide_bits (-(1 lsl (Isa.timer_bits - 1)))
  let timer_max = of_signed_int ~width:wide_bits ((1 lsl (Isa.timer_bits - 1)) - 1)
  let data_max = ones Isa.data_bits

  let is_empty (r : _ Row.t) =
    r.phase_lo
    >+ r.phase_hi
    |: (r.period_lo >: r.period_hi)
    |: (r.x_lo >: r.x_hi)
    |: (r.y_lo >: r.y_hi)
  ;;

  let is_full (r : _ Row.t) =
    wide r.phase_lo ==: timer_min &: (wide r.phase_hi ==: timer_max)
  ;;

  (* An unsigned interval that a register's image must fall in, or [any] for a write the
     kernel does not follow. *)
  let contains ~lo ~hi ~any ~image_lo ~image_hi =
    mux2 any (lo ==:. 0 &: (hi ==: data_max)) (lo <=: image_lo &: (image_hi <=: hi))
  ;;

  let accepts
    ~side_set_count
    ~fraction
    ~(loaded : _ With_valid.t)
    ~word
    ~(row : _ Row.t)
    ~(next : _ Row.t)
    ~target
    =
    let c = Class.of_word ~side_set_count word in
    let lo = wide row.phase_lo in
    let hi = wide row.phase_hi in
    let released x = mux2 (x <+ zero wide_bits) (zero wide_bits) x in
    let cycles = uresize c.cycles ~width:wide_bits in
    let imm = uresize c.imm ~width:wide_bits in
    let carry = uresize (c.advance &: fraction) ~width:wide_bits in
    let by_register ~p ~x ~y ~otherwise =
      mux2 (c.advance |: c.add_p) p @@ mux2 c.add_x x @@ mux2 c.add_y y @@ otherwise
    in
    let image_lo, image_hi =
      let base_lo = mux2 c.anchor (zero wide_bits) @@ mux2 c.deadline (released lo) lo in
      let base_hi = mux2 c.anchor (zero wide_bits) @@ mux2 c.deadline (released hi) hi in
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
      base_lo +: cycles -: less_lo, base_hi +: cycles -: less_hi
    in
    let fits = image_lo >=+ timer_min &: (image_hi <=+ timer_max) in
    let period_image v = mux2 c.set_p c.set_value @@ mux2 c.writes_p loaded.value v in
    (* a register's image on one way out: a counted jump decrements it on both *)
    let counter ~set ~dec ~(taken : bool) lo hi =
      let taken_lo = mux2 (lo ==:. 0) (zero Isa.data_bits) (lo -:. 1) in
      let dec_lo, dec_hi = if taken then taken_lo, hi -:. 1 else data_max, data_max in
      ( mux2 set c.set_value @@ mux2 dec dec_lo lo
      , mux2 set c.set_value @@ mux2 dec dec_hi hi )
    in
    let holds ~taken (s : _ Row.t) =
      let x_lo, x_hi = counter ~set:c.set_x ~dec:c.x_dec ~taken row.x_lo row.x_hi in
      let y_lo, y_hi = counter ~set:c.set_y ~dec:c.y_dec ~taken row.y_lo row.y_hi in
      let phase =
        is_full s
        |: (c.bounded
            &: fits
            &: (wide s.phase_lo <=+ image_lo)
            &: (image_hi <=+ wide s.phase_hi))
      in
      phase
      &: contains
           ~lo:s.period_lo
           ~hi:s.period_hi
           ~any:(c.writes_p &: ~:(loaded.valid))
           ~image_lo:(period_image row.period_lo)
           ~image_hi:(period_image row.period_hi)
      &: contains ~lo:s.x_lo ~hi:s.x_hi ~any:c.writes_x ~image_lo:x_lo ~image_hi:x_hi
      &: contains ~lo:s.y_lo ~hi:s.y_hi ~any:c.writes_y ~image_lo:y_lo ~image_hi:y_hi
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
    let in_time = ~:(c.deadline) |: (row.phase_hi <=+ zero Isa.timer_bits) in
    is_empty row
    |: c.halts
    |: (in_time
        &: (~:(c.jump) |: ~:may_fall |: holds ~taken:false next)
        &: (c.jump |: holds ~taken:false next)
        &: (~:(c.jump) |: ~:may_take |: holds ~taken:true target))
  ;;

  let following ~wrap_top ~wrap_bottom pc = mux2 (pc ==: wrap_top) wrap_bottom (pc +:. 1)
end

module Table = struct
  type t = Bits.t Row.t array

  let full_phase = Interval.top

  let row ~(phase : Interval.t) ~(period : Interval.t) ~(x : Interval.t) ~(y : Interval.t)
    =
    let signed n = Bits.of_signed_int ~width:Isa.timer_bits n in
    let data_max = (1 lsl Isa.data_bits) - 1 in
    (* the analyser's register bounds are the value's, so clamp them to its width *)
    let data bound ~default =
      Bits.of_unsigned_int
        ~width:Isa.data_bits
        (Int.clamp_exn (Option.value bound ~default) ~min:0 ~max:data_max)
    in
    let half = 1 lsl (Isa.timer_bits - 1) in
    (* an open end is the whole range, since the timer wraps *)
    let phase_lo, phase_hi =
      match phase.lo, phase.hi with
      | Some lo, Some hi -> lo, hi
      | _ -> -half, half - 1
    in
    { Row.phase_lo = signed phase_lo
    ; phase_hi = signed phase_hi
    ; period_lo = data period.lo ~default:0
    ; period_hi = data period.hi ~default:data_max
    ; x_lo = data x.lo ~default:0
    ; x_hi = data x.hi ~default:data_max
    ; y_lo = data y.lo ~default:0
    ; y_hi = data y.hi ~default:data_max
    }
  ;;

  let unreached =
    { Row.phase_lo = Bits.of_signed_int ~width:Isa.timer_bits 1
    ; phase_hi = Bits.zero Isa.timer_bits
    ; period_lo = Bits.zero Isa.data_bits
    ; period_hi = Bits.zero Isa.data_bits
    ; x_lo = Bits.zero Isa.data_bits
    ; x_hi = Bits.zero Isa.data_bits
    ; y_lo = Bits.zero Isa.data_bits
    ; y_hi = Bits.zero Isa.data_bits
    }
  ;;

  let of_analyser (rows : Analyser.Row.t list) =
    let table = Array.create ~len:(1 lsl Isa.pc_bits) unreached in
    List.iter rows ~f:(fun r ->
      table.(r.pc) <- row ~phase:r.phase ~period:r.period ~x:r.x ~y:r.y);
    table.(0)
    <- row ~phase:full_phase ~period:Interval.top ~x:Interval.top ~y:Interval.top;
    table
  ;;
end

module K = Make (Bits)

let check ?period ~(config : Program_config.t) ~words (table : Table.t) =
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
  let starts_open =
    let r = table.(0) in
    let full lo hi =
      Bits.to_unsigned_int lo = 0 && Bits.to_unsigned_int hi = (1 lsl Isa.data_bits) - 1
    in
    Bits.to_bool (K.is_full r)
    && full r.period_lo r.period_hi
    && full r.x_lo r.x_hi
    && full r.y_lo r.y_hi
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
              ~loaded
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
    ; loaded : 'a With_valid.t [@bits Isa.data_bits]
    ; word : 'a [@bits Isa.data_bits]
    ; phase : 'a [@bits Isa.timer_bits]
    ; period : 'a [@bits Isa.data_bits]
    ; x : 'a [@bits Isa.data_bits]
    ; y : 'a [@bits Isa.data_bits]
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
    ~word:i.word
    ~phase:i.phase
    ~period:i.period
    ~x:i.x
    ~y:i.y
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"kernel_step" create i
;;
