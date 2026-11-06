(** LFAST (NXP AN5134 Rev. 0, "Introduction to the Zipwire Interface"): a 33-bit frame of
    sync, header, payload and stop bit on one pin. *)

open! Core
open Protocol_emulator

(** The line the firmware drives. *)
val pin : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
