(** SENT, SAE J2716, a fast channel transmitter on [pin]: a sync pulse, the status nibble,
    six data nibbles and the CRC, then a pause pulse.

    The host sends the tick length in cycles once, then two words per frame ([words]).
    Each pulse is low for 5 ticks and ends at the next fall: 12 ticks plus the nibble
    value, or 56 for the sync. The CRC is CRC-4 over the data nibbles, not the status. The
    pause is 12 ticks, or runs until a tick after the next frame arrives; a late second
    word is an underflow fault. The line is low from reset until the tick arrives. J2716
    bounds the pause at 768 ticks, so the host must send the next frame within 766 ticks
    of the pause's fall. *)

open! Core
open Protocol_emulator

val pin : int

(** 3.125 us at 48 MHz. *)
val standard_tick : int

(** The smallest tick the host may load. The kernel accepts the analyser's rows for it and
    every larger value. *)
val shortest_tick : int

val firmware : string
val config : Program_config.t

(** The SAE's recommended CRC: the table method from seed 5, then a zero nibble. *)
val crc4 : int list -> int

module Frame : sig
  type t =
    { status : int
    ; data : int list (** Six nibbles. *)
    }
  [@@deriving sexp_of, compare, equal]
end

val words : Frame.t -> int list

(** Decodes one level per cycle against J2716's pulses: sync 56 ticks, each low more than
    4 ticks, a nibble 12 to 27 ticks (within an eighth of a tick of whole ticks of the
    sync's tick), and a pause 12 to 768 ticks. A frame whose pause hasn't ended yet still
    counts.

    The tick is taken from each sync and compared with the previous one (within 1/64), not
    with J2716's 3 to 90 us, so tests can run short ticks for speed. Every frame must have
    a pause. This is an oracle for this transmitter, not a general J2716 receiver. *)
val decode : clock_hz:int -> bool list -> (Frame.t list * Measured.t) Or_error.t

val protocol : Protocol.t
