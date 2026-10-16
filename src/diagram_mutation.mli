(** A diagram with every period's cycles cut by a percentage, certified beside the
    original. The table interpreter refuses a step shorter than its kind needs, and a
    diagram's own edge limits are checked on the new cycles, so a protocol drawn at its
    margin is refused when it runs a little fast. *)

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

(** [cycles * (100 - faster) / 100] rounded down, so a period of any length loses a cycle;
    a period of 0 cycles stays. [faster] is in (0, 100). *)
val faster : Wavejson.t -> percent:float -> Wavejson.t Or_error.t

val run : Wavejson.t -> percent:float -> t Or_error.t
