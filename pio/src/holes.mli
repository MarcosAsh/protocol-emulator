(** A [.pio] file with holes for the timing check to fill: [[?]] in a delay field,
    [side ?] for a side-set value. A hole can take any value pioasm accepts there. Its
    cost is the distance from a reference program: [|d - d0|] for a delay, the number of
    differing bits for a side-set value. *)

open! Core

module Hole : sig
  type kind =
    | Delay
    | Side
  [@@deriving sexp_of]

  type t =
    { line : int (** From 1. *)
    ; kind : kind
    ; reference : int option
    (** The reference program's value. A missing delay counts as 0. A missing side-set is
        [None], and every value costs 1 from there. [None] if there is no reference. *)
    ; domain : int list
    }
  [@@deriving sexp_of]
end

type t

(** The holes in [text], in order. With a [reference], each hole's value comes from the
    same line of it, and every other line must be identical. Without one, a delay costs
    its value and a side-set value costs nothing, so the search finds the fastest program. *)
val parse : ?reference:string -> string -> t Or_error.t

val holes : t -> Hole.t list

(** [text] with each hole replaced by its value, in order. A line whose holes all keep the
    reference's values is copied from the reference unchanged. *)
val fill : t -> int list -> string

(** The sum of the holes' costs. *)
val cost : t -> int list -> int

(** True when every program a spec selects passes [Timing.analyse] under that spec, as it
    would in [pio_check]. It is an error if a spec cannot configure a program. *)
val meets : Spec.t list -> string -> bool Or_error.t

module Search : sig
  type t =
    { checked : (int * int) list (** Each cost tried, with its number of assignments. *)
    ; minimal : (int * int list list) option
    (** The lowest cost with a passing assignment, and all the passing ones at that cost. *)
    }
  [@@deriving sexp_of]
end

(** Tries every assignment in order of cost and stops after the first cost where one
    passes. Everything cheaper failed, so the fix is minimal relative to [passes].
    [minimal = None] means none passes. Errors if more than [max_checks] assignments lie
    up to the cost where it stops. *)
val solve
  :  ?max_checks:int
  -> t
  -> passes:(string -> bool Or_error.t)
  -> Search.t Or_error.t
