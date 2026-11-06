(** A Wiegand card reader's output, DATA0 and DATA1, after Wikipedia's "Wiegand
    interface" (oldid 1374164469), which gives the lines and the 26-bit format but no
    timing. *)

open! Core
open Protocol_emulator

(** DATA0; DATA1 is the next pin. *)
val pin : int

(** The scenario's pulse width in cycles, and interval in pulse widths. *)
val pulse : int

val interval : int
val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

(** The host words of a 26-bit read: even parity over the first 12 bits, odd over the
    last 12. *)
val card : facility:int -> id:int -> int list

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
