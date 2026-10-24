(** A MICROWIRE controller, after National Semiconductor AN-452 (January 1992): CS active
    high, SK at 154.8 kHz, DI moved after SK's fall, DO sampled after it. Its timing meets
    every column of Table I, the NM93C06A's notes and the COP420's SK period. *)

open! Core
open Protocol_emulator

(** OUT4, OUT5, OUT6 and IN0, the bench's flash pins. *)
val di : int

val sk : int
val cs : int
val do_ : int

(** SK's high and low, in cycles. *)
val half : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

(** The host's words for a frame of [bits], MSB first: a header, then 16 bits a word. An
    [erase_write] frame holds CS low 25.94 ms after it, then a status window. Each frame
    pushes the last 16 bits sampled from DO. *)
val frame : ?erase_write:bool -> bool list -> int list

val ewen : int list

(** The 9 instruction bits, then 16 clocks for the data. *)
val read : int -> int list

val write : int -> int -> int list

module Eeprom : sig
  type t

  val create : unit -> t
  val step : t -> cs:bool -> sk:bool -> di:bool -> t
  val dout : t -> bool
  val registers : t -> int list

  (** Each instruction as it was taken, and each erase/write as it was done. *)
  val log : t -> string list

  val violations : t -> string list
end

val bench : Bench.t
val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
