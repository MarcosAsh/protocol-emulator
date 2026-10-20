(** The kernel's verdicts on one-field variants of the firmware library: every other delay
    that re-encodes, and every jump target moved one either way inside the program. Runs
    keep to the certificates' premises: the host preloads the period and a run stops at
    the first load of [p] that carries anything else. Receivers are left out, as random
    pins break their single-edge premise, and so are table interpreters, whose paths
    follow a table in data memory that the runs leave empty. Runs are far shorter than the
    84 ms [no_wrap] horizon. *)

open! Core
open Protocol_emulator

module Variant : sig
  type t =
    { name : string (** The firmware, the pc and the field's new value. *)
    ; firmware : Certified.t
    ; config : Program_config.t
    ; words : int list
    }
end

(** [Library.certified] less the receivers. *)
val firmware : Certified.t list

val variants : Certified.t -> Variant.t list

module Verdict : sig
  type t =
    | Accepted
    | Missed (** Refused, and a run missed a deadline. *)
    | Analyser_limit (** Refused, no miss found, and a SAT table passes [Kernel.check]. *)
    | No_table
    (** Refused, no miss found, and no table of the kernel's shape passes (an UNSAT
        cake_lpr checks): a limit of its rows, or a miss the runs did not reach. *)
    | Accepted_but_missed (** A run missed a deadline the kernel says it meets. Never. *)
    | Witness_refused
    (** SAT found a table [Kernel.check] refuses. Never, and reachable only where SAT
        finds a table. *)
  [@@deriving sexp_of, compare, equal, enumerate]
end

(** Run [i] of [runs] has seed [i]: even seeds write only the period, odd ones other
    words, seed 3 counts 0-7 and 0xffff. [`Cycles] sums the cycles the premises held for.
    [random_host], for teeth, writes random words from the start with no premise cut. *)
val classify
  :  ?random_host:bool
  -> ?runs:int
  -> ?cycles:int
  -> Variant.t
  -> Verdict.t * [ `Cycles of int ]

(** The count of each verdict, then every variant not [Accepted] or [Missed], by name. *)
val print_split : ?runs:int -> ?cycles:int -> Variant.t list -> unit
