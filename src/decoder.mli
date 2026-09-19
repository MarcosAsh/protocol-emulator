(** Decode over any [Comb], so the core and the tests share one circuit. [valid] is low
    exactly when [Isa.of_word] fails. *)

open! Core
open! Hardcaml

module Decoded : sig
  type 'a t =
    { valid : 'a
    ; opcode : 'a Isa.Opcode.t
    ; delay : 'a
    ; side_set : 'a
    ; jmp_cond : 'a Isa.Jmp_cond.t
    ; jmp_target : 'a
    ; wait_polarity : 'a
    ; wait_source : 'a Isa.Wait_source.t
    ; wait_index : 'a
    ; shift_count : 'a
    ; in_source : 'a Isa.In_source.t
    ; out_dest : 'a Isa.Out_dest.t
    ; mov_dest : 'a Isa.Mov_dest.t
    ; mov_op : 'a Isa.Mov_op.t
    ; mov_source : 'a Isa.Mov_source.t
    ; set_dest : 'a Isa.Set_dest.t
    ; set_value : 'a
    ; alu_dest : 'a Isa.Alu_dest.t
    ; alu_op : 'a Isa.Alu_op.t
    ; alu_is_reg : 'a
    ; alu_imm : 'a
    ; alu_reg : 'a Isa.Alu_reg.t
    ; sys_op : 'a Isa.Sys_op.t
    }
  [@@deriving hardcaml]
end

module Make (Comb : Comb.S) : sig
  val decode : side_set_count:Comb.t -> Comb.t -> Comb.t Decoded.t
end
