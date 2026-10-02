(** Asks SAT whether any table passes the kernel, pc 0 held full as [Kernel.check] holds
    it and every other row free, so [None] is a limit of the kernel's rows, not the
    analyser's, and an UNSAT cake_lpr checks ([Checked_unsat]). Like [Kernel.check] it
    checks every pc, reads words past the program as zero and takes [period] as what every
    run-time load of [p] carries. *)

open! Core
open Protocol_emulator

(** That the kernel accepts [table] at every pc, with [loaded] as the run-time load of
    [p]. *)
val accepts
  :  loaded:Hardcaml_verify.Comb_gates.t Hardcaml.With_valid.t
  -> single_capture_edge:bool
  -> config:Program_config.t
  -> words:int list
  -> Hardcaml_verify.Comb_gates.t Kernel.Row.t array
  -> Hardcaml_verify.Comb_gates.t

(** That the kernel accepts [table] at every run-time load of [floor] or more, the load an
    input named [loaded] and the rest constant. *)
val every_load_from
  :  floor:int
  -> single_capture_edge:bool
  -> config:Program_config.t
  -> words:int list
  -> Kernel.Table.t
  -> Hardcaml_verify.Comb_gates.t

(** The solver's model as a table, a row input it leaves out read as zero. Only
    [Kernel.check] on it is a verdict. Without [offsets] every offset is full. Raises if
    [solver] (default [Checked_unsat.solver]) fails. *)
val witness
  :  ?solver:Hardcaml_verify.Solver.run_solver
  -> ?offsets:bool
  -> ?period:int
  -> single_capture_edge:bool
  -> config:Program_config.t
  -> words:int list
  -> unit
  -> Kernel.Table.t option

(** [witness] of the firmware, assembled, as a yes or no. Raises if [Kernel.check] refuses
    the table a yes rests on. *)
val some_table_passes : ?offsets:bool -> Certified.t -> bool
