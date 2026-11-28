(** SENT, SAE J2716, a fast channel transmitter on [pin]: a sync pulse, the status nibble,
    six data nibbles, the CRC, then a pause pulse. The host sends the tick length in
    cycles once, then two words per frame ([words]). A pulse is low 5 ticks and ends at
    the next fall: 12 ticks plus the nibble, 56 for sync. CRC-4 covers the data nibbles.
    The pause is 12 ticks or until the next frame, at most 768, so send it within 766. *)

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
    4 ticks, a nibble 12 to 27 ticks (to an eighth of a tick), a pause 12 to 768. The tick
    comes from each sync, compared with the last (within 1/64) not J2716's 3 to 90 us, so
    tests can use short ticks. An oracle for this transmitter, not a general receiver. *)
val decode : clock_hz:int -> bool list -> (Frame.t list * Measured.t) Or_error.t

val protocol : Protocol.t
