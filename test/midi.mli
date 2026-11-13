(** A MIDI 1.0 transmitter on OUT0, after the MMA's CA-033 "MIDI 1.0 Electrical
    Specification Update" (2014): 31.25 kbaud, a start bit, 8 data bits LSB first and a
    stop bit, so a byte takes 320 us. The pin is the UART side, ahead of the current-loop
    buffer. *)

open! Core
open Protocol_emulator

(** OUT0. *)
val pin : int

(** The bit in cycles, which the host loads first. *)
val period : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

(** The scenario's messages, status byte first, the second without one (running status). *)
val messages : int list list

val bench : Bench.t
val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
