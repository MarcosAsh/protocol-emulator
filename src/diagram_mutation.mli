(** A diagram with every period's cycles cut by a percentage, certified beside the
    original. A refusal is usually the table interpreter's minimum for a step's kind, not
    a protocol limit: a diagram drawn at that minimum fails at any percentage. A diagram's
    own edge limits are checked on the new cycles and, when one fails, it is named. A
    refusal at a drawn period also says which edge and cycle that is. *)

open! Core

module Verdict : sig
  type t =
    | Accepted of Wavedrom.t
    | Refused of Error.t

  (** What the playground shows: the steps and each edge's limit and time, or the refusal,
      which names the step or the edge and the limit it breaks. *)
  val to_string : t -> string
end

type t =
  { original : Verdict.t
  ; mutant : Verdict.t
  ; cycles : int list (** the mutant's cycles a period *)
  }

(** [cycles * (1000 - tenths) / 1000] rounded down, [tenths] being [percent] to a tenth,
    so a period of any length loses a cycle; a clock's period stays even, a positive
    period stays at least 1 (2 for a clock) and one of 0 cycles stays. [percent] is in (0,
    100). *)
val faster : Wavejson.t -> percent:float -> Wavejson.t Or_error.t

val run : Wavejson.t -> percent:float -> t Or_error.t
