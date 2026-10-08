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
    ; period_fraction : 'a [@bits Isa.fraction_bits]
    ; autopull_data : 'a
    ; manchester : 'a
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
    ; period_fraction = int Isa.fraction_bits c.period_fraction
    ; autopull_data = bool c.autopull_data
    ; manchester = bool c.manchester
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

module Host = struct
  type 'a t =
    { config : 'a Config.t
    ; start : 'a
    ; program_write : 'a Program_write.t
    ; data_write : 'a Program_write.t
    ; tx : 'a With_valid.t [@bits Isa.data_bits]
    ; rx_pop : 'a
    ; clear_irq : 'a
    ; stop : 'a
    ; flush : 'a
    ; check : 'a
    ; config_written : 'a
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
    ; program_read : 'a With_valid.t [@bits Isa.pc_bits]
    ; data_word : 'a [@bits Isa.data_bits]
    ; tx : 'a With_valid.t [@bits Isa.data_bits]
    ; rx_pop : 'a
    ; clear_irq : 'a
    ; stop : 'a
    ; flush : 'a
    ; inputs : 'a [@bits num_pins]
    }
  [@@deriving hardcaml]
end

let data_bits = Isa.data_bits
let fraction_bits = Isa.fraction_bits
let pc_bits = Isa.pc_bits
let count_bits = Isa.count_bits

module Pins = Pins.Make (Signal)

let read_pins = Pins.read
let write_pins = Pins.write
let count_mask = Pins.count_mask

(* bit [idx] of [v], for a pin the config names *)
let pin_of v idx = mux idx (bits_lsb v)

(* the address after [addr], wrapping from [wrap_top] to [wrap_bottom] *)
let address_after (c : Signal.t Config.t) addr =
  mux2 (addr ==: c.wrap_top) c.wrap_bottom (addr +:. 1)
;;

(* a shift register's fill after [b] more bits, held at [data_bits] *)
let saturate a b =
  let s = uresize a ~width:(count_bits + 1) +: uresize b ~width:(count_bits + 1) in
  mux2
    (s >:. data_bits)
    (of_unsigned_int ~width:count_bits data_bits)
    (sel_bottom s ~width:count_bits)
;;

let by_opcode opcode ~default cases = Isa.Opcode.Of_signal.match_ ~default opcode cases

let mov_apply ~mov_op v =
  Isa.Mov_op.Of_signal.match_
    ~default:v
    mov_op
    [ Copy, v; Invert, ~:v; Reverse, reverse v ]
;;

(* [v] combined with [operand] cut or extended to [v]'s width *)
let alu_apply ~alu_op ~operand v =
  let operand = uresize operand ~width:(width v) in
  Isa.Alu_op.Of_signal.match_
    ~default:v
    alu_op
    [ Add, v +: operand; Sub, v -: operand; Xor, v ^: operand ]
;;

let output_pin n = n >= first_output_pin
let bidir_pin n = n >= first_bidir_pin && n < Isa.num_pins

(* the complement on [out_base] and the bit beside it *)
let manchester_pair bit = uresize (bit @: ~:bit) ~width:data_bits

module type Timer = sig
  val timer_bits : int
end

module Make (Timer : Timer) = struct
  let timer_bits = Timer.timer_bits

  module O = struct
    type 'a t =
      { pin_out : 'a [@bits num_pins]
      ; pin_dir : 'a [@bits num_pins]
      ; pc : 'a [@bits Isa.pc_bits]
      ; data_ptr : 'a [@bits Isa.data_addr_bits]
      ; data_addr : 'a [@bits Isa.data_addr_bits]
      ; x : 'a [@bits Isa.data_bits]
      ; y : 'a [@bits Isa.data_bits]
      ; p : 'a [@bits Isa.data_bits]
      ; t : 'a [@bits timer_bits]
      ; t_fraction : 'a [@bits Isa.fraction_bits]
      ; osr : 'a [@bits Isa.data_bits]
      ; osr_count : 'a [@bits Isa.count_bits]
      ; isr : 'a [@bits Isa.data_bits]
      ; isr_count : 'a [@bits Isa.count_bits]
      ; now : 'a [@bits timer_bits]
      ; stall : 'a [@bits Isa.count_bits]
      ; halted : 'a
      ; free : 'a
      ; irq : 'a
      ; fault : 'a Fault.t
      ; capture : 'a [@bits timer_bits]
      ; capture_armed : 'a
      ; tx_level : 'a [@bits Host_fifo.level_bits]
      ; rx_level : 'a [@bits Host_fifo.level_bits]
      ; rx_head : 'a [@bits Isa.data_bits]
      ; instruction : 'a [@bits Isa.word_bits]
      ; program_word : 'a [@bits Isa.word_bits]
      ; decode_ok : 'a
      ; opcode_onehot : 'a [@bits List.length Isa.Opcode.Cases.all]
      ; wait_select : 'a [@bits num_pins]
      ; crc : 'a [@bits Isa.data_bits]
      ; stuff_run : 'a [@bits Isa.count_bits]
      ; flip_pending : 'a
      ; flip_bit : 'a
      }
    [@@deriving hardcaml]
  end

  (* Every register's output, plus [fetch_addr], [data_ptr_next] and [ir_load]: all are
     read before the logic that drives them. *)
  module Feedback = struct
    type t =
      { pc : Signal.t
      ; x : Signal.t
      ; y : Signal.t
      ; p : Signal.t
      ; t : Signal.t
      ; t_fraction : Signal.t
      ; osr : Signal.t
      ; osr_count : Signal.t
      ; isr : Signal.t
      ; isr_count : Signal.t
      ; now : Signal.t
      ; pin_out : Signal.t
      ; pin_dir : Signal.t
      ; pins_sampled : Signal.t
      ; stall : Signal.t
      ; halted : Signal.t
      ; flip_pending : Signal.t
      ; flip_bit : Signal.t
      ; capture : Signal.t
      ; capture_armed : Signal.t
      ; crc : Signal.t
      ; stuff_run : Signal.t
      ; fetch_addr : Signal.t
      ; data_ptr : Signal.t
      ; data_ptr_next : Signal.t
      ; data_moved : Signal.t
      ; ir_load : Signal.t
      }

    let create scope =
      let%hw pc = wire pc_bits in
      let%hw x = wire data_bits in
      let%hw y = wire data_bits in
      let%hw p = wire data_bits in
      let%hw t = wire timer_bits in
      let%hw t_fraction = wire fraction_bits in
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
      let%hw flip_pending = wire 1 in
      let%hw flip_bit = wire 1 in
      let%hw capture = wire timer_bits in
      let%hw capture_armed = wire 1 in
      let%hw crc = wire data_bits in
      let%hw stuff_run = wire count_bits in
      let%hw fetch_addr = wire pc_bits in
      let%hw data_ptr = wire Isa.data_addr_bits in
      let%hw data_ptr_next = wire Isa.data_addr_bits in
      let%hw data_moved = wire 1 in
      let%hw ir_load = wire 1 in
      { pc
      ; x
      ; y
      ; p
      ; t
      ; t_fraction
      ; osr
      ; osr_count
      ; isr
      ; isr_count
      ; now
      ; pin_out
      ; pin_dir
      ; pins_sampled
      ; stall
      ; halted
      ; flip_pending
      ; flip_bit
      ; capture
      ; capture_armed
      ; crc
      ; stuff_run
      ; fetch_addr
      ; data_ptr
      ; data_ptr_next
      ; data_moved
      ; ir_load
      }
    ;;
  end

  (* [tx_pop] and [rx_push] are driven once the instruction is known. *)
  module Host_fifos = struct
    type t =
      { tx : Signal.t Host_fifo.O.t
      ; rx : Signal.t Host_fifo.O.t
      ; tx_pop : Signal.t
      ; rx_push : Signal.t With_valid.t
      ; rx_head : Signal.t
      }

    let create scope (i : Signal.t I.t) ~halted =
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
      (* an empty fifo's head is a stale word, from power-up until eight have passed *)
      let%hw rx_head = mux2 rx.empty (zero data_bits) rx.head in
      { tx; rx; tx_pop; rx_push; rx_head }
    ;;
  end

  (* The memory reads one address ahead of [word], the word at [pc]. *)
  module Fetch = struct
    type t =
      { free : Signal.t
      ; program_word : Signal.t
      ; word : Signal.t
      }

    let create
      scope
      ~spec
      ~(memory : Memory.t)
      (i : Signal.t I.t)
      (fb : Feedback.t)
      ~start
      =
      let { Feedback.halted; fetch_addr; ir_load; _ } = fb in
      (* a write or a read while the core runs would take the memory from the fetch *)
      let%hw program_write = i.program_write.valid &: halted in
      (* halted stays high through a start and the fetch of pc 0 a cycle later *)
      let%hw free = halted &: ~:(i.start |: start) in
      let%hw program_read = i.program_read.valid &: free in
      let memory_in =
        { Program_memory.I.clock = i.clocking.clock
        ; men = vdd
        ; wen = program_write
        ; ren = vdd
        ; addr =
            mux2 program_write i.program_write.addr
            @@ mux2 program_read i.program_read.value fetch_addr
        ; din = i.program_write.data
        ; bm = ones Isa.word_bits
        }
      in
      let memory =
        match memory with
        | Flops -> Program_memory.hierarchical scope memory_in
        | Ihp_sram -> Sram_macro.hierarchical scope memory_in
      in
      (* refilled after a jump or start, which is the jump's second cycle *)
      let%hw word = reg spec ~enable:ir_load memory.dout in
      { free; program_word = memory.dout; word }
    ;;
  end

  (* The core reads its own drive on the pins it drives, the outside on the rest, and on a
     wire both, ORed. *)
  let sample_pins scope (fb : Feedback.t) ~inputs =
    let { Feedback.pin_out; pin_dir; _ } = fb in
    let%hw sample =
      List.init num_pins ~f:(fun n ->
        if n >= Isa.num_pins
        then pin_out.:(n) |: inputs.:(n)
        else (
          let driven =
            if n < first_output_pin
            then gnd
            else if n < first_bidir_pin
            then vdd
            else pin_dir.:(n)
          in
          mux2 driven pin_out.:(n) inputs.:(n)))
      |> concat_lsb
    in
    sample
  ;;

  (* The decoded word at [pc], and flags registered beside it off the memory. *)
  module Instruction = struct
    type t =
      { decoded : Signal.t Decoder.Decoded.t
      ; decode_ok : Signal.t
      ; is_opcode : Signal.t list
      ; wait_select : Signal.t
      }

    let create scope ~spec (c : Signal.t Config.t) ~word ~program_word ~ir_load =
      let module D = Decoder.Make (Signal) in
      let%hw.Decoder.Decoded.Of_signal d =
        D.decode ~side_set_count:c.side_set_count word
      in
      (* decoded off the memory and registered, so register enables start from a flop;
         neither depends on the config *)
      let fetched = D.decode ~side_set_count:c.side_set_count program_word in
      let%hw decode_ok = reg spec ~enable:ir_load ~clear_to:vdd fetched.valid in
      let%hw_list is_opcode =
        List.map Isa.Opcode.Cases.all ~f:(fun op ->
          reg
            spec
            ~enable:ir_load
            ~clear_to:(of_bool (Isa.Opcode.to_int op = 0))
            (Isa.Opcode.Of_signal.is fetched.opcode op))
      in
      (* on flops of its own, away from [word]'s fanout, once the slowest path to memory *)
      let%hw wait_select =
        reg
          spec
          ~enable:ir_load
          ~clear_to:(of_unsigned_int ~width:num_pins 1)
          (binary_to_onehot fetched.wait_index |> sel_bottom ~width:num_pins)
      in
      { decoded = d; decode_ok; is_opcode; wait_select }
    ;;

    let is t op = List.nth_exn t.is_opcode (Isa.Opcode.to_int op)
    let is_sys t op = is t Sys &: Isa.Sys_op.Of_signal.is t.decoded.sys_op op
  end

  (* When a wait releases and whether a jump is taken. *)
  module Conditions = struct
    type t =
      { deadline_late : Signal.t
      ; wait_ready : Signal.t
      ; jmp_taken : Signal.t
      }

    let create
      scope
      (c : Signal.t Config.t)
      (fb : Feedback.t)
      (instruction : Instruction.t)
      (fifos : Host_fifos.t)
      ~sample
      =
      let { Feedback.now; t; x; y; osr_count; stuff_run; pins_sampled; _ } = fb in
      let { Decoder.Decoded.jmp_cond; wait_polarity; wait_source; _ } =
        instruction.decoded
      in
      let { Host_fifos.tx; rx; _ } = fifos in
      let wait_select = instruction.wait_select in
      let module Deadline = Deadline.Make (Signal) in
      let%hw deadline_ready = Deadline.release ~now ~t in
      let%hw deadline_late = Deadline.late ~now ~t in
      let%hw wait_pin_prev = pins_sampled &: wait_select <>:. 0 in
      let%hw wait_pin_cur = sample &: wait_select <>:. 0 in
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
      { deadline_late; wait_ready; jmp_taken }
    ;;
  end

  (* An instruction issues unless halted, stalled or starting, then stalls for its delay.
     A false wait reissues and re-applies its side-set. *)
  module Control = struct
    type t =
      { issue : Signal.t
      ; go : Signal.t
      ; jmp_go : Signal.t
      ; op_go : Signal.t
      ; advance : Signal.t
      }

    let create scope (fb : Feedback.t) (instruction : Instruction.t) ~start ~wait_ready =
      let is = Instruction.is instruction in
      let { Feedback.halted; stall; _ } = fb in
      let%hw issue = ~:halted &: (stall ==:. 0) &: ~:start in
      let%hw go = issue &: instruction.decode_ok in
      let%hw jmp_go = go &: is Jmp in
      let%hw op_go = go &: ~:(is Jmp) in
      let%hw wait_holds = is Wait &: ~:wait_ready in
      let%hw advance = op_go &: ~:wait_holds in
      { issue; go; jmp_go; op_go; advance }
    ;;
  end

  (* What [in] shifts into [isr] and [out] shifts out of [osr], after any autopull. *)
  module Shifter = struct
    type t =
      { in_value : Signal.t
      ; isr_shifted : Signal.t
      ; isr_count_next : Signal.t
      ; autopush_now : Signal.t
      ; pull_data : Signal.t
      ; pull_data_ok : Signal.t
      ; pull_fifo : Signal.t
      ; pull_ok : Signal.t
      ; out_value : Signal.t
      ; osr_shifted : Signal.t
      ; osr_count_next : Signal.t
      }

    let create
      scope
      (c : Signal.t Config.t)
      (fb : Feedback.t)
      (instruction : Instruction.t)
      (fifos : Host_fifos.t)
      ~sample
      ~data_word
      =
      let { Feedback.x; y; isr; isr_count; osr; osr_count; crc; capture; data_moved; _ } =
        fb
      in
      let { Decoder.Decoded.shift_count; in_source; _ } = instruction.decoded in
      let { Host_fifos.tx; _ } = fifos in
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
          ; Capture, uresize capture ~width:data_bits
          ]
        &: mask
      in
      let%hw shift_back = of_unsigned_int ~width:count_bits data_bits -: shift_count in
      let%hw isr_shifted =
        mux2
          c.in_shift_right
          (log_shift ~f:srl isr ~by:shift_count
           |: log_shift ~f:sll in_value ~by:shift_back)
          (log_shift ~f:sll isr ~by:shift_count |: in_value)
      in
      let%hw isr_count_next = saturate isr_count shift_count in
      let%hw autopush_now = c.autopush &: (isr_count_next >=: c.push_threshold) in
      let%hw pull_now = c.autopull &: (osr_count >=: c.pull_threshold) in
      (* shared memory: a pointer moved last cycle may not have its word yet, so refuse as
         if the fifo were empty *)
      let%hw pull_data = pull_now &: c.autopull_data in
      let%hw pull_data_ok = pull_data &: ~:data_moved in
      let%hw pull_fifo = pull_now &: ~:(c.autopull_data) in
      let%hw pull_ok = pull_fifo &: ~:(tx.empty) in
      let%hw osr_before = mux2 pull_data_ok data_word @@ mux2 pull_ok tx.head osr in
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
      { in_value
      ; isr_shifted
      ; isr_count_next
      ; autopush_now
      ; pull_data
      ; pull_data_ok
      ; pull_fifo
      ; pull_ok
      ; out_value
      ; osr_shifted
      ; osr_count_next
      }
    ;;
  end

  (* The CRC and the run of equal bits see every single-bit shift. *)
  module Crc_and_stuffing = struct
    type t =
      { crc_next : Signal.t
      ; stuff_run_next : Signal.t
      }

    let create
      scope
      (c : Signal.t Config.t)
      (fb : Feedback.t)
      (instruction : Instruction.t)
      ~in_value
      ~out_value
      =
      let is = Instruction.is instruction in
      let is_sys = Instruction.is_sys instruction in
      let { Feedback.crc; stuff_run; _ } = fb in
      let { Decoder.Decoded.shift_count; _ } = instruction.decoded in
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
      let%hw stuff_run_max = of_unsigned_int ~width:count_bits Isa.stuff_run_max in
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
      { crc_next; stuff_run_next }
    ;;
  end

  (* The values [mov] and [alu] read. *)
  module Operands = struct
    type t =
      { mov_value : Signal.t
      ; mov_value_t : Signal.t
      ; alu_operand : Signal.t
      }

    let create
      scope
      (c : Signal.t Config.t)
      (fb : Feedback.t)
      (instruction : Instruction.t)
      ~sample
      =
      let { Feedback.x; y; p; isr; osr; now; capture; _ } = fb in
      let { Decoder.Decoded.mov_source; mov_op; alu_is_reg; alu_imm; alu_reg; _ } =
        instruction.decoded
      in
      (* wide enough for [t] and for the data registers, whichever is wider *)
      let mov_bits = Int.max timer_bits data_bits in
      let%hw mov_value24 =
        Isa.Mov_source.Of_signal.match_
          mov_source
          [ ( Pins
            , uresize (read_pins sample ~base:c.in_base ~count:c.in_count) ~width:mov_bits
            )
          ; X, uresize x ~width:mov_bits
          ; Y, uresize y ~width:mov_bits
          ; Null, zero mov_bits
          ; Isr, uresize isr ~width:mov_bits
          ; Osr, uresize osr ~width:mov_bits
          ; Now, uresize now ~width:mov_bits
          ; Capture, uresize capture ~width:mov_bits
          ]
      in
      let%hw mov_value = mov_apply ~mov_op (uresize mov_value24 ~width:data_bits) in
      let%hw mov_value_t = mov_apply ~mov_op (uresize mov_value24 ~width:timer_bits) in
      let%hw alu_operand =
        mux2
          alu_is_reg
          (Isa.Alu_reg.Of_signal.match_
             ~default:(zero data_bits)
             alu_reg
             [ X, x; Y, y; P, p; Isr, isr; Osr, osr ])
          (uresize alu_imm ~width:data_bits)
      in
      { mov_value; mov_value_t; alu_operand }
    ;;
  end

  (* Manchester second half, then side-set, then the instruction's write *)
  module Pin_writer = struct
    type t =
      { pin_out_flipped : Signal.t
      ; manchester_out : Signal.t
      ; pin_out_next : Signal.t
      ; pin_dir_next : Signal.t
      }

    let create
      scope
      (c : Signal.t Config.t)
      (fb : Feedback.t)
      (instruction : Instruction.t)
      ~out_value
      ~mov_value
      =
      let { Feedback.pin_out; pin_dir; flip_pending; flip_bit; _ } = fb in
      let { Decoder.Decoded.opcode
          ; side_set
          ; shift_count
          ; out_dest
          ; mov_dest
          ; set_dest
          ; set_value
          ; _
          }
        =
        instruction.decoded
      in
      let side_count = uresize c.side_set_count ~width:count_bits in
      let set_count = uresize c.set_count ~width:count_bits in
      let manchester_pins = of_unsigned_int ~width:count_bits Isa.manchester_pins in
      let%hw pin_out_flipped =
        mux2
          flip_pending
          (write_pins
             pin_out
             ~base:c.out_base
             ~count:manchester_pins
             ~value:(manchester_pair ~:flip_bit)
             ~writable:output_pin)
          pin_out
      in
      let%hw pin_out_side =
        write_pins
          pin_out_flipped
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
      let%hw pin_out_base = mux2 c.side_set_pindirs pin_out_flipped pin_out_side in
      let%hw pin_dir_base = mux2 c.side_set_pindirs pin_dir_side pin_dir in
      let out_to ~base ~count ~value =
        write_pins pin_out_base ~base ~count ~value ~writable:output_pin
      in
      let dir_to ~base ~count ~value =
        write_pins pin_dir_base ~base ~count ~value ~writable:bidir_pin
      in
      let%hw manchester_out = c.manchester &: (shift_count ==:. 1) in
      let%hw pin_out_next =
        Isa.Opcode.Of_signal.match_
          ~default:pin_out_base
          opcode
          [ ( Out
            , mux2
                (Isa.Out_dest.Of_signal.is out_dest Pins)
                (mux2
                   manchester_out
                   (out_to
                      ~base:c.out_base
                      ~count:manchester_pins
                      ~value:(manchester_pair out_value.:(0)))
                   (out_to ~base:c.out_base ~count:shift_count ~value:out_value))
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
      { pin_out_flipped; manchester_out; pin_out_next; pin_dir_next }
    ;;
  end

  (* Next [x], [y] and [p], for an instruction that issues. *)
  module Data_registers = struct
    type t =
      { x_next : Signal.t
      ; y_next : Signal.t
      ; p_next : Signal.t
      }

    let create
      scope
      (fb : Feedback.t)
      (instruction : Instruction.t)
      ~out_value
      ~mov_value
      ~alu_operand
      =
      let { Feedback.x; y; p; _ } = fb in
      let { Decoder.Decoded.opcode
          ; jmp_cond
          ; out_dest
          ; mov_dest
          ; set_dest
          ; set_value
          ; alu_dest
          ; alu_op
          ; _
          }
        =
        instruction.decoded
      in
      let alu_apply = alu_apply ~alu_op ~operand:alu_operand in
      let%hw x_next =
        by_opcode
          opcode
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
          opcode
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
          opcode
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
      { x_next; y_next; p_next }
    ;;
  end

  (* Next [t] and [t_fraction]: a releasing [wait] advances the deadline by the period. *)
  module Deadline_timer = struct
    type t =
      { releases_deadline : Signal.t
      ; t_next : Signal.t
      ; t_fraction_next : Signal.t
      }

    let create
      scope
      (c : Signal.t Config.t)
      (fb : Feedback.t)
      (instruction : Instruction.t)
      ~wait_ready
      ~out_value
      ~mov_value_t
      ~alu_operand
      =
      let is = Instruction.is instruction in
      let { Feedback.t; t_fraction; p; _ } = fb in
      let { Decoder.Decoded.opcode
          ; wait_polarity
          ; wait_source
          ; out_dest
          ; mov_dest
          ; alu_dest
          ; alu_op
          ; _
          }
        =
        instruction.decoded
      in
      let alu_apply = alu_apply ~alu_op ~operand:alu_operand in
      let%hw releases_deadline =
        is Wait &: Isa.Wait_source.Of_signal.is wait_source Deadline &: wait_ready
      in
      (* the part of the period below the cycle builds up under [t] and carries into it *)
      let%hw fraction_sum =
        let wide x = uresize x ~width:(fraction_bits + 1) in
        wide t_fraction +: wide c.period_fraction
      in
      let%hw advances_deadline = releases_deadline &: wait_polarity in
      let%hw t_advanced =
        t +: uresize p ~width:timer_bits +: uresize (msb fraction_sum) ~width:timer_bits
      in
      let%hw t_next =
        by_opcode
          opcode
          ~default:t
          [ Wait, mux2 advances_deadline t_advanced t
          ; ( Out
            , mux2
                (Isa.Out_dest.Of_signal.is out_dest T)
                (uresize out_value ~width:timer_bits)
                t )
          ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest T) mov_value_t t
          ; Alu, mux2 (Isa.Alu_dest.Of_signal.is alu_dest T) (alu_apply t) t
          ]
      in
      (* any other write to [t] starts it on a whole cycle *)
      let%hw t_fraction_next =
        by_opcode
          opcode
          ~default:t_fraction
          [ Wait, mux2 advances_deadline (lsbs fraction_sum) t_fraction
          ; ( Out
            , mux2 (Isa.Out_dest.Of_signal.is out_dest T) (zero fraction_bits) t_fraction
            )
          ; ( Mov
            , mux2 (Isa.Mov_dest.Of_signal.is mov_dest T) (zero fraction_bits) t_fraction
            )
          ; ( Alu
            , mux2 (Isa.Alu_dest.Of_signal.is alu_dest T) (zero fraction_bits) t_fraction
            )
          ]
      in
      { releases_deadline; t_next; t_fraction_next }
    ;;
  end

  (* Next [isr], [osr] and their counts, for an instruction that issues. *)
  module Shift_registers = struct
    type t =
      { pushes : Signal.t
      ; pulls : Signal.t
      ; osr_next : Signal.t
      ; osr_count_next_value : Signal.t
      ; isr_next : Signal.t
      ; isr_count_next_value : Signal.t
      }

    let create
      scope
      (fb : Feedback.t)
      (instruction : Instruction.t)
      (fifos : Host_fifos.t)
      (shifter : Shifter.t)
      ~mov_value
      =
      let is = Instruction.is instruction in
      let is_sys = Instruction.is_sys instruction in
      let { Feedback.isr; isr_count; osr; osr_count; _ } = fb in
      let { Decoder.Decoded.opcode; shift_count; out_dest; mov_dest; _ } =
        instruction.decoded
      in
      let { Host_fifos.tx; _ } = fifos in
      let { Shifter.autopush_now
          ; isr_shifted
          ; isr_count_next
          ; out_value
          ; osr_shifted
          ; osr_count_next
          ; _
          }
        =
        shifter
      in
      let%hw pushes = is In &: autopush_now |: is_sys Push in
      let%hw pulls = is_sys Pull in
      let%hw osr_next =
        by_opcode
          opcode
          ~default:osr
          [ Out, osr_shifted
          ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest Osr) mov_value osr
          ; Sys, mux2 (pulls &: ~:(tx.empty)) tx.head osr
          ]
      in
      let%hw osr_count_zero = zero count_bits in
      let%hw osr_count_next_value =
        by_opcode
          opcode
          ~default:osr_count
          [ Out, osr_count_next
          ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest Osr) osr_count_zero osr_count
          ; Sys, mux2 pulls osr_count_zero osr_count
          ]
      in
      let%hw isr_next =
        by_opcode
          opcode
          ~default:isr
          [ In, mux2 autopush_now (zero data_bits) isr_shifted
          ; Out, mux2 (Isa.Out_dest.Of_signal.is out_dest Isr) out_value isr
          ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest Isr) mov_value isr
          ; Sys, mux2 (is_sys Push) (zero data_bits) isr
          ]
      in
      let%hw isr_count_next_value =
        by_opcode
          opcode
          ~default:isr_count
          [ In, mux2 autopush_now osr_count_zero isr_count_next
          ; Out, mux2 (Isa.Out_dest.Of_signal.is out_dest Isr) shift_count isr_count
          ; Mov, mux2 (Isa.Mov_dest.Of_signal.is mov_dest Isr) osr_count_zero isr_count
          ; Sys, mux2 (is_sys Push) osr_count_zero isr_count
          ]
      in
      { pushes; pulls; osr_next; osr_count_next_value; isr_next; isr_count_next_value }
    ;;
  end

  (* Next [halted], [stall] and [pc]; drives [fetch_addr] and [ir_load]. A jump always
     takes two cycles, taken or not. *)
  module Sequencer = struct
    type t =
      { halted_next : Signal.t
      ; stall_next : Signal.t
      ; pc_value_next : Signal.t
      }

    let create
      scope
      ~spec
      (c : Signal.t Config.t)
      (i : Signal.t I.t)
      (fb : Feedback.t)
      (instruction : Instruction.t)
      (control : Control.t)
      ~start
      ~pc_next
      ~jmp_target_or_next
      =
      let is_sys = Instruction.is_sys instruction in
      let { Feedback.pc; halted; stall; fetch_addr; ir_load; _ } = fb in
      let { Decoder.Decoded.delay; _ } = instruction.decoded in
      let decode_ok = instruction.decode_ok in
      let { Control.issue; jmp_go; op_go; advance; _ } = control in
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
        mux2 start (zero pc_bits)
        @@ mux2 jmp_go jmp_target_or_next
        @@ mux2 advance pc_next pc
      in
      (* sums taken off the register, so no adder follows control on the way to memory *)
      let%hw pc_after_next =
        mux2 start (address_after c (zero pc_bits))
        @@ mux2 advance (address_after c pc_next) pc_next
      in
      fetch_addr
      <-- mux2 i.start (zero pc_bits) @@ mux2 jmp_go jmp_target_or_next pc_after_next;
      let%hw refill = reg spec (jmp_go |: i.start) in
      ir_load <-- (advance |: refill);
      { halted_next; stall_next; pc_value_next }
    ;;
  end

  (* The pointer is at 0 from the start pulse on, so the word is there by the first issue. *)
  let drive_data_pointer
    scope
    ~spec
    (i : Signal.t I.t)
    (fb : Feedback.t)
    (instruction : Instruction.t)
    ~op_go
    ~start
    ~pull_data_ok
    =
    let is = Instruction.is instruction in
    let is_sys = Instruction.is_sys instruction in
    let { Feedback.x; data_ptr; data_ptr_next; data_moved; _ } = fb in
    let%hw seeks = op_go &: is_sys Seek in
    let%hw pulls_data = op_go &: is Out &: pull_data_ok in
    data_ptr_next
    <-- mux2 (i.start |: start) (zero Isa.data_addr_bits)
        @@ mux2 seeks (sel_bottom x ~width:Isa.data_addr_bits)
        @@ mux2 pulls_data (data_ptr +:. 1) data_ptr;
    data_ptr <-- reg spec data_ptr_next;
    data_moved <-- reg spec (mux2 start gnd (seeks |: pulls_data))
  ;;

  (* A jump carries no side-set, so all it does to the pins is the flip. *)
  let drive_pins
    scope
    ~spec
    (fb : Feedback.t)
    (instruction : Instruction.t)
    (control : Control.t)
    (pin_writer : Pin_writer.t)
    ~start
    ~sample
    ~out_value
    =
    let is = Instruction.is instruction in
    let { Feedback.pin_out; pin_dir; pins_sampled; flip_pending; flip_bit; _ } = fb in
    let { Decoder.Decoded.out_dest; _ } = instruction.decoded in
    let { Control.issue; op_go; _ } = control in
    let { Pin_writer.pin_out_flipped; manchester_out; pin_out_next; pin_dir_next } =
      pin_writer
    in
    pin_out
    <-- reg
          spec
          ~enable:(op_go |: (issue &: flip_pending))
          (mux2 op_go pin_out_next pin_out_flipped);
    let%hw starts_manchester_bit =
      op_go &: is Out &: Isa.Out_dest.Of_signal.is out_dest Pins &: manchester_out
    in
    flip_pending
    <-- reg
          spec
          (mux2 start gnd @@ mux2 starts_manchester_bit vdd @@ mux2 issue gnd flip_pending);
    flip_bit <-- reg spec ~enable:starts_manchester_bit out_value.:(0);
    pin_dir <-- reg spec ~enable:op_go pin_dir_next;
    pins_sampled <-- reg spec sample
  ;;

  (* Register writes show the next cycle, pin writes the cycle after issue. *)
  let create ~(memory : Memory.t) (scope : Scope.t) (i : Signal.t I.t) =
    let spec = Clocking.to_spec i.clocking in
    let c = i.config in
    let fb = Feedback.create scope in
    let { Feedback.pc
        ; x
        ; y
        ; p
        ; t
        ; t_fraction
        ; osr
        ; osr_count
        ; isr
        ; isr_count
        ; now
        ; pin_out
        ; pin_dir
        ; stall
        ; halted
        ; flip_pending
        ; flip_bit
        ; capture
        ; capture_armed
        ; crc
        ; stuff_run
        ; data_ptr
        ; data_ptr_next
        ; data_moved
        ; pins_sampled
        ; fetch_addr = _
        ; ir_load
        }
      =
      fb
    in
    let%hw start = reg spec i.start in
    let fifos = Host_fifos.create scope i ~halted in
    let { Host_fifos.tx; rx; tx_pop; rx_push; rx_head } = fifos in
    let fetch = Fetch.create scope ~spec ~memory i fb ~start in
    let sample = sample_pins scope fb ~inputs:i.inputs in
    let instruction =
      Instruction.create
        scope
        ~spec
        c
        ~word:fetch.word
        ~program_word:fetch.program_word
        ~ir_load
    in
    let is = Instruction.is instruction in
    let is_sys = Instruction.is_sys instruction in
    let { Conditions.deadline_late; wait_ready; jmp_taken } =
      Conditions.create scope c fb instruction fifos ~sample
    in
    let control = Control.create scope fb instruction ~start ~wait_ready in
    let { Control.issue; go; op_go; _ } = control in
    (* off [pc] and the config alone, so the fetch reads ahead across the wrap for free *)
    let%hw pc_next = address_after c pc in
    let%hw jmp_target_or_next = mux2 jmp_taken instruction.decoded.jmp_target pc_next in
    let shifter =
      Shifter.create scope c fb instruction fifos ~sample ~data_word:i.data_word
    in
    let { Shifter.in_value; out_value; isr_shifted; _ } = shifter in
    let { Crc_and_stuffing.crc_next; stuff_run_next } =
      Crc_and_stuffing.create scope c fb instruction ~in_value ~out_value
    in
    let { Operands.mov_value; mov_value_t; alu_operand } =
      Operands.create scope c fb instruction ~sample
    in
    let pin_writer = Pin_writer.create scope c fb instruction ~out_value ~mov_value in
    let { Data_registers.x_next; y_next; p_next } =
      Data_registers.create scope fb instruction ~out_value ~mov_value ~alu_operand
    in
    let { Deadline_timer.releases_deadline; t_next; t_fraction_next } =
      Deadline_timer.create
        scope
        c
        fb
        instruction
        ~wait_ready
        ~out_value
        ~mov_value_t
        ~alu_operand
    in
    let { Shift_registers.pushes
        ; pulls
        ; osr_next
        ; osr_count_next_value
        ; isr_next
        ; isr_count_next_value
        }
      =
      Shift_registers.create scope fb instruction fifos shifter ~mov_value
    in
    let%hw captured =
      capture_armed
      &: (pin_of sample c.capture_pin <>: pin_of pins_sampled c.capture_pin)
      &: (pin_of sample c.capture_pin ==: c.capture_rising)
    in
    let { Sequencer.halted_next; stall_next; pc_value_next } =
      Sequencer.create
        scope
        ~spec
        c
        i
        fb
        instruction
        control
        ~start
        ~pc_next
        ~jmp_target_or_next
    in
    let sticky set = reg spec ~enable:set vdd in
    let fault =
      { Fault.underflow =
          sticky
            (op_go
             &: (is Out
                 &: (shifter.pull_fifo &: tx.empty |: (shifter.pull_data &: data_moved))
                 |: (pulls &: tx.empty)))
      ; overflow = sticky (op_go &: pushes &: rx.full)
      ; missed_deadline = sticky (op_go &: releases_deadline &: deadline_late)
      ; decode = sticky (issue &: ~:(instruction.decode_ok))
      }
    in
    rx_push.valid <-- (op_go &: pushes &: ~:(rx.full));
    rx_push.value <-- mux2 (is In) isr_shifted isr;
    tx_pop <-- (op_go &: (is Out &: shifter.pull_ok |: (pulls &: ~:(tx.empty))));
    pc <-- reg spec pc_value_next;
    x <-- reg spec ~enable:go x_next;
    y <-- reg spec ~enable:go y_next;
    p <-- reg spec ~enable:go p_next;
    t <-- reg spec ~enable:go t_next;
    t_fraction <-- reg spec ~enable:go t_fraction_next;
    drive_data_pointer
      scope
      ~spec
      i
      fb
      instruction
      ~op_go
      ~start
      ~pull_data_ok:shifter.pull_data_ok;
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
    drive_pins scope ~spec fb instruction control pin_writer ~start ~sample ~out_value;
    stall <-- reg spec stall_next;
    halted <-- reg spec ~clear_to:vdd halted_next;
    capture <-- reg spec ~enable:captured now;
    crc <-- reg spec (mux2 start c.crc_init @@ mux2 go crc_next crc);
    stuff_run
    <-- reg spec (mux2 start (zero count_bits) @@ mux2 go stuff_run_next stuff_run);
    capture_armed
    <-- reg
          spec
          (mux2 captured gnd @@ mux2 (op_go &: is_sys Capture_arm) vdd capture_armed);
    let%hw irq =
      reg_fb spec ~width:1 ~f:(fun d ->
        mux2 (op_go &: is_sys Irq) vdd @@ mux2 i.clear_irq gnd d)
    in
    { O.pin_out
    ; pin_dir
    ; pc
    ; data_ptr
    ; data_addr = data_ptr_next
    ; x
    ; y
    ; p
    ; t
    ; t_fraction
    ; osr
    ; osr_count
    ; isr
    ; isr_count
    ; now
    ; stall
    ; halted
    ; free = fetch.free
    ; irq
    ; fault
    ; capture
    ; capture_armed
    ; tx_level = tx.level
    ; rx_level = rx.level
    ; rx_head
    ; instruction = fetch.word
    ; program_word = fetch.program_word
    ; decode_ok = instruction.decode_ok
    ; opcode_onehot = concat_lsb instruction.is_opcode
    ; wait_select = instruction.wait_select
    ; crc
    ; stuff_run
    ; flip_pending
    ; flip_bit
    }
  ;;

  let hierarchical ?instance ~memory scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"engine" (create ~memory) i
  ;;
end

include Make (Isa)
