(** HDMI-CEC initiator on one open drain pin, IO0, every time a whole number of 50 us
    units.

    The host sends the unit in cycles once, then per frame the number of blocks less one
    and a word per block, [words]. The start bit is 74 units low and 90 in all, 3.7 and
    4.5 ms; a bit is 12 units low for a one and 30 for a zero, 0.6 and 1.5 ms, and 48 in
    all. In each ACK slot the initiator sends a one, samples the line at 21 units, 1.05
    ms, and pushes what it saw, 0 when a follower acknowledged. After a frame the line is
    left free for seven bit periods, 16.8 ms, CEC 9.1's wait before an initiator's next
    frame, which covers a retry's three too. A block's word that is late is an underflow
    fault.

    No arbitration: the initiator does not watch the line before a frame or read back its
    bits, and sends every block whatever the ACK. *)

open! Core
open Protocol_emulator

val pin : int

(** 50 us at 50 MHz. *)
val standard_unit : int

(** The least unit the host may load: the kernel accepts the analyser's rows at every load
    of it or more. *)
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

(** A follower at a logical address on the line. It acknowledges every block of a frame
    sent to it, pulling the line low from the ACK slot's fall to 1.5 ms. It times what it
    sees against CEC 1.4's limits: a start bit low 3.5 to 3.9 ms and 4.3 to 4.7 ms to the
    next fall, a one low 0.4 to 0.8 ms, a zero 1.3 to 1.7, an ACK slot as either whoever
    pulls it, a bit 2.05 to 2.75 to the next fall. Before a start bit the line must be
    free, CEC 9.1, for 3 bit periods after a frame that failed, a block unacknowledged or
    a broadcast refused, when the next is the same frame again, 5, 12 ms, before a new
    initiator's, and 7 before any other frame of the same initiator's; checked at the next
    frame's EOM. A frame whose line stays high past a bit's 2.75 ms, or a start bit's 4.7,
    is given up and not counted. *)
module Follower : sig
  type t

  val create : cycle_ns:int -> address:int -> t
  val drive_low : t -> bool

  (** [low]: the line, driven by anyone, in this cycle. *)
  val step : t -> low:bool -> t

  (** Every frame seen to its EOM, with the ACK slot of each block, true if pulled low. *)
  val frames : t -> (Frame.t * bool list) list

  val measured : t -> Measured.t
  val violations : t -> string list
end
