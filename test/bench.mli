(** The library firmware the outside chip demos in BRINGUP.md load, at the parameters the
    bench's clock needs, each with the assumption the analyser and the kernel check it
    under. *)

open! Core
open Protocol_emulator

module Assumption : sig
  type t =
    | Nothing
    | Floor of int (** The least period the host may load. *)
    | Period of int (** The period the host loads. *)
    | Receiver of int (** The period, and one edge before the capture. *)
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
  }

val all : t list

(** The keyboard demo's log to Pico B at 115200 baud, which [all] leaves out: the demo
    loads the certified copy. *)
val uart_log : t

(** The period the kernel checks the limits at: the assumption's, else the load. *)
val period : t -> int option

(** Searches [all] and [uart_log]. *)
val find_exn : string -> t

(** A time or a rate from cycles at [clock_hz], 48 MHz unless given, which is where every
    label here comes from. *)
val time : ?clock_hz:int -> int -> string

val rate : ?clock_hz:int -> ?unit:string -> int -> string

(** [Timed_program.of_source_exn] under the assumption. *)
val timed : t -> Timed_program.t
