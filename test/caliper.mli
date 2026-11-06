(** The scale end of the Chinese digital scales' serial output: two 24-bit position words,
    LSB first, on a clock of about 90 kHz. Follows page 1 of "Chinese Scales" (the spec
    has no revision). *)

open! Core
open Protocol_emulator

(** The clock's pin; the data is on the next. *)
val pin : int

(** The clock's half period in cycles, which the host loads before any frame. *)
val half_period : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
