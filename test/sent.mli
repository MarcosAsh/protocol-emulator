(** SENT, SAE J2716, a fast channel transmitter on [pin]: a sync pulse, the status nibble,
    six data nibbles and the CRC, then a pause pulse.

    The host sends the tick in cycles once, then two words a frame, [words]. Each pulse
    falls on a deadline, is low for 5 ticks and ends at the next fall, 12 ticks and the
    nibble after, the sync 56. The CRC is the core's: CRC-4 over the data nibbles, not the
    status. The pause is 12 ticks, or, when the host's next frame is not in by then, runs
    on to a tick after it arrives, 13 ticks or more; a late second word is an underflow
    fault. The line is low from reset until the tick arrives.

    J2716 bounds the pause at 768 ticks, so the host must send the next frame within 766
    ticks of the pause's fall. *)

open! Core
open Protocol_emulator

val pin : int
val cycle_ns : int

(** 3 us at 50 MHz. *)
val standard_tick : int

(** The least tick the host may load: the kernel accepts the analyser's rows at every load
    of it or more. *)
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
    4 ticks, a nibble 12 to 27 ticks within an eighth of a tick of whole ticks of the
    sync's, and a pause 12 to 768 ticks. A frame whose pause has not ended counts.

    The tick is measured from each sync against the last, within 1/64, not against J2716's
    3 to 90 us, so the tests may run short ticks for speed; and every frame must have a
    pause. An oracle for this transmitter, not a general J2716 receiver. *)
val decode : cycle_ns:int -> bool list -> (Frame.t list * Measured.t) Or_error.t

val protocol : Protocol.t
