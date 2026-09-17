(** Per-program settings that the host writes before starting the core. They fix how the
    pin-addressed instructions map onto the flat pin space and how the shift registers
    behave, in the manner of the RP2040 PIO. *)

open! Core

module Shift_direction : sig
  type t =
    | Left
    | Right
  [@@deriving sexp_of, compare, equal]
end

type t =
  { side_set_count : int
  ; side_set_base : int
  ; side_set_pindirs : bool (** Side-set writes pin directions instead of values. *)
  ; in_base : int
  ; out_base : int (** Base of [out pins] and of [mov pins]. *)
  ; out_count : int (** Number of pins written by [mov pins] and [mov pindirs]. *)
  ; set_base : int
  ; set_count : int
  ; jmp_pin : int
  ; capture_pin : int
  ; capture_rising : bool
  ; in_shift : Shift_direction.t
  ; out_shift : Shift_direction.t
  ; autopush : bool
  ; push_threshold : int
  ; autopull : bool
  ; pull_threshold : int
  }
[@@deriving sexp_of, compare, equal]

(** One output pin at OUT0, shifting right, no side-set, no autopush or autopull. *)
val default : t

val validate : t -> unit Or_error.t
