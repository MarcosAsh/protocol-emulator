(** Frumbleglide, FGL-0 Clockless Telemetry Link revision 0.9: one wire, LNK, six cells of
    preamble then sixteen bits MSB first, each cell's mid-point transition its bit. *)

open! Core
open Protocol_emulator

(** LNK, which the firmware drives. *)
val pin : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

(** What the scenario and the bench send. *)
val words : int list

val bench : Bench.t
val limits : Datasheet.t list

(** Each frame's mid-cell transitions, in cycles from the run's start, from LNK's levels. *)
val mids : clock_hz:int -> (bool * int) list -> int list list

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
