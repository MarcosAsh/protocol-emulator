(** LIN, the master's side: a header, then a slave's response read back. LIN Specification
    Package Revision 2.2A, 2.3 (frame) and 6.3 (bit rate tolerance). *)

open! Core
open Protocol_emulator

(** IO0, open drain. *)
val pin : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. Takes half a bit, then per frame the
    response's bytes less one and the PID; pushes each response byte, checksum last. A
    response that never comes stalls it. *)
val firmware : Timed_program.t

(** The PID of a frame identifier, its parity bits on top. *)
val pid : int -> int

(** The enhanced checksum of a frame's data under its PID. *)
val enhanced : pid:int -> int list -> int

(** The host words of a frame. *)
val words : id:int -> data:int list -> int list

(** A slave at [bit] cycles a bit that answers each identifier in [publishes] with its
    data and enhanced checksum, a bit after the PID's stop bit. *)
module Slave : sig
  type t

  val create : clock_hz:int -> bit:int -> publishes:(int * int list) list -> t
  val drive_low : t -> bool
  val step : t -> low:bool -> t

  (** The PIDs it read. *)
  val headers : t -> int list

  val measured : t -> Measured.t
  val violations : t -> string list
end

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
