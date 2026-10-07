(** [Load_check.walk] in hardware: on [check] it walks the halted engine's program, a word
    a pc through [program_read], against the certificate at [base] in the data memory,
    through [data_read], with the kernel's own [one_way], a field of a row at a time. It
    reads nothing from the host but the certificate, so what it accepts is the program the
    engine will run. [finished] pulses once, with [accepted], or [reject_pc] and [reason]:
    the index of the first failing conjunct in [Kernel.Conjuncts.to_list] order, or
    [out_of_order] or [left_over], or [aborted] if [abort] came while it walked. *)

open! Core
open! Hardcaml

(** Cycles from the walk choosing a data address to taking its word: one for [data_read]'s
    register, then two for either engine's turn. *)
val data_wait : int

val aborted : int
val out_of_order : int
val left_over : int

(** What the host sets before a check: where the certificate starts, the period every
    run-time load of [p] is assumed to carry, and the single-edge assumption. Taken as the
    check begins; a write during a walk counts from the next check. *)
module Setup : sig
  type 'a t =
    { base : 'a
    ; loaded : 'a With_valid.t
    ; single_edge : 'a
    }
  [@@deriving hardcaml]
end

(** The last check's outcome, as the host reads it. *)
module Verdict : sig
  type 'a t =
    { busy : 'a
    ; accepted : 'a
    ; reject_pc : 'a
    ; reason : 'a
    }
  [@@deriving hardcaml]
end

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; check : 'a
    ; abort : 'a (** Ends a walk unaccepted: something it reads was written. *)
    ; config : 'a Engine.Config.t
    ; setup : 'a Setup.t
    ; program_word : 'a (** The word at [program_read], a cycle later. *)
    ; data_word : 'a (** The word at [data_read] once it has held two cycles. *)
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { program_read : 'a With_valid.t
    ; data_read : 'a With_valid.t
    ; busy : 'a
    ; finished : 'a
    ; accepted : 'a
    ; reject_pc : 'a
    ; reason : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
