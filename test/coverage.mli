(** Functional coverage of the instruction set: which opcodes and operand kinds the model
    has issued, with every jump seen taken and untaken and every wait seen both held and
    released. It only watches the model from outside, decoding the word at [pc] whenever a
    step issues one. *)

open! Core
open Protocol_emulator

type t

val create : unit -> t

(** [after] is [Machine.step before]. An instruction was issued when [before] was neither
    halted nor stalled. A jump whose target is also where it falls through to tells
    nothing about which way it went and is not counted. *)
val record : t -> before:Machine.t -> after:Machine.t -> unit

(** Per group, how many points were hit out of how many, and the ones that never were. *)
val print_holes : t -> unit
