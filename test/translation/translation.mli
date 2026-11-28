(** Checks each module of the simulated circuit against the same module of a Verilog file
    (as Yosys reads it) using [Hardcaml_verify.Sec]. Sec pairs state by name, so the
    Hardcaml side is rebuilt in Yosys's form: clear and enable folded into a flop's [d],
    memory as a flop per word named [mem[i]], asynchronous reset through inverters.
    Instances pair by label. Initial values are compared apart. *)

open! Core
open! Hardcaml

module Verilog : sig
  type t

  (** Reads [files] through Yosys with [lib] as black boxes. [proc -norom] keeps case
      statements as logic, and [memory_map] turns each memory word into a flop. *)
  val read : files:string list -> lib:string list -> top:string -> t Or_error.t

  (** Every module except the black boxes. *)
  val modules : t -> string list
end

module Outcome : sig
  type t =
    { flops : int
    ; bits : int
    ; equal : Hardcaml_verify.Sec.Equivalence_result.t
    }
  [@@deriving sexp_of]
end

val check : Rtl.Circuit_instance.t -> Verilog.t -> Outcome.t Or_error.t
