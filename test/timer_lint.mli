(** A lint for compares of timer values. The timer ([Isa.timer_bits] wide) wraps by
    design, so a compare of two of its values means what it says only as the signed
    difference, [now - t] against a constant, or on a sum computed wide enough that it
    cannot wrap. On 2026-09-26 the capture proof found the kernel summing a count of
    cycles in 24 bits and then comparing it against a limit, which a wrapped count passed.

    The lint walks the signal graph of each circuit and finds every unsigned and signed
    less-than, every equality with an adder or subtractor on one side, and every test of
    the sign bit, whose operands are timer wide or are sums and differences of timer wide
    values. A sign bit that only goes into a sign extension of its value, into the flip
    [<+] makes of that value, or into a reordering of all its bits is not a test. The lint
    looks through wires, muxes and resizes to what an operand can be, and then says
    whether the compare is safe, or else what is wrong with it.

    A difference of two timer values is safe against a constant, since it wraps on
    purpose. A difference with a constant is a threshold on its other side, judged as that
    side would be, so [msb (x -:. limit)] tests [x] against [limit]. Anything else is a
    count: a sum wide enough that its largest value does not carry out of its width, one
    bit more than a timer value for two terms, two for three or four. A count compared as
    signed, or tested by its sign bit, must also stay below the sign bit, which takes one
    bit more again. A difference added into a count may be negative, so it is flagged.

    The bound on a value comes from its structure alone (constants, zero extension, muxes
    and nested sums), so a sum that cannot wrap for a reason the graph does not show is
    flagged and needs an allowance saying why. *)

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
    flagged; then any allowance that covered nothing. A compare is placed by the named
    signals it first reaches. Operands are written with Hardcaml's operators, a nameless
    or deep operand as [_]. *)
val print : ?allow:Allowance.t list -> Circuit.t list -> unit
