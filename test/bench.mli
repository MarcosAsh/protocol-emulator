(** The library firmware the outside chip demos in BRINGUP.md load, at the parameters the
    bench's clock needs, each with the assumption the analyser and the kernel check it
    under, and the pins and clock the bench gives them. *)

open! Core
open Protocol_emulator

module Assumption : sig
  type t =
    | Nothing
    | Floor of int (** The least period the host may load. *)
    | Period of int (** The period the host loads. *)
    | Receiver of int (** The period, and one edge before the capture. *)
end

(** What a run gives the host after [load]: bursts of words, each once the one before is
    in the core, its fifo empty and the pin quiet for [quiet] cycles. *)
module Stimulus : sig
  type t =
    { bursts : int list list
    ; quiet : int
    ; cycles : int
    }
end

type t =
  { name : string
  ; what : string
  ; source : string
  ; config : Program_config.t
  ; assumption : Assumption.t
  ; clock_hz : int
  ; load : int option
  (** The period a demo loads, for firmware that takes it from the host, from the rate it
      wants at [clock_hz]. *)
  ; stimulus : Stimulus.t option
  (** For limits a run bounds ([Datasheet.Bound.Run]), with the host on time. *)
  }

(** I2C's pins on the bench, which is wired once for every demo. *)
val sda : int

val scl : int

(** MOSI on OUT4, SCK on OUT5 and, for [Spi_cs], CS on OUT6 by side-set. *)
val on_spi_pins : Program_config.t -> Program_config.t

(** The chip's clock on both boards, and the half period both SPI masters run at. *)
val clock_hz : int

val spi_half : int

(** Cycles at [clock_hz]. *)
val quarter : hz:int -> int

val cycles_in : us:int -> int

(** The library firmware no protocol file holds yet ([Library]). *)
val others : t list

(** The period the kernel checks the limits at: the assumption's, else the load. *)
val period : t -> int option

(** A time or a rate from cycles at [clock_hz], 48 MHz unless given, which is where every
    label here comes from. *)
val time : ?clock_hz:int -> int -> string

val rate : ?clock_hz:int -> ?unit:string -> int -> string

(** [Timed_program.of_source_exn] under the assumption. *)
val timed : t -> Timed_program.t
