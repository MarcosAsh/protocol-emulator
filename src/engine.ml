open! Core
open! Hardcaml
open! Signal

let num_pins = Isa.num_pins
let pin_bits = Int.ceil_log2 num_pins
let first_output_pin = 5
let first_bidir_pin = 12

module Config = struct
  type 'a t =
    { side_set_count : 'a [@bits 2]
    ; side_set_base : 'a [@bits pin_bits]
    ; side_set_pindirs : 'a
    ; in_base : 'a [@bits pin_bits]
    ; out_base : 'a [@bits pin_bits]
    ; out_count : 'a [@bits 5]
    ; set_base : 'a [@bits pin_bits]
    ; set_count : 'a [@bits 3]
    ; jmp_pin : 'a [@bits pin_bits]
    ; capture_pin : 'a [@bits pin_bits]
    ; capture_rising : 'a
    ; in_shift_right : 'a
    ; out_shift_right : 'a
    ; autopush : 'a
    ; push_threshold : 'a [@bits 5]
    ; autopull : 'a
    ; pull_threshold : 'a [@bits 5]
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
    ; out_base = int pin_bits c.out_base
    ; out_count = int 5 c.out_count
    ; set_base = int pin_bits c.set_base
    ; set_count = int 3 c.set_count
    ; jmp_pin = int pin_bits c.jmp_pin
    ; capture_pin = int pin_bits c.capture_pin
    ; capture_rising = bool c.capture_rising
    ; in_shift_right = right c.in_shift
    ; out_shift_right = right c.out_shift
    ; autopush = bool c.autopush
    ; push_threshold = int 5 c.push_threshold
    ; autopull = bool c.autopull
    ; pull_threshold = int 5 c.pull_threshold
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

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; config : 'a Config.t
    ; start : 'a
    ; program_write : 'a Program_write.t
    ; tx : 'a With_valid.t [@bits Isa.data_bits]
    ; rx_pop : 'a
    ; clear_irq : 'a
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
    ; osr_count : 'a [@bits 5]
    ; isr : 'a [@bits Isa.data_bits]
    ; isr_count : 'a [@bits 5]
    ; now : 'a [@bits Isa.timer_bits]
    ; stall : 'a [@bits 5]
    ; halted : 'a
    ; irq : 'a
    ; fault : 'a Fault.t
    ; capture : 'a [@bits Isa.timer_bits]
    ; capture_armed : 'a
    ; tx_level : 'a [@bits Host_fifo.level_bits]
    ; rx_level : 'a [@bits Host_fifo.level_bits]
    ; rx_head : 'a [@bits Isa.data_bits]
    }
  [@@deriving hardcaml]
end

let data_bits = Isa.data_bits
let timer_bits = Isa.timer_bits
let pc_bits = Isa.pc_bits

let pin_index base j =
  let s = uresize base ~width:(pin_bits + 1) +:. j in
  mux2 (s >=:. num_pins) (s -:. num_pins) s |> sel_bottom ~width:pin_bits
;;

let bits_of v = List.init (width v) ~f:(fun i -> v.:(i))

let read_pins sample ~base ~count =
  List.init data_bits ~f:(fun j ->
    let hit = of_unsigned_int ~width:(width count) j <: count in
    hit &: mux (pin_index base j) (bits_of sample))
  |> concat_lsb
;;

let write_pins old ~base ~count ~value ~writable =
  let value = uresize value ~width:data_bits in
  List.init num_pins ~f:(fun i ->
    let below = base >:. i in
    let j =
      mux2
        below
        (of_unsigned_int ~width:(pin_bits + 1) (i + num_pins)
         -: uresize base ~width:(pin_bits + 1))
        (of_unsigned_int ~width:(pin_bits + 1) i -: uresize base ~width:(pin_bits + 1))
    in
    let hit = j <: uresize count ~width:(pin_bits + 1) &: of_bool (writable i) in
    mux2 hit (mux (sel_bottom j ~width:4) (bits_of value)) old.:(i))
  |> concat_lsb
;;

let count_mask count = ~:(log_shift ~f:sll (ones data_bits) ~by:count)

let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let c = i.config in
  let%hw_var pc = Always.Variable.reg spec ~width:pc_bits in
  let%hw_var x = Always.Variable.reg spec ~width:data_bits in
  let%hw_var y = Always.Variable.reg spec ~width:data_bits in
  let%hw_var p = Always.Variable.reg spec ~width:data_bits in
  let%hw_var t = Always.Variable.reg spec ~width:timer_bits in
  let%hw_var osr = Always.Variable.reg spec ~width:data_bits in
  let%hw_var osr_count =
    Always.Variable.reg spec ~clear_to:(of_unsigned_int ~width:5 data_bits) ~width:5
  in
  let%hw_var isr = Always.Variable.reg spec ~width:data_bits in
  let%hw_var isr_count = Always.Variable.reg spec ~width:5 in
  let%hw_var now = Always.Variable.reg spec ~width:timer_bits in
  let%hw_var pin_out = Always.Variable.reg spec ~width:num_pins in
  let%hw_var pin_dir = Always.Variable.reg spec ~width:num_pins in
  let%hw_var pins_sampled = Always.Variable.reg spec ~width:num_pins in
  let%hw_var stall = Always.Variable.reg spec ~width:5 in
  let%hw_var halted = Always.Variable.reg spec ~clear_to:vdd ~width:1 in
  let%hw_var irq = Always.Variable.reg spec ~width:1 in
  let%hw_var capture = Always.Variable.reg spec ~width:timer_bits in
  let%hw_var capture_armed = Always.Variable.reg spec ~width:1 in
  let%hw_var fault_underflow = Always.Variable.reg spec ~width:1 in
  let%hw_var fault_overflow = Always.Variable.reg spec ~width:1 in
  let%hw_var fault_missed = Always.Variable.reg spec ~width:1 in
  let%hw_var fault_decode = Always.Variable.reg spec ~width:1 in
  let%hw_var rx_push = Always.Variable.wire ~default:gnd () in
  let%hw_var rx_push_data = Always.Variable.wire ~default:(zero data_bits) () in
  let%hw_var tx_pop = Always.Variable.wire ~default:gnd () in
  let%hw_var fetch_addr = Always.Variable.wire ~default:pc.value () in
  let tx =
    Host_fifo.hierarchical
      ~instance:"tx"
      scope
      { clocking = i.clocking; push = i.tx; pop = tx_pop.value }
  in
  let rx =
    Host_fifo.hierarchical
      ~instance:"rx"
      scope
      { clocking = i.clocking
      ; push = { valid = rx_push.value; value = rx_push_data.value }
      ; pop = i.rx_pop
      }
  in
  let memory =
    Program_memory.hierarchical
      scope
      { clock = i.clocking.clock
      ; men = vdd
      ; wen = i.program_write.valid
      ; ren = vdd
      ; addr = mux2 i.program_write.valid i.program_write.addr fetch_addr.value
      ; din = i.program_write.data
      ; bm = ones Isa.word_bits
      }
  in
  let%hw word = memory.dout in
  let%hw sample =
    List.init num_pins ~f:(fun n ->
      let driven =
        if n < first_output_pin
        then gnd
        else if n < first_bidir_pin
        then vdd
        else pin_dir.value.:(n)
      in
      mux2 driven pin_out.value.:(n) i.inputs.:(n))
    |> concat_lsb
  in
  let pin_of sig_ idx = mux idx (bits_of sig_) in
  let module D = Decoder.Make (Signal) in
  let%hw.Decoder.Decoded.Of_signal d = D.decode ~side_set_count:c.side_set_count word in
  let opcode = d.opcode in
  let is op = Isa.Opcode.Of_signal.is opcode op in
  let delay = d.delay in
  let side_set = d.side_set in
  let jmp_cond = d.jmp_cond in
  let jmp_target = d.jmp_target in
  let wait_polarity = d.wait_polarity in
  let wait_source = d.wait_source in
  let wait_index = d.wait_index in
  let shift_count = d.shift_count in
  let in_source = d.in_source in
  let out_dest = d.out_dest in
  let mov_dest = d.mov_dest in
  let mov_op = d.mov_op in
  let mov_source = d.mov_source in
  let set_dest = d.set_dest in
  let set_value = d.set_value in
  let alu_dest = d.alu_dest in
  let alu_op = d.alu_op in
  let alu_is_reg = d.alu_is_reg in
  let alu_imm = d.alu_imm in
  let alu_reg = d.alu_reg in
  let sys_op = d.sys_op in
  let decode_ok = d.valid in
  let%hw phase = now.value -: t.value in
  let%hw deadline_ready = ~:(msb phase) in
  let%hw deadline_late = deadline_ready &: (phase <>:. 0) in
  let%hw wait_pin_prev = pin_of pins_sampled.value wait_index in
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
      ; X_dec, x.value <>:. 0
      ; Y_dec, y.value <>:. 0
      ; X_ne_y, x.value <>: y.value
      ; Pin, pin_of sample c.jmp_pin
      ; Not_pin, ~:(pin_of sample c.jmp_pin)
      ; Osr_not_empty, osr_count.value <: c.pull_threshold
      ; Stuff_pending, gnd
      ]
  in
  let%hw issue = ~:(halted.value) &: (stall.value ==:. 0) in
  let%hw pc_next = pc.value +:. 1 in
  let%hw wait_holds = is Wait &: ~:wait_ready in
  let%hw mask = count_mask shift_count in
  let%hw in_value =
    Isa.In_source.Of_signal.match_
      in_source
      [ Pins, read_pins sample ~base:c.in_base ~count:shift_count
      ; X, x.value
      ; Y, y.value
      ; Null, zero data_bits
      ; Isr, isr.value
      ; Osr, osr.value
      ; Crc, zero data_bits
      ; Capture, sel_bottom capture.value ~width:data_bits
      ]
    &: mask
  in
  let%hw shift_back = of_unsigned_int ~width:5 data_bits -: shift_count in
  let%hw isr_shifted =
    mux2
      c.in_shift_right
      (log_shift ~f:srl isr.value ~by:shift_count
       |: log_shift ~f:sll in_value ~by:shift_back)
      (log_shift ~f:sll isr.value ~by:shift_count |: in_value)
  in
  let saturate a b =
    let s = uresize a ~width:6 +: uresize b ~width:6 in
    mux2 (s >:. data_bits) (of_unsigned_int ~width:5 data_bits) (sel_bottom s ~width:5)
  in
  let%hw isr_count_next = saturate isr_count.value shift_count in
  let%hw autopush_now = c.autopush &: (isr_count_next >=: c.push_threshold) in
  let%hw pull_now = c.autopull &: (osr_count.value >=: c.pull_threshold) in
  let%hw pull_ok = pull_now &: ~:(tx.empty) in
  let%hw osr_before = mux2 pull_ok tx.head osr.value in
  let%hw osr_count_before = mux2 pull_now (zero 5) osr_count.value in
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
  let%hw mov_value24 =
    Isa.Mov_source.Of_signal.match_
      mov_source
      [ ( Pins
        , uresize
            (read_pins sample ~base:c.in_base ~count:(of_unsigned_int ~width:5 data_bits))
            ~width:timer_bits )
      ; X, uresize x.value ~width:timer_bits
      ; Y, uresize y.value ~width:timer_bits
      ; Null, zero timer_bits
      ; Isr, uresize isr.value ~width:timer_bits
      ; Osr, uresize osr.value ~width:timer_bits
      ; Now, now.value
      ; Capture, capture.value
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
         [ X, x.value; Y, y.value; P, p.value; Isr, isr.value; Osr, osr.value ])
      (uresize alu_imm ~width:data_bits)
  in
  let alu_apply v =
    let operand = uresize alu_operand ~width:(width v) in
    Isa.Alu_op.Of_signal.match_
      ~default:v
      alu_op
      [ Add, v +: operand; Sub, v -: operand; Xor, v ^: operand ]
  in
  let%hw alu_x = alu_apply x.value in
  let%hw alu_y = alu_apply y.value in
  let%hw alu_p = alu_apply p.value in
  let%hw alu_t = alu_apply t.value in
  let output_pin n = n >= first_output_pin in
  let bidir_pin n = n >= first_bidir_pin in
  let side_count = uresize c.side_set_count ~width:5 in
  (* side-set first, then the instruction's own pin write *)
  let%hw pin_out_side =
    write_pins
      pin_out.value
      ~base:c.side_set_base
      ~count:side_count
      ~value:side_set
      ~writable:output_pin
  in
  let%hw pin_dir_side =
    write_pins
      pin_dir.value
      ~base:c.side_set_base
      ~count:side_count
      ~value:side_set
      ~writable:bidir_pin
  in
  let%hw pin_out_base = mux2 c.side_set_pindirs pin_out.value pin_out_side in
  let%hw pin_dir_base = mux2 c.side_set_pindirs pin_dir_side pin_dir.value in
  let write_out ~base ~count ~value =
    Always.(pin_out <-- write_pins pin_out_base ~base ~count ~value ~writable:output_pin)
  in
  let write_dir ~base ~count ~value =
    Always.(pin_dir <-- write_pins pin_dir_base ~base ~count ~value ~writable:bidir_pin)
  in
  let set_count = uresize c.set_count ~width:5 in
  let push_isr value =
    Always.
      [ if_ rx.full [ fault_overflow <-- vdd ] [ rx_push <-- vdd; rx_push_data <-- value ]
      ; isr <-- zero data_bits
      ; isr_count <-- zero 5
      ]
  in
  let pull_osr =
    Always.
      [ if_ tx.empty [ fault_underflow <-- vdd ] [ osr <-- tx.head; tx_pop <-- vdd ]
      ; osr_count <-- zero 5
      ]
  in
  let advance = Always.[ pc <-- pc_next; stall <-- delay ] in
  let%hw captured =
    capture_armed.value
    &: (pin_of sample c.capture_pin <>: pin_of pins_sampled.value c.capture_pin)
    &: (pin_of sample c.capture_pin ==: c.capture_rising)
  in
  Always.(
    compile
      [ now <-- now.value +:. 1
      ; pins_sampled <-- sample
      ; when_ i.clear_irq [ irq <-- gnd ]
      ; when_ (stall.value <>:. 0) [ stall <-- stall.value -:. 1 ]
      ; when_
          issue
          [ if_
              ~:decode_ok
              [ fault_decode <-- vdd; halted <-- vdd ]
              [ if_
                  (is Jmp)
                  [ pc <-- mux2 jmp_taken jmp_target pc_next
                  ; fetch_addr <-- mux2 jmp_taken jmp_target pc_next
                  ; stall <-- of_unsigned_int ~width:5 (Isa.jmp_cycles - 1)
                  ; Isa.Jmp_cond.Of_always.match_
                      ~default:[]
                      jmp_cond
                      [ X_dec, [ x <-- x.value -:. 1 ]; Y_dec, [ y <-- y.value -:. 1 ] ]
                  ]
                  [ pin_out <-- pin_out_base
                  ; pin_dir <-- pin_dir_base
                  ; fetch_addr <-- mux2 wait_holds pc.value pc_next
                  ; Isa.Opcode.Of_always.match_
                      ~default:[]
                      opcode
                      [ ( Wait
                        , [ when_
                              wait_ready
                              (advance
                               @ [ Isa.Wait_source.Of_always.match_
                                     ~default:[]
                                     wait_source
                                     [ ( Deadline
                                       , [ when_ deadline_late [ fault_missed <-- vdd ]
                                         ; when_
                                             wait_polarity
                                             [ t
                                               <-- t.value
                                                   +: uresize p.value ~width:timer_bits
                                             ]
                                         ] )
                                     ]
                                 ])
                          ] )
                      ; ( In
                        , advance
                          @ [ if_
                                autopush_now
                                (push_isr isr_shifted)
                                [ isr <-- isr_shifted; isr_count <-- isr_count_next ]
                            ] )
                      ; ( Out
                        , advance
                          @ [ when_ pull_ok [ tx_pop <-- vdd ]
                            ; when_ (pull_now &: tx.empty) [ fault_underflow <-- vdd ]
                            ; osr <-- osr_shifted
                            ; osr_count <-- osr_count_next
                            ; Isa.Out_dest.Of_always.match_
                                ~default:[]
                                out_dest
                                [ ( Pins
                                  , [ write_out
                                        ~base:c.out_base
                                        ~count:shift_count
                                        ~value:out_value
                                    ] )
                                ; X, [ x <-- out_value ]
                                ; Y, [ y <-- out_value ]
                                ; ( Pindirs
                                  , [ write_dir
                                        ~base:c.out_base
                                        ~count:shift_count
                                        ~value:out_value
                                    ] )
                                ; Isr, [ isr <-- out_value; isr_count <-- shift_count ]
                                ; P, [ p <-- out_value ]
                                ; T, [ t <-- uresize out_value ~width:timer_bits ]
                                ]
                            ] )
                      ; ( Mov
                        , advance
                          @ [ Isa.Mov_dest.Of_always.match_
                                ~default:[]
                                mov_dest
                                [ ( Pins
                                  , [ write_out
                                        ~base:c.out_base
                                        ~count:c.out_count
                                        ~value:mov_value
                                    ] )
                                ; X, [ x <-- mov_value ]
                                ; Y, [ y <-- mov_value ]
                                ; ( Pindirs
                                  , [ write_dir
                                        ~base:c.out_base
                                        ~count:c.out_count
                                        ~value:mov_value
                                    ] )
                                ; Isr, [ isr <-- mov_value; isr_count <-- zero 5 ]
                                ; Osr, [ osr <-- mov_value; osr_count <-- zero 5 ]
                                ; P, [ p <-- mov_value ]
                                ; T, [ t <-- mov_value_t ]
                                ]
                            ] )
                      ; ( Set
                        , advance
                          @ [ Isa.Set_dest.Of_always.match_
                                ~default:[]
                                set_dest
                                [ ( Pins
                                  , [ write_out
                                        ~base:c.set_base
                                        ~count:set_count
                                        ~value:set_value
                                    ] )
                                ; X, [ x <-- uresize set_value ~width:data_bits ]
                                ; Y, [ y <-- uresize set_value ~width:data_bits ]
                                ; ( Pindirs
                                  , [ write_dir
                                        ~base:c.set_base
                                        ~count:set_count
                                        ~value:set_value
                                    ] )
                                ; P, [ p <-- uresize set_value ~width:data_bits ]
                                ]
                            ] )
                      ; ( Alu
                        , advance
                          @ [ Isa.Alu_dest.Of_always.match_
                                ~default:[]
                                alu_dest
                                [ X, [ x <-- alu_x ]
                                ; Y, [ y <-- alu_y ]
                                ; P, [ p <-- alu_p ]
                                ; T, [ t <-- alu_t ]
                                ]
                            ] )
                      ; ( Sys
                        , advance
                          @ [ Isa.Sys_op.Of_always.match_
                                ~default:[]
                                sys_op
                                [ Halt, [ halted <-- vdd ]
                                ; Irq, [ irq <-- vdd ]
                                ; Push, push_isr isr.value
                                ; Pull, pull_osr
                                ; Capture_arm, [ capture_armed <-- vdd ]
                                ]
                            ] )
                      ]
                  ]
              ]
          ]
      ; when_ captured [ capture <-- now.value; capture_armed <-- gnd ]
      ; when_
          i.start
          [ pc <-- zero pc_bits
          ; fetch_addr <-- zero pc_bits
          ; halted <-- gnd
          ; stall <-- zero 5
          ; now <-- zero timer_bits
          ]
      ]);
  { O.pin_out = pin_out.value
  ; pin_dir = pin_dir.value
  ; pc = pc.value
  ; x = x.value
  ; y = y.value
  ; p = p.value
  ; t = t.value
  ; osr = osr.value
  ; osr_count = osr_count.value
  ; isr = isr.value
  ; isr_count = isr_count.value
  ; now = now.value
  ; stall = stall.value
  ; halted = halted.value
  ; irq = irq.value
  ; fault =
      { underflow = fault_underflow.value
      ; overflow = fault_overflow.value
      ; missed_deadline = fault_missed.value
      ; decode = fault_decode.value
      }
  ; capture = capture.value
  ; capture_armed = capture_armed.value
  ; tx_level = tx.level
  ; rx_level = rx.level
  ; rx_head = rx.head
  }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"engine" create i
;;
