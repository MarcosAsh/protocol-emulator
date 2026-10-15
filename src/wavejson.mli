(** WaveDrom's WaveJSON, read as the WaveDrom editor reads it: JSON with unquoted keys,
    single quotes, trailing commas and comments. Lanes in groups are flattened and spacers
    dropped. A top-level [table] object, which WaveDrom ignores, says how long each period
    is; see [Wavedrom]. *)

open! Core

module Value : sig
  type t =
    | Null
    | Bool of bool
    | Number of float
    | String of string
    | List of t list
    | Object of (string * t) list
  [@@deriving sexp_of, equal]

  val parse : string -> t Or_error.t
end

module Lane : sig
  type t =
    { name : string
    ; wave : string
    ; data : string list
    ; input : bool (** [input: true]: a pin the table reads, not one it drives *)
    ; phase : float
    ; period : float
    }
  [@@deriving sexp_of]
end

module Cycles : sig
  (** Cycles a period: the same for every period, or one for each drawn period. *)
  type t =
    | Every of int
    | Each of int list
  [@@deriving sexp_of]
end

module Repeat : sig
  (** Periods [first] to [last] drawn once and sent [times] times. With [while_host] that
      is one pass, and passes go on while the host's word says so. *)
  type t =
    { first : int
    ; last : int
    ; times : int
    ; while_host : bool
    }
  [@@deriving sexp_of]
end

type t =
  { lanes : Lane.t list
  ; cycles : Cycles.t
  ; repeat : Repeat.t option
  ; words : int list option (** bits in each host word, first first *)
  }
[@@deriving sexp_of]

val of_value : Value.t -> t Or_error.t
val parse : string -> t Or_error.t
