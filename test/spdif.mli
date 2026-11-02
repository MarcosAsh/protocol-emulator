(** An S/PDIF transmitter: stereo 16-bit samples at 44.1 kHz, biphase mark, B every 192
    frames, silence when the host has none. Wikipedia's S/PDIF, revision 1378032122. *)

open! Core
open Protocol_emulator

(** The line the firmware drives. *)
val pin : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
