open! Core
open! Hardcaml

module Decoded = struct
  type 'a t =
    { valid : 'a
    ; opcode : 'a Isa.Opcode.t
    ; delay : 'a [@bits Isa.delay_bits]
    ; side_set : 'a [@bits 2]
    ; jmp_cond : 'a Isa.Jmp_cond.t
    ; jmp_target : 'a [@bits Isa.pc_bits]
    ; wait_polarity : 'a
    ; wait_source : 'a Isa.Wait_source.t
    ; wait_index : 'a [@bits Isa.Field.wait_index.width]
    ; shift_count : 'a [@bits Isa.Field.shift_count.width]
    ; in_source : 'a Isa.In_source.t
    ; out_dest : 'a Isa.Out_dest.t
    ; mov_dest : 'a Isa.Mov_dest.t
    ; mov_op : 'a Isa.Mov_op.t
    ; mov_source : 'a Isa.Mov_source.t
    ; set_dest : 'a Isa.Set_dest.t
    ; set_value : 'a [@bits Isa.Field.set_value.width]
    ; alu_dest : 'a Isa.Alu_dest.t
    ; alu_op : 'a Isa.Alu_op.t
    ; alu_is_reg : 'a
    ; alu_imm : 'a [@bits Isa.Field.alu_operand.width]
    ; alu_reg : 'a Isa.Alu_reg.t
    ; sys_op : 'a Isa.Sys_op.t
    }
  [@@deriving hardcaml]
end

module Make (Comb : Comb.S) = struct
  open Comb
  module Opcode = Isa.Opcode.Make_comb (Comb)
  module Jmp_cond = Isa.Jmp_cond.Make_comb (Comb)
  module Wait_source = Isa.Wait_source.Make_comb (Comb)
  module In_source = Isa.In_source.Make_comb (Comb)
  module Out_dest = Isa.Out_dest.Make_comb (Comb)
  module Mov_dest = Isa.Mov_dest.Make_comb (Comb)
  module Mov_op = Isa.Mov_op.Make_comb (Comb)
  module Mov_source = Isa.Mov_source.Make_comb (Comb)
  module Set_dest = Isa.Set_dest.Make_comb (Comb)
  module Alu_dest = Isa.Alu_dest.Make_comb (Comb)
  module Alu_op = Isa.Alu_op.Make_comb (Comb)
  module Alu_reg = Isa.Alu_reg.Make_comb (Comb)
  module Sys_op = Isa.Sys_op.Make_comb (Comb)

  let valid_code (type a) (module E : Isa.Enum with type Cases.t = a) raw =
    let n = List.length E.Cases.all in
    if n = 1 lsl width raw then vdd else raw <:. n
  ;;

  let decode ~side_set_count word =
    let field f = Isa.Field.select (module Comb) f word in
    let opcode = Opcode.of_raw (field Isa.Field.op) in
    let delay_side = field Isa.Field.delay_side in
    let delay =
      mux
        side_set_count
        [ delay_side; delay_side &:. 0xf; delay_side &:. 0x7; delay_side &:. 0x7 ]
    in
    let side_set =
      mux
        side_set_count
        [ zero 2
        ; uresize delay_side.:[4, 4] ~width:2
        ; delay_side.:[4, 3]
        ; delay_side.:[4, 3]
        ]
    in
    let jmp_target = field Isa.Field.jmp_target in
    let wait_source = Wait_source.of_raw (field Isa.Field.wait_source) in
    let wait_index = field Isa.Field.wait_index in
    let shift_target = field Isa.Field.shift_target in
    let shift_count = field Isa.Field.shift_count in
    let mov_op_raw = field Isa.Field.mov_op in
    let set_dest_raw = field Isa.Field.set_dest in
    let alu_op_raw = field Isa.Field.alu_op in
    let alu_is_reg = field Isa.Field.alu_is_reg in
    let alu_operand_raw = field Isa.Field.alu_operand in
    let wait_index_ok =
      Wait_source.match_
        wait_source
        [ Pin_level, wait_index <:. Isa.pin_space
        ; Pin_edge, wait_index <:. Isa.pin_space
        ; Deadline, wait_index ==:. 0
        ; Fifo, wait_index ==:. 0
        ]
    in
    let count_ok = shift_count >=:. 1 &: (shift_count <=:. Isa.max_shift_count) in
    let valid =
      Opcode.match_
        opcode
        [ Jmp, valid_code (module Isa.Jmp_cond) (field Isa.Field.jmp_cond)
        ; Wait, wait_index_ok
        ; In, count_ok
        ; Out, count_ok
        ; Mov, valid_code (module Isa.Mov_op) mov_op_raw
        ; Set, valid_code (module Isa.Set_dest) set_dest_raw
        ; ( Alu
          , valid_code (module Isa.Alu_op) alu_op_raw
            &: (~:alu_is_reg |: valid_code (module Isa.Alu_reg) alu_operand_raw) )
        ; Sys, word.:[7, Isa.Field.sys_op.width] ==:. 0
        ]
    in
    { Decoded.valid
    ; opcode
    ; delay
    ; side_set
    ; jmp_cond = Jmp_cond.of_raw (field Isa.Field.jmp_cond)
    ; jmp_target
    ; wait_polarity = field Isa.Field.wait_polarity
    ; wait_source
    ; wait_index
    ; shift_count
    ; in_source = In_source.of_raw shift_target
    ; out_dest = Out_dest.of_raw shift_target
    ; mov_dest = Mov_dest.of_raw (field Isa.Field.mov_dest)
    ; mov_op = Mov_op.of_raw mov_op_raw
    ; mov_source = Mov_source.of_raw (field Isa.Field.mov_source)
    ; set_dest = Set_dest.of_raw set_dest_raw
    ; set_value = field Isa.Field.set_value
    ; alu_dest = Alu_dest.of_raw (field Isa.Field.alu_dest)
    ; alu_op = Alu_op.of_raw alu_op_raw
    ; alu_is_reg
    ; alu_imm = alu_operand_raw
    ; alu_reg = Alu_reg.of_raw alu_operand_raw
    ; sys_op = Sys_op.of_raw (field Isa.Field.sys_op)
    }
  ;;
end
