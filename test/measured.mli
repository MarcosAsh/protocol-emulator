(** The times a pin-side model has measured, by name, as the shortest and the longest seen
    of each, in the order the names first came up. *)

open! Core

type t [@@deriving sexp_of]

val empty : t
val add : t -> name:string -> ns:int -> t

(** [cycles] at [clock_hz] in ns, to the nearest, as a reading. *)
val ns : clock_hz:int -> int -> int

(** Whether [cycles] at [clock_hz] last at least, or at most, [ns]: exact, where a reading
    to the nearest ns is not. *)
val at_least : clock_hz:int -> int -> ns:int -> bool

val at_most : clock_hz:int -> int -> ns:int -> bool

(** The whole cycles in [ns] at [clock_hz]. *)
val cycles : clock_hz:int -> ns:int -> int
