(** Checks a timing certificate one instruction at a time. A certificate is a row per pc:
    the phase [now - t] on entry as a signed interval, the period [p] as an unsigned one.
    The analyser proposes it and is not trusted.

    [formal/phase_step.sv] proves the core moves from one entry to the next as [step]
    says, for any program; [test/test_kernel.ml] proves by SAT that [accepts] keeps [step]
    inside the rows and a deadline wait at or below zero. So a program whose rows all
    pass, with the full range at pc 0, never misses a deadline. An empty row is a pc never
    reached; the full range is an unknown phase. *)

open! Core
open! Hardcaml

module Row : sig
  type 'a t =
    { phase_lo : 'a
    ; phase_hi : 'a
    ; period_lo : 'a
    ; period_hi : 'a
    }
  [@@deriving hardcaml]
end

(** The next entry's phase: anything unless [bounded], one less too if [may_carry].
    [next_period] holds when [period_known]. [loaded], when valid, is the assumption that
    every run-time write to [p] carries its value. [halts]: no next entry. *)
module Step : sig
  type 'a t =
    { next_phase : 'a
    ; bounded : 'a
    ; may_carry : 'a
    ; next_period : 'a
    ; period_known : 'a
    ; halts : 'a
    }
  [@@deriving hardcaml]
end

module Make (Comb : Comb.S) : sig
  val step
    :  side_set_count:Comb.t
    -> fraction:Comb.t
    -> loaded:Comb.t With_valid.t
    -> word:Comb.t
    -> phase:Comb.t
    -> period:Comb.t
    -> Comb.t Step.t

  (** [next] is the row after this one, [target] the jump's. *)
  val accepts
    :  side_set_count:Comb.t
    -> fraction:Comb.t
    -> loaded:Comb.t With_valid.t
    -> word:Comb.t
    -> row:Comb.t Row.t
    -> next:Comb.t Row.t
    -> target:Comb.t Row.t
    -> Comb.t

  val following : wrap_top:Comb.t -> wrap_bottom:Comb.t -> Comb.t -> Comb.t
  val is_full : Comb.t Row.t -> Comb.t
end

module Table : sig
  type t = Bits.t Row.t array

  (** The analyser's rows; pcs it does not reach are empty. *)
  val of_analyser : Analyser.Row.t list -> t
end

(** Checks every pc; words past the program read zero. [period] is [loaded]. *)
val check
  :  ?period:int
  -> config:Program_config.t
  -> words:int list
  -> Table.t
  -> unit Or_error.t

(** [step] as a circuit, for the RTL proof to use the same definition. *)
module I : sig
  type 'a t =
    { side_set_count : 'a
    ; fraction : 'a
    ; loaded : 'a With_valid.t
    ; word : 'a
    ; phase : 'a
    ; period : 'a
    }
  [@@deriving hardcaml]
end

module O = Step

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
