(** Moving a field of bits between a register and a run of pins. The run starts at pin
    [base], is [count] long and carries on from the last pin to pin 0. [base] must be a
    pin and [count] at most [Isa.data_bits]. *)

open! Core
open! Hardcaml

module Make (Comb : Comb.S) : sig
  (** Ones in the low [count] bits. *)
  val count_mask : Comb.t -> Comb.t

  (** The pins of the run in the low bits, zero above them. *)
  val read : Comb.t -> base:Comb.t -> count:Comb.t -> Comb.t

  (** The pins with the run replaced by the low bits of [value], where [writable]. *)
  val write
    :  Comb.t
    -> base:Comb.t
    -> count:Comb.t
    -> value:Comb.t
    -> writable:(int -> bool)
    -> Comb.t
end
