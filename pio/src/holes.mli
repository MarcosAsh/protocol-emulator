(** A [.pio] file with holes for the timing to fill: [[?]] in a delay field, [side ?] for
    a side-set value. A hole may take any value pioasm accepts there. Its cost is its
    distance from a reference program: [|d - d0|] for a delay, the bits that differ for a
    side-set value. *)

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
    (** The reference program's value: a missing delay is 0, a missing side-set [None],
        from which every value costs 1. [None] for every hole with no reference. *)
    ; domain : int list
    }
  [@@deriving sexp_of]
end

type t

(** The holes in [text], in order. With a [reference], each hole's value is read from the
    same line of it, and every other line must be the same. Without one a delay costs its
    value and a side-set value nothing, so the search finds the fastest program. *)
val parse : ?reference:string -> string -> t Or_error.t

val holes : t -> Hole.t list

(** [text] with each hole given its value, in order. A line whose holes all keep the
    reference's values is the reference's line, as it was. *)
val fill : t -> int list -> string

(** The sum of each hole's cost. *)
val cost : t -> int list -> int

(** Every program each spec selects passes [Timing.analyse] under it, as [pio_check] with
    that spec would. A spec that cannot configure a program is an error. *)
val meets : Spec.t list -> string -> bool Or_error.t

module Search : sig
  type t =
    { checked : (int * int) list (** Each cost tried, with how many assignments it has. *)
    ; minimal : (int * int list list) option
    (** The lowest cost at which an assignment passes, and every one that does. *)
    }
  [@@deriving sexp_of]
end

(** Tries every assignment in order of cost and stops after the first cost at which one
    passes. Every cheaper assignment was tried and failed, so none of them passes: that is
    the proof the fix is minimal, relative to [passes]. [minimal = None] means no
    assignment passes at all, every one tried. Errors when the space has more than
    [max_checks] assignments up to the cost where it stops. *)
val solve
  :  ?max_checks:int
  -> t
  -> passes:(string -> bool Or_error.t)
  -> Search.t Or_error.t
