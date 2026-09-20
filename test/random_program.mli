(** Random configurations and programs of words that decode, for tests that compare the
    model with the hardware or with itself. *)

open! Core
open Protocol_emulator

val config : Splittable_random.t -> Program_config.t

(** Never [halt]. With [fifo_waits] false, never [wait tx] or [wait rx] either. *)
val word : ?fifo_waits:bool -> Splittable_random.t -> side_set_count:int -> int

(** A full program memory of [word]s. *)
val program
  :  ?fifo_waits:bool
  -> Splittable_random.t
  -> config:Program_config.t
  -> int list
