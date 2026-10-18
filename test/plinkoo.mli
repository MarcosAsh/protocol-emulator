(** plinkoo, TODO: what it is and the spec this file follows, with its revision. *)

open! Core
open Protocol_emulator

(** The line the firmware drives. *)
val pin : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
