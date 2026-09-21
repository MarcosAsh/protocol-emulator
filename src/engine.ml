open! Core
open! Hardcaml
open! Signal

let num_pins = Isa.pin_space
let pin_bits = Int.ceil_log2 num_pins
let first_output_pin = Isa.first_output_pin
let first_bidir_pin = Isa.first_bidir_pin

module Config = struct
  type 'a t =
    { side_set_count : 'a [@bits 2]
    ; side_set_base : 'a [@bits pin_bits]
    ; side_set_pindirs : 'a
    ; in_base : 'a [@bits pin_bits]
    ; in_count : 'a [@bits Isa.count_bits]
    ; out_base : 'a [@bits pin_bits]
    ; out_count : 'a [@bits Isa.count_bits]
    ; set_base : 'a [@bits pin_bits]
    ; set_count : 'a [@bits 3]
    ; jmp_pin : 'a [@bits pin_bits]
    ; capture_pin : 'a [@bits pin_bits]
    ; capture_rising : 'a
    ; in_shift_right : 'a
    ; out_shift_right : 'a
    ; autopush : 'a
    ; push_threshold : 'a [@bits Isa.count_bits]
    ; autopull : 'a
    ; pull_threshold : 'a [@bits Isa.count_bits]
    ; crc_width : 'a [@bits Isa.count_bits]
    ; crc_poly : 'a [@bits Isa.data_bits]
    ; crc_init : 'a [@bits Isa.data_bits]
    ; crc_reflect : 'a
    ; stuff_threshold : 'a [@bits Isa.count_bits]
    ; stuff_level : 'a
    ; wrap_bottom : 'a [@bits Isa.pc_bits]
    ; wrap_top : 'a [@bits Isa.pc_bits]
    }
  [@@deriving hardcaml]

  let of_program_config (c : Program_config.t) =
    let bool b = Bits.of_bool b in
    let int width v = Bits.of_unsigned_int ~width v in
    let right (d : Program_config.Shift_direction.t) =
      match d with
      | Right -> Bits.vdd
      | Left -> Bits.gnd
    in
    { side_set_count = int 2 c.side_set_count
    ; side_set_base = int pin_bits c.side_set_base
    ; side_set_pindirs = bool c.side_set_pindirs
    ; in_base = int pin_bits c.in_base
    ; in_count = int Isa.count_bits c.in_count
    ; out_base = int pin_bits c.out_base
    ; out_count = int Isa.count_bits c.out_count
    ; set_base = int pin_bits c.set_base
    ; set_count = int 3 c.set_count
    ; jmp_pin = int pin_bits c.jmp_pin
    ; capture_pin = int pin_bits c.capture_pin
    ; capture_rising = bool c.capture_rising
    ; in_shift_right = right c.in_shift
    ; out_shift_right = right c.out_shift
    ; autopush = bool c.autopush
    ; push_threshold = int Isa.count_bits c.push_threshold
    ; autopull = bool c.autopull
    ; pull_threshold = int Isa.count_bits c.pull_threshold
    ; crc_width = int Isa.count_bits c.crc_width
    ; crc_poly = int Isa.data_bits c.crc_poly
    ; crc_init = int Isa.data_bits c.crc_init
    ; crc_reflect = bool c.crc_reflect
    ; stuff_threshold = int Isa.count_bits c.stuff_threshold
    ; stuff_level = bool c.stuff_level
    ; wrap_bottom = int Isa.pc_bits c.wrap_bottom
    ; wrap_top = int Isa.pc_bits c.wrap_top
    }
  ;;
end

module Fault = struct
  type 'a t =
    { underflow : 'a
    ; overflow : 'a
    ; missed_deadline : 'a
    ; decode : 'a
    }
  [@@deriving hardcaml]
end

module Program_write = struct
  type 'a t =
    { valid : 'a
    ; addr : 'a [@bits Isa.pc_bits]
    ; data : 'a [@bits Isa.word_bits]
    }
  [@@deriving hardcaml]
end

module Memory = struct
  type t =
    | Flops
    | Ihp_sram
  [@@deriving sexp_of, enumerate]
end

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; config : 'a Config.t
    ; start : 'a
    ; program_write : 'a Program_write.t
    ; tx : 'a With_valid.t [@bits Isa.data_bits]
    ; rx_pop : 'a
    ; clear_irq : 'a
    ; stop : 'a
    ; flush : 'a
    ; inputs : 'a [@bits num_pins]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { pin_out : 'a [@bits num_pins]
    ; pin_dir : 'a [@bits num_pins]
    ; pc : 'a [@bits Isa.pc_bits]
    ; x : 'a [@bits Isa.data_bits]
    ; y : 'a [@bits Isa.data_bits]
    ; p : 'a [@bits Isa.data_bits]
    ; t : 'a [@bits Isa.timer_bits]
    ; osr : 'a [@bits Isa.data_bits]
    ; osr_count : 'a [@bits Isa.count_bits]
    ; isr : 'a [@bits Isa.data_bits]
    ; isr_count : 'a [@bits Isa.count_bits]
    ; now : 'a [@bits Isa.timer_bits]
    ; stall : 'a [@bits Isa.count_bits]
    ; halted : 'a
    ; irq : 'a
    ; fault : 'a Fault.t
    ; capture : 'a [@bits Isa.timer_bits]
    ; capture_armed : 'a
    ; tx_level : 'a [@bits Host_fifo.level_bits]
    ; rx_level : 'a [@bits Host_fifo.level_bits]
    ; rx_head : 'a [@bits Isa.data_bits]
    ; instruction : 'a [@bits Isa.word_bits]
    ; decode_ok : 'a
    ; opcode_onehot : 'a [@bits List.length Isa.Opcode.Cases.all]
    ; crc : 'a [@bits Isa.data_bits]
    ; stuff_run : 'a [@bits Isa.count_bits]
    }
  [@@deriving hardcaml]
end

let data_bits = Isa.data_bits
let timer_bits = Isa.timer_bits
let pc_bits = Isa.pc_bits
let count_bits = Isa.count_bits

module Pins = Pins.Make (Signal)

let read_pins = Pins.read
let write_pins = Pins.write
let count_mask = Pins.count_mask

(* Schedule. The memory reads one address ahead of the instruction register [word], which
   holds the word at [pc]. An instruction issues when the core is neither halted nor
   stalled and no start is in flight, and then stalls for its delay field. A jump issues,
   redirects the fetch and stalls one cycle while the register refills, so it always takes
   two cycles whichever way it goes. A wait whose condition is false issues again the next
   cycle and re-applies its side-set. Registers written in a cycle are visible from the
   next one, and a pin write shows on the pin the cycle after it issues. *)
let create ~(memory : Memory.t) (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let c = i.config in
  (* Architectural state. Each register takes a next value computed below. *)
  let%hw pc = wire pc_bits in
  let%hw x = wire data_bits in
  let%hw y = wire data_bits in
  let%hw p = wire data_bits in
  let%hw t = wire timer_bits in
  let%hw osr = wire data_bits in
  let%hw osr_count = wire count_bits in
  let%hw isr = wire data_bits in
  let%hw isr_count = wire count_bits in
  let%hw now = wire timer_bits in
  let%hw pin_out = wire num_pins in
  let%hw pin_dir = wire num_pins in
  let%hw pins_sampled = wire num_pins in
  let%hw stall = wire count_bits in
  let%hw halted = wire 1 in
  let%hw capture = wire timer_bits in
  let%hw capture_armed = wire 1 in
  let%hw crc = wire data_bits in
  let%hw stuff_run = wire count_bits in
  let%hw fetch_addr = wire pc_bits in
  let%hw ir_load = wire 1 in
  let%hw start = reg spec i.start in
  let%hw tx_pop = wire 1 in
  let rx_push = { With_valid.valid = wire 1; value = wire data_bits } in
  (* a halted core touches neither fifo, so a flush can never race the program *)
  let%hw flush = i.flush &: halted in
  let tx =
    Host_fifo.hierarchical
      ~instance:"tx"
      scope
      { clocking = i.clocking; push = i.tx; pop = tx_pop; flush }
  in
  let rx =
    Host_fifo.hierarchical
      ~instance:"rx"
      scope
      { clocking = i.clocking; push = rx_push; pop = i.rx_pop; flush }
  in
  (* a write while the core runs would take the memory from the fetch *)
  let%hw program_write = i.program_write.valid &: halted in
  let memory_in =
    { Program_memory.I.clock = i.clocking.clock
    ; men = vdd
    ; wen = program_write
    ; ren = vdd
    ; addr = mux2 program_write i.program_write.addr fetch_addr
    ; din = i.program_write.data
    ; bm = ones Isa.word_bits
    }
  in
  let memory =
    match memory with
    | Flops -> Program_memory.hierarchical scope memory_in
    | Ihp_sram -> Sram_macro.hierarchical scope memory_in
  in
  (* The memory runs a cycle ahead of the instruction register and is refilled after a
     jump or a start, which is where the second cycle of a jump goes. *)
  let%hw word = reg spec ~enable:ir_load memory.dout in
  let%hw sample =
    List.init num_pins ~f:(fun n ->
      if n >= Isa.num_pins
      then pin_out.:(n) |: i.inputs.:(n)
      else (
        let driven =
          if n < first_output_pin
          then gnd
          else if n < first_bidir_pin
          then vdd
          else pin_dir.:(n)
        in
        mux2 driven pin_out.:(n) i.inputs.:(n)))
    |> concat_lsb
  in
  let pin_of v idx = mux idx (bits_lsb v) in
  let module D = Decoder.Make (Signal) in
  let%hw.Decoder.Decoded.Of_signal d = D.decode ~side_set_count:c.side_set_count word in
  let%tydi { Decoder.Decoded.valid = _
           ; opcode
           ; delay
           ; side_set
           ; jmp_cond
           ; jmp_target
           ; wait_polarity
           ; wait_source
           ; wait_index
           ; shift_count
           ; in_source
           ; out_dest
           ; mov_dest
           ; mov_op
           ; mov_source
           ; set_dest
           ; set_value
           ; alu_dest
           ; alu_op
           ; alu_is_reg
           ; alu_imm
           ; alu_reg
           ; sys_op
           }
    =
    d
  in
  (* Whether the word decodes and which opcode it is are worked out on the memory's output
     and registered with the word, so the enables that gate every register start from a
     flop and not from the decoder. Neither depends on the configuration. *)
  let fetched = D.decode ~side_set_count:c.side_set_count memory.dout in
  let%hw decode_ok = reg spec ~enable:ir_load ~clear_to:vdd fetched.valid in
  let%hw_list is_opcode =
    List.map Isa.Opcode.Cases.all ~f:(fun op ->
      reg
        spec
        ~enable:ir_load
        ~clear_to:(of_bool (Isa.Opcode.to_int op = 0))
        (Isa.Opcode.Of_signal.is fetched.opcode op))
  in
  let is op = List.nth_exn is_opcode (Isa.Opcode.to_int op) in
  let is_sys op = is Sys &: Isa.Sys_op.Of_signal.is sys_op op in
  let module Deadline = Deadline.Make (Signal) in
  let%hw deadline_ready = Deadline.release ~now ~t in
  let%hw deadline_late = Deadline.late ~now ~t in
  let%hw wait_pin_prev = pin_of pins_sampled wait_index in
  let%hw wait_pin_cur = pin_of sample wait_index in
  let%hw wait_ready =
    Isa.Wait_source.Of_signal.match_
      wait_source
      [ Pin_level, wait_pin_cur ==: wait_polarity
      ; Pin_edge, wait_pin_cur <>: wait_pin_prev &: (wait_pin_cur ==: wait_polarity)
      ; Deadline, deadline_ready
      ; Fifo, mux2 wait_polarity ~:(tx.empty) ~:(rx.full)
      ]
  in
  let%hw jmp_taken =
    Isa.Jmp_cond.Of_signal.match_
      jmp_cond
      [ Always, vdd
      ; X_dec, x <>:. 0
      ; Y_dec, y <>:. 0
      ; X_ne_y, x <>: y
      ; Pin, pin_of sample c.jmp_pin
      ; Not_pin, ~:(pin_of sample c.jmp_pin)
      ; Osr_not_empty, osr_count <: c.pull_threshold
      ; Stuff_pending, c.stuff_threshold <>:. 0 &: (stuff_run >=: c.stuff_threshold)
      ; Tx_not_empty, ~:(tx.empty)
      ; Tx_empty, tx.empty
      ; Rx_not_full, ~:(rx.full)
      ; Rx_full, rx.full
      ]
  in
  let%hw issue = ~:halted &: (stall ==:. 0) &: ~:start in
  let%hw go = issue &: decode_ok in
  let%hw jmp_go = go &: is Jmp in
  let%hw op_go = go &: ~:(is Jmp) in
  let%hw wait_holds = is Wait &: ~:wait_ready in
  let%hw advance = op_go &: ~:wait_holds in
  (* The wrap: the address after [wrap_top] is [wrap_bottom]. It comes off the pc register
     and the configuration alone, so the memory can read ahead across it and the loop
     costs nothing. *)
  let after addr = mux2 (addr ==: c.wrap_top) c.wrap_bottom (addr +:. 1) in
  let%hw pc_next = after pc in
  let%hw jmp_target_or_next = mux2 jmp_taken jmp_target pc_next in
  (* Shifts and moves. *)
  let%hw mask = count_mask shift_count in
  let%hw in_value =
    Isa.In_source.Of_signal.match_
      in_source
      [ Pins, read_pins sample ~base:c.in_base ~count:shift_count
      ; X, x
      ; Y, y
      ; Null, zero data_bits
      ; Isr, isr
      ; Osr, osr
      ; Crc, crc
      ; Capture, sel_bottom capture ~width:data_bits
      ]
    &: mask
  in
  let%hw shift_back = of_unsigned_int ~width:count_bits data_bits -: shift_count in
  let%hw isr_shifted =
    mux2
      c.in_shift_right
      (log_shift ~f:srl isr ~by:shift_count |: log_shift ~f:sll in_value ~by:shift_back)
      (log_shift ~f:sll isr ~by:shift_count |: in_value)
  in
  let saturate a b =
    let s = uresize a ~width:(count_bits + 1) +: uresize b ~width:(count_bits + 1) in
    mux2
      (s >:. data_bits)
      (of_unsigned_int ~width:count_bits data_bits)
      (sel_bottom s ~width:count_bits)
  in
  let%hw isr_count_next = saturate isr_count shift_count in
  let%hw autopush_now = c.autopush &: (isr_count_next >=: c.push_threshold) in
  let%hw pull_now = c.autopull &: (osr_count >=: c.pull_threshold) in
  let%hw pull_ok = pull_now &: ~:(tx.empty) in
  let%hw osr_before = mux2 pull_ok tx.head osr in
  let%hw osr_count_before = mux2 pull_now (zero count_bits) osr_count in
  let%hw out_value =
    mux2
      c.out_shift_right
      (osr_before &: mask)
      (log_shift ~f:srl osr_before ~by:shift_back &: mask)
  in
  let%hw osr_shifted =
    mux2
      c.out_shift_right
      (log_shift ~f:srl osr_before ~by:shift_count)
      (log_shift ~f:sll osr_before ~by:shift_count)
  in
  let%hw osr_count_next = saturate osr_count_before shift_count in
  (* The assist units see the bit of every single-bit shift, whatever it moves between. *)
  let%hw bit_crosses = shift_count ==:. 1 &: (is In |: is Out) in
  let%hw crossing_bit = mux2 (is In) in_value.:(0) out_value.:(0) in
  let module Crc_step = Crc.Make (Signal) in
  let%hw crc_stepped =
    Crc_step.step
      ~width:c.crc_width
      ~poly:c.crc_poly
      ~reflect:c.crc_reflect
      crc
      ~bit:crossing_bit
  in
  let%hw crc_next =
    mux2 (is_sys Crc_init) c.crc_init @@ mux2 bit_crosses crc_stepped crc
  in
  let%hw stuff_run_max = of_unsigned_int ~width:count_bits 31 in
  let%hw stuff_run_next =
    mux2 (is_sys Stuff_reset) (zero count_bits)
    @@ mux2
         bit_crosses
         (mux2
            (crossing_bit ==: c.stuff_level)
            (mux2 (stuff_run ==: stuff_run_max) stuff_run (stuff_run +:. 1))
            (zero count_bits))
         stuff_run
  in
  let%hw mov_value24 =
    Isa.Mov_source.Of_signal.match_
      mov_source
      [ ( Pins
        , uresize (read_pins sample ~base:c.in_base ~count:c.in_count) ~width:timer_bits )
      ; X, uresize x ~width:timer_bits
      ; Y, uresize y ~width:timer_bits
      ; Null, zero timer_bits
      ; Isr, uresize isr ~width:timer_bits
      ; Osr, uresize osr ~width:timer_bits
      ; Now, now
      ; Capture, capture
      ]
  in
  let mov_apply v =
    Isa.Mov_op.Of_signal.match_
      ~default:v
      mov_op
      [ Copy, v; Invert, ~:v; Reverse, reverse v ]
  in
  let%hw mov_value = mov_apply (sel_bottom mov_value24 ~width:data_bits) in
  let%hw mov_value_t = mov_apply mov_value24 in
  let%hw alu_operand =
    mux2
      alu_is_reg
      (Isa.Alu_reg.Of_signal.match_
         ~default:(zero data_bits)
         alu_reg
         [ X, x; Y, y; P, p; Isr, isr; Osr, osr ])
      (uresize alu_imm ~width:data_bits)
  in
  let alu_apply v =
    let operand = uresize alu_operand ~width:(width v) in
    Isa.Alu_op.Of_signal.match_
      ~default:v
      alu_op
      [ Add, v +: operand; Sub, v -: operand; Xor, v ^: operand ]
  in
  (* Pin writes: side-set first, then the instruction's own write. *)
  let output_pin n = n >= first_output_pin in
  let bidir_pin n = n >= first_bidir_pin && n < Isa.num_pins in
  let side_count = uresize c.side_set_count ~width:count_bits in
  let set_count = uresize c.set_count ~width:count_bits in
  let%hw pin_out_side =
    write_pins
      pin_out
      ~base:c.side_set_base
      ~count:side_count
      ~value:side_set
      ~writable:output_pin
  in
  let%hw pin_dir_side =
    write_pins
      pin_dir
      ~base:c.side_set_base
      ~count:side_count
      ~value:side_set
      ~writable:bidir_pin
  in
  let%hw pin_out_base = mux2 c.side_set_pindirs pin_out pin_out_side in
  let%hw pin_dir_base = mux2 c.side_set_pindirs pin_dir_side pin_dir in
  let out_to ~base ~count ~value =
    write_pins pin_out_base ~base ~count ~value ~writable:output_pin
  in
  let dir_to ~base ~count ~value =
    write_pins pin_dir_base ~base ~count ~value ~writable:bidir_pin
  in
  let%hw pin_out_next =
    Isa.Opcode.Of_signal.match_
      ~default:pin_out_base
      opcode
      [ ( Out
        , mux2
            (Isa.Out_dest.Of_signal.is out_dest Pins)
            (out_to ~base:c.out_base ~count:shift_count ~value:out_value)
            pin_out_base )
      ; ( Mov
        , mux2
            (Isa.Mov_dest.Of_signal.is mov_dest Pins)
            (out_to ~base:c.out_base ~count:c.out_count ~value:mov_value)
            pin_out_base )
      ; ( Set
        , mux2
            (Isa.Set_dest.Of_signal.is set_dest Pins)
            (out_to ~base:c.set_base ~count:set_count ~value:set_value)
            pin_out_base )
      ]
  in
  let%hw pin_dir_next =
    Isa.Opcode.Of_signal.match_
      ~default:pin_dir_base
      opcode
      [ ( Out
        , mux2
            (Isa.Out_dest.Of_signal.is out_dest Pindirs)
            (dir_to ~base:c.out_base ~count:shift_count ~value:out_value)
            pin_dir_base )
      ; ( Mov
        , mux2
            (Isa.Mov_dest.Of_signal.is mov_dest Pindirs)
            (dir_to ~base:c.out_base ~count:c.out_count ~value:mov_value)
            pin_dir_base )
      ; ( Set
        , mux2
            (Isa.Set_dest.Of_signal.is set_dest Pindirs)
            (dir_to ~base:c.set_base ~count:set_count ~value:set_value)
            pin_dir_base )
      ]
  in
  (* Register next values, one selector per architectural register. *)
  let by_opcode ~default cases = Isa.Opcode.Of_signal.match_ ~default opcode cases in
  let%hw x_next =
    by_opcode
      ~default:x
      [ Jmp, mux2 (Isa.Jmp_cond.Of_signal.is jmp_cond X_dec) (x -:. 1) x
      ; Out, mux2 (Isa.Out_dest.Of_signal.is out_dest X) out_value x
      ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest X) mov_value x
      ; ( Set
        , mux2
            (Isa.Set_dest.Of_signal.is set_dest X)
            (uresize set_value ~width:data_bits)
            x )
      ; Alu, mux2 (Isa.Alu_dest.Of_signal.is alu_dest X) (alu_apply x) x
      ]
  in
  let%hw y_next =
    by_opcode
      ~default:y
      [ Jmp, mux2 (Isa.Jmp_cond.Of_signal.is jmp_cond Y_dec) (y -:. 1) y
      ; Out, mux2 (Isa.Out_dest.Of_signal.is out_dest Y) out_value y
      ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest Y) mov_value y
      ; ( Set
        , mux2
            (Isa.Set_dest.Of_signal.is set_dest Y)
            (uresize set_value ~width:data_bits)
            y )
      ; Alu, mux2 (Isa.Alu_dest.Of_signal.is alu_dest Y) (alu_apply y) y
      ]
  in
  let%hw p_next =
    by_opcode
      ~default:p
      [ Out, mux2 (Isa.Out_dest.Of_signal.is out_dest P) out_value p
      ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest P) mov_value p
      ; ( Set
        , mux2
            (Isa.Set_dest.Of_signal.is set_dest P)
            (uresize set_value ~width:data_bits)
            p )
      ; Alu, mux2 (Isa.Alu_dest.Of_signal.is alu_dest P) (alu_apply p) p
      ]
  in
  let%hw releases_deadline =
    is Wait &: Isa.Wait_source.Of_signal.is wait_source Deadline &: wait_ready
  in
  let%hw t_next =
    by_opcode
      ~default:t
      [ ( Wait
        , mux2 (releases_deadline &: wait_polarity) (t +: uresize p ~width:timer_bits) t )
      ; ( Out
        , mux2
            (Isa.Out_dest.Of_signal.is out_dest T)
            (uresize out_value ~width:timer_bits)
            t )
      ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest T) mov_value_t t
      ; Alu, mux2 (Isa.Alu_dest.Of_signal.is alu_dest T) (alu_apply t) t
      ]
  in
  let%hw pushes = is In &: autopush_now |: is_sys Push in
  let%hw pulls = is_sys Pull in
  let%hw osr_next =
    by_opcode
      ~default:osr
      [ Out, osr_shifted
      ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest Osr) mov_value osr
      ; Sys, mux2 (pulls &: ~:(tx.empty)) tx.head osr
      ]
  in
  let%hw osr_count_zero = zero count_bits in
  let%hw osr_count_next_value =
    by_opcode
      ~default:osr_count
      [ Out, osr_count_next
      ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest Osr) osr_count_zero osr_count
      ; Sys, mux2 pulls osr_count_zero osr_count
      ]
  in
  let%hw isr_next =
    by_opcode
      ~default:isr
      [ In, mux2 autopush_now (zero data_bits) isr_shifted
      ; Out, mux2 (Isa.Out_dest.Of_signal.is out_dest Isr) out_value isr
      ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest Isr) mov_value isr
      ; Sys, mux2 (is_sys Push) (zero data_bits) isr
      ]
  in
  let%hw isr_count_next_value =
    by_opcode
      ~default:isr_count
      [ In, mux2 autopush_now osr_count_zero isr_count_next
      ; Out, mux2 (Isa.Out_dest.Of_signal.is out_dest Isr) shift_count isr_count
      ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest Isr) osr_count_zero isr_count
      ; Sys, mux2 (is_sys Push) osr_count_zero isr_count
      ]
  in
  let%hw captured =
    capture_armed
    &: (pin_of sample c.capture_pin <>: pin_of pins_sampled c.capture_pin)
    &: (pin_of sample c.capture_pin ==: c.capture_rising)
  in
  (* Control. *)
  let%hw halted_next =
    mux2 start gnd
    @@ mux2 i.stop vdd
    @@ mux2 (issue &: ~:decode_ok) vdd
    @@ mux2 (op_go &: is_sys Halt) vdd halted
  in
  let%hw stall_next =
    mux2 start (zero count_bits)
    @@ mux2 jmp_go (of_unsigned_int ~width:count_bits (Isa.jmp_cycles - 1))
    @@ mux2 advance delay
    @@ mux2 (stall <>:. 0) (stall -:. 1) stall
  in
  let%hw pc_value_next =
    mux2 start (zero pc_bits) @@ mux2 jmp_go jmp_target_or_next @@ mux2 advance pc_next pc
  in
  (* The address after the next instruction, picked from sums made off the register so
     that no adder follows the control logic on the way to the memory. *)
  let%hw pc_after_next =
    mux2 start (after (zero pc_bits)) @@ mux2 advance (after pc_next) pc_next
  in
  fetch_addr
  <-- mux2 i.start (zero pc_bits) @@ mux2 jmp_go jmp_target_or_next pc_after_next;
  let%hw refill = reg spec (jmp_go |: i.start) in
  ir_load <-- (advance |: refill);
  let sticky set = reg spec ~enable:set vdd in
  let fault =
    { Fault.underflow =
        sticky (op_go &: (is Out &: pull_now &: tx.empty |: (pulls &: tx.empty)))
    ; overflow = sticky (op_go &: pushes &: rx.full)
    ; missed_deadline = sticky (op_go &: releases_deadline &: deadline_late)
    ; decode = sticky (issue &: ~:decode_ok)
    }
  in
  rx_push.valid <-- (op_go &: pushes &: ~:(rx.full));
  rx_push.value <-- mux2 (is In) isr_shifted isr;
  tx_pop <-- (op_go &: (is Out &: pull_ok |: (pulls &: ~:(tx.empty))));
  pc <-- reg spec pc_value_next;
  x <-- reg spec ~enable:go x_next;
  y <-- reg spec ~enable:go y_next;
  p <-- reg spec ~enable:go p_next;
  t <-- reg spec ~enable:go t_next;
  osr <-- reg spec ~enable:go osr_next;
  osr_count
  <-- reg
        spec
        ~enable:go
        ~clear_to:(of_unsigned_int ~width:count_bits data_bits)
        osr_count_next_value;
  isr <-- reg spec ~enable:go isr_next;
  isr_count <-- reg spec ~enable:go isr_count_next_value;
  now <-- reg spec (mux2 start (zero timer_bits) (now +:. 1));
  pin_out <-- reg spec ~enable:op_go pin_out_next;
  pin_dir <-- reg spec ~enable:op_go pin_dir_next;
  pins_sampled <-- reg spec sample;
  stall <-- reg spec stall_next;
  halted <-- reg spec ~clear_to:vdd halted_next;
  capture <-- reg spec ~enable:captured now;
  crc <-- reg spec (mux2 start c.crc_init @@ mux2 go crc_next crc);
  stuff_run <-- reg spec (mux2 start (zero count_bits) @@ mux2 go stuff_run_next stuff_run);
  capture_armed
  <-- reg spec (mux2 captured gnd @@ mux2 (op_go &: is_sys Capture_arm) vdd capture_armed);
  let%hw irq =
    reg_fb spec ~width:1 ~f:(fun d ->
      mux2 (op_go &: is_sys Irq) vdd @@ mux2 i.clear_irq gnd d)
  in
  { O.pin_out
  ; pin_dir
  ; pc
  ; x
  ; y
  ; p
  ; t
  ; osr
  ; osr_count
  ; isr
  ; isr_count
  ; now
  ; stall
  ; halted
  ; irq
  ; fault
  ; capture
  ; capture_armed
  ; tx_level = tx.level
  ; rx_level = rx.level
  ; rx_head = rx.head
  ; instruction = word
  ; decode_ok
  ; opcode_onehot = concat_lsb is_opcode
  ; crc
  ; stuff_run
  }
;;

let hierarchical ?instance ~memory scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"engine" (create ~memory) i
;;
