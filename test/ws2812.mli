(** WS2812B LED strings: one wire, 24 bits a pixel, green first, each bit a high pulse
    whose width is the data.

    A bit is three deadlines: rise, then [third] cycles later the line takes the value of
    the bit, then [third] cycles later it falls, and the next bit starts [third + tail]
    cycles after that. Every edge is the instruction after a deadline wait, so none of
    them depends on the data, on the word boundaries or on when the host wrote. With
    [third] 20 and [tail] 2 at 48 MHz that is T0H 417 ns, T1H 833 ns, T0L 875 ns, T1L 458
    ns and a bit of 1292 ns, 774 kbit/s, each time within 34 ns of the datasheet's against
    a tolerance of 150 ns; 19 and 3 would give its 1250 ns bit.

    The resolution is one clock cycle, 20.8 ns. The shortest bit this structure can make
    is [third] 6 and [tail] 7, 25 cycles or 1.92 Mbit/s: the thirteen cycles from the
    falling edge round the end of a word to the next rise have to fit in [third + tail],
    and [tail] is an immediate of at most 7. A [tail] up to 14 takes a second add, a cycle
    more round a word's end.

    The host writes two words a pixel, [Pixel.words]. The string goes on for as long as
    the next pixel is in the fifo when the last one ends; when it is not, the line stays
    low for 160 times [third] cycles, 67 us at the standard timing, so the string latches,
    and the next word starts a new frame at the first LED. Strings that want a longer
    reset take [latching]. A pixel whose second word is late sets the underflow fault. *)

open! Core
open Protocol_emulator

val pin : int
val firmware : third:int -> tail:int -> string

(** [firmware] with the line low for [gaps] times 160 thirds before a frame, from 1 to 32. *)
val latching : gaps:int -> third:int -> tail:int -> string

val standard : string
val config : Program_config.t

module Pixel : sig
  type t =
    { red : int
    ; green : int
    ; blue : int
    }
  [@@deriving sexp_of, compare, equal]

  val words : t -> int list
end

(** The string as the datasheet describes it: decodes the wire back into pixels and checks
    every high time and every low time between two bits against 400 and 850 ns for a zero,
    800 and 450 ns for a one, each within 150 ns. 50 us of low ends a frame. *)
module Strip : sig
  type t

  val create : clock_hz:int -> t
  val step : t -> level:int -> t

  (** Frames that have latched, oldest first. *)
  val frames : t -> Pixel.t list list

  val measured : t -> Measured.t
  val violations : t -> string list
end

val protocol : Protocol.t
