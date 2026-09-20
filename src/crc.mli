(** One step of a serial CRC, shared by the model and the hardware tests as the reference.
    [poly] is right-aligned with the top bit implicit. Reflected CRCs shift right and take
    the data LSB first, as USB does; otherwise the register shifts left. *)

open! Core

val step : width:int -> poly:int -> reflect:bool -> int -> bit:int -> int
