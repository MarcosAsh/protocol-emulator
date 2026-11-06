(** DMX512 transmitter: a packet of break, mark after break, start code and 512 channels
    at 250 kbit/s. Limits from Wikipedia's DMX512, oldid 1380777110. *)

open! Core
open Protocol_emulator

(** The line the firmware drives. *)
val pin : int

(** A bit in cycles at 48 MHz. *)
val period : int

val config : Program_config.t

(** The host's words for a packet: the start code, then the channels two per word, low byte
    first. Raises unless there are 512. *)
val packet : start_code:int -> int list -> int list

val channels : int list

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
