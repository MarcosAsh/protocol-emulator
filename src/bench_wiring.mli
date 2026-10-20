(** Which logic analyser channel each chip pin of the bench's one permanent wiring (the
    carrier PCB's) reaches, and what else hangs on that net. *)

open! Core

module Analyser : sig
  type t =
    | A
    | B
  [@@deriving compare, sexp_of]
end

type t =
  { pin : int
  ; name : string
  ; analyser : Analyser.t
  ; channel : int
  ; net : string
  }

(** Every chip pin with a channel, in pin order. *)
val all : t list

val find : pin:int -> t option
