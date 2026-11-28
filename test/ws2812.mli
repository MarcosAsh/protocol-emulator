(** WS2812B LED strings: one wire, 24 bits a pixel, green first, each bit a high pulse
    whose width is the data. A bit is three deadlines: rise, [third] cycles to the data's
    level, [third] more to the fall, [third + tail] to the next rise. Shortest bit:
    [third] 6, [tail] 7 (an immediate, at most 7). Two words per pixel ([Pixel.words]).
    160 [third] cycles low with no pixel in the fifo latches, [latching] longer. *)

open! Core
open Protocol_emulator

val pin : int
val firmware : third:int -> tail:int -> string

(** [firmware] with the line low for [gaps] times 160 thirds before a frame, [gaps] from 1
    to 32. *)
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
