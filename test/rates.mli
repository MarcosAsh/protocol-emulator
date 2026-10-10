(** The standard settings: UART at the common rates, I2C in Standard-mode and Fast-mode,
    SPI in modes 0 to 3, each the library's firmware at the bench's clock with the limits
    of the sheet that sets it. *)

open! Core

type t =
  { bench : Bench.t
  ; limits : Datasheet.t list
  ; stimulus : Datasheet.Stimulus.t option (** For a run's bounds. *)
  }

val bauds : int list
val uart : t list
val i2c : t list
val spi : t list
val all : t list
val check : t -> (Datasheet.t * Datasheet.Verdict.t) list
