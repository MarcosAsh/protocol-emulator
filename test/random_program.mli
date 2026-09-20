(** Random configurations and programs of words that decode, for tests that compare the
    model with the hardware or with itself. *)

open! Core
open Protocol_emulator

val config : Splittable_random.t -> Program_config.t

(** Never [halt]. With [waits] [`Input_pins] the only waits are on input pins, which
    random inputs release within a few cycles; a deadline wait on a random [t] or a fifo
    wait would hold the core for the rest of a run. *)
val word
  :  ?waits:[ `Any | `Input_pins ]
  -> Splittable_random.t
  -> side_set_count:int
  -> int

(** A full program memory of [word]s. *)
val program
  :  ?waits:[ `Any | `Input_pins ]
  -> Splittable_random.t
  -> config:Program_config.t
  -> int list
