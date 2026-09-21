(** The times a pin-side model has measured, by name, as the shortest and the longest seen
    of each, in the order the names first came up. *)

open! Core

type t [@@deriving sexp_of]

val empty : t
val add : t -> name:string -> ns:int -> t
