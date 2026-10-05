(** [Load_check.walk] in hardware: on [check] it walks the halted engine's program, a word
    a pc through [program_read], against the certificate at [base] in the data memory,
    through [data_read], with the kernel's own [conjuncts] and [fall_through]. It reads
    nothing from the host but the certificate, so what it accepts is the program the
    engine will run. [finished] pulses once, with [accepted], or [reject_pc] and [reason]:
    the index of the first failing conjunct in [Kernel.Conjuncts.to_list] order, or
    [out_of_order] or [left_over]. *)

open! Core
open! Hardcaml

(** Cycles from presenting a data address to its word, enough for either engine's turn. *)
val data_wait : int

val out_of_order : int
val left_over : int

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; check : 'a
    ; config : 'a Engine.Config.t
    ; loaded : 'a With_valid.t
    ; single_edge : 'a
    ; base : 'a
    ; program_word : 'a (** The word at [program_read], a cycle later. *)
    ; data_word : 'a (** The word at [data_read], [data_wait] cycles later. *)
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
