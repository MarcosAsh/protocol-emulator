(** Plinkoo, PLK-2 Two-Wire Packet Bus revision 1.3: the controller's end, a sync on STB,
    then L, L bytes and their checksum MSB first on open-drain DAT, then an ack bit. *)

open! Core
open Protocol_emulator

(** STB, driven by [set], and DAT, by its direction bit. *)
val stb : int

val dat : int

(** The sync, in cycles. *)
val sync : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

(** The host's words for a payload: L, then each byte, each in a word's high byte. *)
val words : int list -> int list

(** The checksum section 5 gives a frame's bytes. *)
val checksum : int list -> int

(** The payloads the scenario and the bench send. *)
val frames : int list list

(** The far end: takes a frame on each rise of STB and acknowledges a good one. *)
module Peripheral : sig
  type t

  val create : unit -> t
  val pulls_low : t -> bool

  (** One cycle, with the levels the line shows after it. *)
  val step : t -> stb:bool -> dat:bool -> t

  (** Every frame it took: its bytes, L first, and whether it acknowledged it. *)
  val frames : t -> (int list * bool) list
end

val bench : Bench.t
val limits : Datasheet.t list

(** Each rise of STB in a run of every pin: its cycle, the cycles since DAT last moved,
    and those until it next moves. *)
val around_rises : int array -> (int * int * int option) list

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
