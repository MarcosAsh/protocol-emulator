(** The XY2-100 controller's side: SENDCK, SYNC and DATA, as Newson's rhothor X7 datasheet
    (revision 0703) gives them. SENDCK runs at 2 MHz without a break and a 20-bit word
    follows another with no gap. The host writes the 16 data bits of each setpoint; the
    clock starts with the first and the last is sent again where there is no next. *)

open! Core
open Protocol_emulator

(** The lines the firmware drives: SENDCK, then SYNC and DATA on the pins after it. *)
val pin : int

val clk_pin : int
val sync_pin : int
val data_pin : int

(** The 20 bits on the wire for a setpoint, the first sent highest: control 001, the 16
    data bits, even parity. The host's word is the data. *)
val on_wire : data:int -> int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
