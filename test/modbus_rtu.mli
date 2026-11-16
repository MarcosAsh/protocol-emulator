(** A Modbus RTU client's transmitter on OUT0, after the Modbus Organization's "MODBUS
    over Serial Line Specification and Implementation Guide" V1.02: 19200 baud, 8 data
    bits, even parity and one stop bit, each frame sent after a silent interval of 3.5
    characters, with no gap between its characters. *)

open! Core
open Protocol_emulator

(** OUT0. *)
val pin : int

(** The bit in cycles, which the host loads first. *)
val period : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

(** [crc bytes] is the frame's CRC-16 as a register: the low byte goes first on the line. *)
val crc : int list -> int

(** The host words of a frame, its [bytes] and then the CRC: the character count less one,
    then each character as its byte with the even parity bit above it. *)
val frame : int list -> int list

(** The frames the bench and scenario send. *)
val requests : int list list

val bench : Bench.t
val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
