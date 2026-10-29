(** A straight line program that issues every [mov] and every [alu] operand combination
    once, which random programs rarely reach. The rest of the memory jumps back to the
    start. *)

open! Core

val words : int list
