(** Checks each module of the circuit the tests simulate against the same module of a
    Verilog file (as Yosys reads it) using [Hardcaml_verify.Sec].

    Sec pairs state by name, so the Hardcaml side is rebuilt into the form Yosys gives:
    clear and enable are folded into a flop's [d] (clear first, as Cyclesim does), a
    memory becomes one flop per word named [mem[i]], an asynchronous reset goes through
    inverters, and each flop takes the name the Verilog declares. Instances pair by label
    and their ports are compared, so the modules compose to the whole chip. Sec ignores
    initial values, so they are compared separately. *)

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
