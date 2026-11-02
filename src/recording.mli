(** Edge times on one or more lines, as an analyser or the chip's edge logger saw them.
    The text is demo/edges.py's: [rate HZ], [length SAMPLES], then a line a pin,
    [pin NAME LEVEL T1 T2 ...], its level at sample 0 and the sample of each change. Lines
    starting [#] are notes, kept for where a recording came from. *)

open! Core

module Line : sig
  type t =
    { name : string
    ; first : bool
    ; edges : int array
    }
  [@@deriving sexp_of]

  (** Each run between two edges, its level and length in samples; the two the capture
      cuts are left out. *)
  val runs : t -> (bool * int) list

  (** The level just before sample [at]. *)
  val level_at : t -> int -> bool
end

type t =
  { rate_hz : float
  ; length : int
  ; lines : Line.t list
  ; notes : string list
  }
[@@deriving sexp_of]

val of_string : string -> t Or_error.t
val to_string : t -> string
val find : t -> string -> Line.t option
