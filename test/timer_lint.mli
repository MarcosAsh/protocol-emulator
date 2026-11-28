(** A lint for timer compares. The timer ([Isa.timer_bits] wide) wraps by design, so two
    of its values compare only as the signed difference ([now - t] against a constant) or
    as a sum wide enough not to wrap. It walks each circuit's signal graph and judges
    every less-than, adder equality and sign bit test on timer wide values. Bounds come
    from structure alone, so a hidden reason not to wrap needs an allowance. *)

open! Core
open! Hardcaml

module Fault : sig
  type t =
    | May_wrap of string (** a sum whose largest operands carry out of its width *)
    | Signed_overflow of string
    (** a sum tested as signed, or by its sign bit, whose largest value sets that bit *)
    | Unsigned_difference of string
    (** a difference compared as unsigned, or added into a count *)
    | Unsigned_timer of string (** a timer value, not a wide sum, compared as unsigned *)
    | Not_a_difference of string
    (** a value compared against a constant, or tested by its sign, that is neither a
        difference nor a count *)
    | Two_sided of string (** two values compared, where their difference would do *)
  [@@deriving compare, equal, sexp_of]
end

(** A flagged fault that is fine for a reason the graph does not show. It covers that
    fault in that compare of that circuit, both as printed, so a reason given for one
    compare covers no other. *)
module Allowance : sig
  type t =
    { name : string
    ; circuit : string
    ; compare : string
    ; fault : Fault.t
    ; reason : string
    }
end

(** Every compare of timer values in [circuits], by circuit, each safe, allowed or
    flagged, then any allowance that covered nothing. A compare is placed by the named
    signals it first reaches. Operands are written with Hardcaml's operators, with a
    nameless or deep operand as [_]. *)
val print : ?allow:Allowance.t list -> Circuit.t list -> unit
