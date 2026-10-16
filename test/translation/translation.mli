(** Each module of the circuit the tests simulate, checked equal to the same module of a
    Verilog file as Yosys reads it, by [Hardcaml_verify.Sec].

    Sec pairs state by name, so the Hardcaml side is rebuilt to the form Yosys gives:
    clear and enable folded into a flop's [d] (clear first, as Cyclesim), a memory as a
    flop per word named [mem[i]], an asynchronous reset taken through inverters, and each
    flop named as the Verilog declares it. Instances pair by label with their ports
    compared, so the modules compose to the chip. Sec ignores initial values, compared
    here apart. *)

open! Core
open! Hardcaml

module Verilog : sig
  type t

  (** [files] through Yosys with [lib] as black boxes: [proc -norom] keeps case statements
      as logic, [memory_map] makes each memory word a flop. *)
  val read : files:string list -> lib:string list -> top:string -> t Or_error.t

  (** Every module but the black boxes. *)
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
