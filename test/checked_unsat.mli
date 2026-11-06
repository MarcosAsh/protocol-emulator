(** SAT answers checked either way, on the DIMACS file hardcaml_verify writes for a query:
    cake_lpr, verified in HOL4 down to machine code, must accept cadical's LRAT proof of
    an UNSAT, and a model must make every clause true. Trusted: hardcaml_verify's gates,
    Tseitin encoding, DIMACS writer and model reader, and cake_lpr. [cadical] and
    [cake_lpr] must be on the path ([make -C formal sat_tools]). *)

open! Core
open Hardcaml_verify

(** Runs cadical on [dimacs], writing its answer to [result] and, if UNSAT, an LRAT proof
    to [proof], in text if not [binary]. *)
val cadical
  :  ?binary:bool
  -> dimacs:string
  -> proof:string
  -> result:string
  -> unit
  -> unit Or_error.t

(** Ok when cake_lpr prints exactly [s VERIFIED UNSAT] for [proof] of [dimacs]. *)
val check : dimacs:string -> proof:string -> unit Or_error.t

(** Ok when [result] is SAT and its model, setting no variable twice, makes a literal of
    every clause of [dimacs] true. *)
val check_model : dimacs:string -> result:string -> unit Or_error.t

(** [cadical], UNSAT only once [check] accepts the proof and SAT once [check_model]
    accepts the model. *)
val solver : Solver.run_solver

(** A text LRAT proof with the first literal of its first lemma negated, so the lemma's
    hints no longer derive it. *)
val negate_first_lemma : string list -> string list

(** [solver], but writing a text proof with [negate_first_lemma] applied. A teeth check: a
    QED's UNSAT must then fail [check]. *)
val solver_with_a_bad_proof : Solver.run_solver

(** cadical's model with its first value negated: the lowest bit of the first input that
    the CNF uses. *)
val negate_first_value : string list -> string list

(** [solver], but with [negate_first_value] applied to the model. A teeth check: a
    counterexample that rests on that bit must then fail [check_model]. *)
val solver_with_a_bad_model : Solver.run_solver

(** Prints QED when every case holds [claim] and the cases cover every input. Cases run one
    query at a time, which SAT finds far easier than all at once. A counterexample prints
    the inputs in [show], or all of them. *)
val prove
  :  ?show:string list
  -> string
  -> cases:Comb_gates.t list
  -> claim:Comb_gates.t
  -> unit
