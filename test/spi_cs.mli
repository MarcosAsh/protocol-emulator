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
val shortest_hold : int
val longest_hold : int

(** A host word is a byte in bits 7 to 0, plus [last] to end the frame; the core pushes
    the byte it read. CS falls [setup] cycles before the first SCK edge, rises [hold]
    cycles after the last, and stays high for at least [deselect] cycles, never fewer than
    9 (a flash waking from power down needs that). Between bytes of a frame CS stays low
    and SCK idles for as long as the host is slow. Raises if [setup], [hold] or [deselect]
    is out of range (up to 248 cycles). *)
val master
  :  mode:Mode.t
  -> half_period:int
  -> setup:int
  -> hold:int
  -> deselect:int
  -> string

(** One frame's host words. *)
val words : int list -> int list

(** A slave on the pins in [mode], written from the mode's definition, not from the
    firmware. In each frame it answers [first], then the complement of each byte it took.
    It measures CS setup and hold, CS high and low times and SCK half periods in cycles,
    and counts an SCK edge with CS high, or CS rising inside a byte, as a violation. *)
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
