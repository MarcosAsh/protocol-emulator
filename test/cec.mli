(** HDMI-CEC initiator on one open drain pin, IO0, with every time a whole number of 50 us
    units.

    The host sends the unit in cycles once, then per frame the number of blocks minus one
    and a word per block, [words]. The start bit is 74 units low and 90 in all (3.7 and
    4.5 ms). A bit is 12 units low for a one and 30 for a zero (0.6 and 1.5 ms), 48 in
    all. In each ACK slot the initiator sends a one, samples at 21 units (1.05 ms) and
    pushes what it saw, 0 when a follower acknowledged. After a frame the line stays free
    for seven bit periods (16.8 ms), CEC 9.1's wait before an initiator's next frame,
    which covers a retry's three. A late block word is an underflow fault.

    No arbitration: the initiator does not watch the line before a frame or read back its
    bits, and sends every block whatever the ACK. *)

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

(** A follower at a logical address on the line. It acknowledges every block of a frame
    sent to it, pulling the line low from the ACK slot's fall to 1.5 ms. It times what it
    sees against CEC 1.4's limits: a start bit low 3.5 to 3.9 ms and 4.3 to 4.7 ms to the
    next fall, a one low 0.4 to 0.8 ms, a zero 1.3 to 1.7, an ACK slot as either (whoever
    pulls it), a bit 2.05 to 2.75 to the next fall. Before a start bit the line must have
    been free (CEC 9.1), counted from the nominal end of the last bit or of a start bit
    given up: 3 bit periods after a failed frame (a block unacknowledged or a broadcast
    refused), when the next is the same frame again; 5, 12 ms, before a new initiator's
    frame; 7 before any other frame of the same initiator. The 3 is checked at the start
    bit and the rest at the frame's EOM. A frame whose line stays high past a bit's 2.75
    ms, or a start bit's 4.7, is given up: it is not counted but it failed, and the next
    frame may retry it if it begins with the blocks it got to. *)
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
