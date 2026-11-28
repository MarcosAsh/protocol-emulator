(** HDMI-CEC initiator on one open drain pin, IO0, every time a whole number of 50 us
    units. The host sends the unit in cycles once, then per frame the block count minus
    one and a word per block, [words]. Start bit 74 units low of 90, a bit 12 low for a
    one or 30 for a zero of 48. ACK slot sampled at 21 units and pushed, 0 if acked. Line
    free seven bit periods after a frame. A late word underflows. No arbitration. *)

open! Core
open Protocol_emulator

val pin : int

(** 52.1 us at 48 MHz. *)
val standard_unit : int

(** The shortest unit the host may load: the kernel accepts the analyser's rows at this
    load and any longer one. *)
val shortest_unit : int

val firmware : string
val config : Program_config.t

module Frame : sig
  type t =
    { initiator : int
    ; destination : int
    ; data : int list (** Opcode and operands, if any. *)
    }
  [@@deriving sexp_of, compare, equal]
end

val words : Frame.t -> int list

(** A follower at a logical address. It acks every block of a frame sent to it and times
    the line against CEC 1.4's limits. Before a start bit the line must have been free
    (CEC 9.1): 3 bit periods after a failed frame, 5 before a new initiator's, 7 before
    any other. A frame stalled past a bit's limit is given up and may be retried. *)
module Follower : sig
  type t

  val create : clock_hz:int -> address:int -> t
  val drive_low : t -> bool

  (** [low]: the line, driven by anyone, in this cycle. *)
  val step : t -> low:bool -> t

  (** Every frame seen to its EOM, with the ACK slot of each block, true if pulled low. *)
  val frames : t -> (Frame.t * bool list) list

  val measured : t -> Measured.t
  val violations : t -> string list
end

val protocol : Protocol.t
