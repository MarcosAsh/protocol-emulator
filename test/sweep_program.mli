(** A straight line program that issues every [mov] and every [alu] operand combination
    once, which sixteen random programs come nowhere near: the coverage table showed them
    reaching 53 of the 192 moves and 27 of the 72 alu forms. The rest of the memory jumps
    back to the start. *)

open! Core

val words : int list
