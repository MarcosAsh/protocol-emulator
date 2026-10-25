(** Snorble, SNB-1 Snorble Sensor Beacon Rev. C: one byte a frame on SIG, a sync, eight
    bits MSB first and odd parity, each a low whose width is the bit. *)

open! Core
open Protocol_emulator

(** SIG, which the firmware drives. *)
val pin : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

(** What the scenario and the bench send. *)
val bytes : int list

val bench : Bench.t
val limits : Datasheet.t list

(** Each frame's byte and whether its nine bits have odd parity, from SIG's levels. *)
val decode : clock_hz:int -> (bool * int) list -> (int * bool) list

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
