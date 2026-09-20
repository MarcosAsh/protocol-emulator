(** One step of a serial CRC, shared by the model and the hardware. [poly] is
    right-aligned with the top bit implicit. Reflected CRCs shift right and take the data
    LSB first, as USB does; otherwise the register shifts left. *)

open! Core
open! Hardcaml

val step : width:int -> poly:int -> reflect:bool -> int -> bit:int -> int

(** The same over signals, with the width and polynomial chosen at run time. *)
module Make (Comb : Comb.S) : sig
  val step
    :  width:Comb.t
    -> poly:Comb.t
    -> reflect:Comb.t
    -> Comb.t
    -> bit:Comb.t
    -> Comb.t
end
