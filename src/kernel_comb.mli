(** The kernel's step and its conjuncts over any gates. *)

open! Core
open! Hardcaml

module Make (Rows : Kernel_intf.Rows) (Comb : Comb.S) : sig
  include Kernel_intf.M(Rows).Combinational(Comb).S

  (** For [Kernel_table]: whether a row is empty, the top and bottom of a count and a
      mark, and the pair's bounds after the word, as [conjuncts] makes them. *)
  val is_empty : Comb.t Rows.Row.t -> Comb.t

  val since_limit : Comb.t
  val mark_none : Comb.t
  val mark_max : Comb.t

  val edge_images
    :  side_set_count:Comb.t
    -> fraction:Comb.t
    -> capture:Comb.t Rows.Capture.t
    -> spacing:Comb.t Kernel_spacing.Spaced.t
    -> word:Comb.t
    -> row:Comb.t Rows.Row.t
    -> Comb.t Rows.Pin.t * Comb.t Rows.Pin.t
end
