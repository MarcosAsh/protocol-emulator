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
  }

val all : t list
val find_exn : string -> t

(** [Timed_program.of_source_exn] under the assumption. *)
val timed : t -> Timed_program.t
