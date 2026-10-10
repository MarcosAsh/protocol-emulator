(** SPI master in any of the four modes, driving its chip select: MOSI on OUT0, SCK on
    OUT1, CS on OUT2 and MISO on IN0, MSB first. The bench's copies, on its pins, are
    certified. *)

open! Core
open Protocol_emulator

module Mode : sig
  type t =
    { cpol : bool (** SCK's idle level. *)
    ; cpha : bool (** Sample on the trailing edge, else on the leading one. *)
    }
  [@@deriving sexp_of, equal]

  (** Mode n is CPOL in bit 1 and CPHA in bit 0. *)
  val of_int : int -> t

  val to_int : t -> int
  val all : t list
end

val mosi_pin : int
val sck_pin : int
val cs_pin : int
val miso_pin : int
val config : Program_config.t

(** Set in a host word, CS rises after its byte. *)
val last : int

(** The least half period the kernel accepts, in cycles; the most is 31. *)
val shortest_half : int

val shortest_setup : int
val longest_setup : int
val shortest_hold : int
val longest_hold : int

(** A host word is a byte in bits 7 to 0, and [last] to end the frame, and the core pushes
    the byte it read. CS falls [setup] cycles before the first SCK edge and rises [hold]
    after the last, and stays high [deselect] cycles at least, and never under 9, which a
    flash's wake from power down needs. Between bytes of a frame it stays low, SCK idle,
    for as long as the host is slow. Raises if [setup], [hold] or [deselect], up to 248
    cycles, is out of its range. *)
val master
  :  mode:Mode.t
  -> half_period:int
  -> setup:int
  -> hold:int
  -> deselect:int
  -> string

(** One frame's host words. *)
val words : int list -> int list

(** A slave on the pins in [mode], from the mode's definition rather than the firmware.
    Each frame it answers [first], then the complement of each byte it took. It measures
    CS's setup and hold, its high and low times and SCK's half periods in cycles, and
    calls an SCK edge with CS high, or CS rising inside a byte, a violation. *)
module Device : sig
  type t

  val create : mode:Mode.t -> first:int -> t
  val miso : t -> int
  val step : t -> cs:int -> sck:int -> mosi:int -> t
  val frames : t -> int list list
  val measured : t -> Measured.t
  val violations : t -> string list
end

val protocol : Protocol.t
