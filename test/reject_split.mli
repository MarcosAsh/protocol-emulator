(** The kernel's verdicts on one-field variants of the firmware library: every other delay
    that re-encodes, and every jump target moved one either way inside the program. Runs
    stay within the certificates' premises: the host preloads the period, a run stops at
    the first load of [p] writing anything else, and runs are far under [no_wrap]'s 84 ms.
    Receivers (single-edge premise) and table interpreters (data memory) are out. *)

open! Core
open Protocol_emulator

module Variant : sig
  type t =
    { name : string (** Names the firmware, the pc and the field's new value. *)
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
    (** Refused, no miss found, and no table of the kernel's shape passes (cake_lpr checks
        the UNSAT). Either a limit of its rows or a miss the runs didn't reach. *)
    | Accepted_but_missed (** A run missed a deadline the kernel says it meets. Never. *)
    | Witness_refused (** SAT found a table [Kernel.check] refuses. Never happens. *)
  [@@deriving sexp_of, compare, equal, enumerate]
end

(** Run [i] of [runs] uses seed [i]. Even seeds write only the period, odd seeds write
    other words, and seed 3 counts 0-7 and 0xffff. [`Cycles] sums the cycles the premises
    held for. [random_host] writes random words from the start with no premise cut, to
    check the test has teeth. *)
val classify
  :  ?random_host:bool
  -> ?runs:int
  -> ?cycles:int
  -> Variant.t
  -> Verdict.t * [ `Cycles of int ]

(** Counts each verdict, then lists every variant that is not [Accepted] or [Missed]. *)
val print_split : ?runs:int -> ?cycles:int -> Variant.t list -> unit
