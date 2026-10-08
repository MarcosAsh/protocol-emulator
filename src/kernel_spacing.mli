(** The pair of pins whose edges the kernel keeps apart, and their state at an entry. *)

open! Core
open! Hardcaml

(** One pin of a watched pair at an entry: the cycles since its last edge in this run,
    saturating, all ones before the first; its bit; and [fresh] until the run first writes
    it, which sets it and is not counted as an edge. *)
module Edge : sig
  type 'a t =
    { since : 'a
    ; level : 'a
    ; fresh : 'a
    }
  [@@deriving hardcaml]
end

(** A pair of pins whose edges must be spaced, each its [pindirs] bit if [dirs] else its
    [pins] bit; the config that writes them; and the least cycles, indexed
    [2 * own + other] by the two bits before an edge, from [a]'s last edge ([hold_a]) and
    [b]'s ([apart_a]), and the same for [b]. Moving at once is 0 apart. An edge is a move
    after the pin's first write in the run. Out and mov data is not followed, so a pin
    they write may move. *)
module Spacing : sig
  type 'a t =
    { a : 'a
    ; b : 'a
    ; dirs : 'a
    ; side_set_base : 'a
    ; side_set_pindirs : 'a
    ; set_base : 'a
    ; set_count : 'a
    ; out_base : 'a
    ; out_count : 'a
    ; hold_a : 'a list
    ; apart_a : 'a list
    ; hold_b : 'a list
    ; apart_b : 'a list
    }
  [@@deriving hardcaml]

  (** The same, the config apart, keyed by the bits before the edge. *)
  module Spec : sig
    type t =
      { a : int
      ; b : int
      ; dirs : bool
      ; hold_a : own:bool -> other:bool -> int
      ; apart_a : own:bool -> other:bool -> int
      ; hold_b : own:bool -> other:bool -> int
      ; apart_b : own:bool -> other:bool -> int
      }
  end

  val of_spec : Program_config.t -> Spec.t -> Bits.t t
end

(** No spacing asks nothing. *)
module Spaced : With_valid.Wrap.S with type 'a value = 'a Spacing.t
