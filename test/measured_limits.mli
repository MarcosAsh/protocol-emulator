(** A bench copy's datasheet limits measured on a capture of its pins, from the rows the
    kernel and its run check them by: a [Datasheet.Bound.Run]'s own widths, and for a
    [Datasheet.Bound.Kernel] the spacing the kernel bounds, at every edge it applies at.
    So one table is certified, run and measured. An open drain pin ([dirs]) is taken as
    driven where it reads low. *)

open! Core

(** The pins a sample at a time, a word a sample by the engine's pin numbers. *)
module Capture : sig
  type t =
    { rate_hz : int
    ; samples : int array
    ; from_reset : bool
    (** The first level began at the first sample, as it does in a run from reset, and not
        before the capture did. *)
    }

  (** [bench]'s own run for [limit] at its clock, as [Datasheet] runs it, sampled at
      [rate_hz] from a cycle's start. *)
  val of_run : ?rate_hz:int -> Bench.t -> Datasheet.t -> t
end

module Verdict : sig
  type t =
    | Pass
    | Within_a_sample (** A sample either way could put it on either side. *)
    | Fail
    | Unmeasured (** No edge it applies at. *)
  [@@deriving sexp_of, equal]
end

type t =
  { limit : Datasheet.t
  ; samples : int option
  (** The least the capture shows, or the most for [At_most], in samples. *)
  ; verdict : Verdict.t
  }

(** Every one of [limits] that names [bench]. *)
val measure : Datasheet.t list -> Bench.t -> Capture.t -> t list

(** A line per limit: its parameter, the limit, what the capture shows in samples and ns,
    and the verdict. *)
val to_string : Capture.t -> t list -> string
