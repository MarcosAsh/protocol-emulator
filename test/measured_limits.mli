(** A bench copy's datasheet limits measured on a capture of its pins, from the rows the
    kernel and its run check them by: a [Datasheet.Bound.Run]'s own widths, and for a
    [Datasheet.Bound.Kernel] the spacing the kernel bounds, at every edge it applies at.
    So one table is certified, run and measured. An open drain pin ([dirs]) is taken as
    driven where it reads low. *)

open! Core
open Protocol_emulator

(** Each pin's edges, by the engine's pin numbers; a pin not given stays low. *)
module Capture : sig
  module Line : sig
    type t =
      { first : bool (** The level at sample 0. *)
      ; edges : int list (** The samples it changes at, rising order. *)
      }
  end

  type t =
    { rate_hz : int
    ; length : int (** In samples. *)
    ; lines : (int * Line.t) list
    ; from_reset : bool
    (** The first level began at sample 0, as in a run from reset, and not before the
        capture did. *)
    }

  (** [bench]'s own run for [limit] at its clock, as [Datasheet] runs it, sampled at
      [rate_hz] from a cycle's start. *)
  val of_run : ?rate_hz:int -> Bench.t -> Datasheet.t -> t

  (** What demo/edges.py writes of a bench capture: [rate HZ], [length N], then a line
      [pin P LEVEL EDGE...] a pin. A capture read back is not [from_reset]. *)
  val of_string : string -> t

  val to_string : t -> string
end

module Verdict : sig
  type t =
    | Pass
    | Within_a_sample (** A sample either way could put it on either side. *)
    | Fail
    | Unmeasured (** No edge it applies at. *)
  [@@deriving sexp_of, equal]
end

(** Every spacing [spec] asks that the capture shows: the edge's number over both pins'
    edges from 1, its sample, and the samples since the edge it is spaced from. *)
val applications : Capture.t -> Kernel.Spacing.Spec.t -> (int * int * int) list

type t =
  { limit : Datasheet.t
  ; samples : int option
  (** The least the capture shows, or the most for [At_most], in samples. *)
  ; verdict : Verdict.t
  }

(** Every one of [limits] that names [bench]. *)
val measure : Datasheet.t list -> Bench.t -> Capture.t -> t list

(** A line per limit: its parameter, the limit, what the capture shows in samples and ns,
    the verdict and the sheet. *)
val to_string : Capture.t -> t list -> string
