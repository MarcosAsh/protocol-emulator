open! Core
open Protocol_emulator

(** Steps the model [cycles] times with constant [inputs] and returns the level of OUT0
    after each step. *)
val run : Machine.t -> cycles:int -> inputs:int -> Machine.t * int list
