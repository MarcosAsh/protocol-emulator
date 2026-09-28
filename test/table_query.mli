(** Asks SAT whether any table passes the kernel, pc 0 held full as [Kernel.check] holds
    it and every other row free, so [None] is a limit of the kernel's rows, not the
    analyser's, and an UNSAT cake_lpr checks ([Checked_unsat]). Like [Kernel.check] it
    checks every pc, reads words past the program as zero and takes [period] as what every
    run-time load of [p] carries. *)

open! Core
open Protocol_emulator

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

(** [witness] of the firmware, assembled, as a yes or no. *)
val some_table_passes : ?offsets:bool -> Certified.t -> bool
