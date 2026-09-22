(** Integer intervals with open ends, for the timing analyser. *)

open! Core

type t =
  { lo : int option
  ; hi : int option
  }
[@@deriving sexp_of, compare, equal]

val exactly : int -> t
val top : t
val at_least : int -> t
val shift : t -> int -> t
val join : t -> t -> t
val plus : t -> t -> t
val minus : t -> t -> t

(** Values below [n] become [n]. *)
val clamp_low : t -> int -> t

val widen : old:t -> t -> t
val contains : t -> int -> bool

(** No integer lies in both. *)
val disjoint : t -> t -> bool

val to_string : t -> string
