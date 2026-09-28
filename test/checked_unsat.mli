(** SAT answers whose UNSAT is checked. cadical proves the DIMACS file hardcaml_verify
    writes for a query, and cake_lpr, verified in HOL4 down to machine code, must accept
    its LRAT proof of that same file. Trusted: hardcaml_verify's gates, Tseitin encoding
    and DIMACS writer, and cake_lpr. [cadical] and [cake_lpr] must be on the path
    ([make -C formal sat_tools]). *)

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

(** [cadical], and UNSAT only once [check] accepts the proof; SAT is cadical's model,
    unchecked. *)
val solver : Solver.run_solver

(** Prints QED when every case holds [claim] and the cases cover every input, one query at
    a time, which SAT finds far easier than all at once. A counterexample prints the
    inputs in [show], or all of them. *)
val prove
  :  ?show:string list
  -> string
  -> cases:Comb_gates.t list
  -> claim:Comb_gates.t
  -> unit
