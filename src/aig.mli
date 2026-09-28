(** An and-inverter graph built through [Bits_list.Make], the construction
    [Hardcaml_verify.Comb_gates] makes the kernel's SAT proofs from, printed as ASCII
    AIGER for [formal/kernel_equiv]. Each [Make ()] is a graph of its own. *)

open! Core
open! Hardcaml

module Make () : sig
  include Comb.S

  (** Bits [name[width - 1]] down to [name[0]], free; one bit is [name]. *)
  val input : string -> int -> t

  (** The graph behind [outputs], each bit named as [input] names them. *)
  val to_aiger : (string * t) list -> string
end
