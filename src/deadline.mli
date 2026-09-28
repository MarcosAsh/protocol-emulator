(** Release when [now - t] is non-negative as a signed number. Over any [Comb] so the
    proven circuit is the one used. *)

open! Core
open! Hardcaml

module Make (Comb : Comb.S) : sig
  val phase : now:Comb.t -> t:Comb.t -> Comb.t
  val release : now:Comb.t -> t:Comb.t -> Comb.t
  val late : now:Comb.t -> t:Comb.t -> Comb.t
end
