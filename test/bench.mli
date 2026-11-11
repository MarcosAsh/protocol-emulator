(** The library firmware that the outside-chip demos load, with the parameters the bench
    clock needs, the assumption the analyser and kernel check each under, and the bench's
    pins and clock. *)

open! Core
open Protocol_emulator

module Assumption : sig
  type t =
    | Nothing
    | Floor of int (** The shortest period the host may load. *)
    | Period of int (** The period the host loads. *)
    | Receiver of int (** The period, and one edge before the capture. *)
end

(** What the host gets after [load]: bursts of words. Each goes in once the previous one
    is in the core, its fifo is empty and the pin has been quiet for [quiet] cycles. *)
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
  (** The period a demo loads, for firmware that takes it from the host, given the rate
      wanted at [clock_hz]. *)
  ; stimulus : Stimulus.t option
  (** For limits that a run bounds ([Datasheet.Bound.Run]); the host is on time. *)
  }

(** The bench's pins, wired once for every demo. *)

val neopixel : int
val sda : int
val scl : int
val one_wire : int
val td_plus : int

(** MOSI on OUT4, SCK on OUT5 and, for [Spi_cs], CS on OUT6 (by side-set). *)
val on_spi_pins : Program_config.t -> Program_config.t

(** The chip clock on both boards, and the half period both SPI masters use. *)
val clock_hz : int

(** 10BASE-T's, on the Icepi's 40 MHz build. *)
val ethernet_clock_hz : int

val spi_half : int

(** Cycles at [clock_hz]. *)
val bit : hz:int -> int

val half : hz:int -> int
val quarter : hz:int -> int
val cycles_in : us:int -> int

(** [source] with the one occurrence of [pattern] replaced. *)
val patch : string -> pattern:string -> with_:string -> string

(** The period the kernel checks the limits at: the assumption's, else the one loaded. *)
val period : t -> int option

(** A time or rate from cycles at [clock_hz] (48 MHz by default), which is where every
    label here comes from. *)
val time : ?clock_hz:int -> int -> string

val rate : ?clock_hz:int -> ?unit:string -> int -> string

(** [Timed_program.of_source_exn] under the assumption. *)
val timed : t -> Timed_program.t
