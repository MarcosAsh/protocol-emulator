(** DShot, the ESC protocol, on [pin]: 16-bit frames MSB first, each bit a high pulse
    whose width is the data. The host sends the whole frame word, [frame].

    Each bit is three deadlines [zero_high] apart, rise, a zero falls, a one falls, and
    the next rise [bit] cycles after this one. After a frame the line stays low for the
    rest of its last bit and [8 * zero_high] cycles more, then until the next word. *)

open! Core
open Protocol_emulator

val pin : int
val cycle_ns : int

(** 31 and 83 cycles, 620 and 1660 ns; in [Library.certified]. *)
val dshot600 : string

(** 16 and 42 cycles, 320 and 840 ns; kernel-checked, not certified. *)
val dshot1200 : string

val config : Program_config.t

(** The 11-bit throttle, the telemetry request, then the XOR of the nibbles above. *)
val frame : throttle:int -> telemetry:bool -> int

(** The rates' nominal times in ns, bit, T0H and T1H, as KISS gives them, 3/8 and 3/4 of
    the bit. Betaflight's 7 and 14 of 20 are outside the decoder's 5% of these. *)
module Rate : sig
  type t =
    { bit_ns : int
    ; zero_high_ns : int
    ; one_high_ns : int
    }
  [@@deriving sexp_of]

  val dshot600 : t
  val dshot1200 : t
end

(** Decodes one level per cycle: a frame is 16 rises, each ended by a low longer than two
    bits. Every high, and every bit from rise to rise, must be within 5% of [rate]'s, and
    the checksum must hold. *)
val decode
  :  Rate.t
  -> cycle_ns:int
  -> bool list
  -> ((int * bool) list * Measured.t) Or_error.t
