(** PS/2, the device end: a start bit, a byte LSB first, odd parity and a stop bit, on a
    clock the device makes, and nothing while the host holds the clock low. IBM PS/2
    Hardware Interface Technical Reference (May 1988), Keyboard and Auxiliary Device
    Controller (Type 1), Figures 7 and 8, and Chapweske's "The PS/2 Mouse/Keyboard
    Protocol" (05/09/03) for the 50 us of clock high before a frame. *)

open! Core
open Protocol_emulator

(** IO0 and IO1, both open drain. *)
val data : int

val clock : int
val config : Program_config.t

(** The host word for [byte]: the byte, with its odd parity in bit 8. *)
val word : int -> int

(** A host that holds the clock low for [hold] cycles from [after] cycles past each
    frame's 11th clock. *)
val host : after:int -> hold:int -> unit -> Pin_trace.Peer.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
