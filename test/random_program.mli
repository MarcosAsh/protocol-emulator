(** Random configurations and programs of words that decode, for tests that compare the
    model with the hardware or with itself. *)

open! Core
open Protocol_emulator

val config : Splittable_random.t -> Program_config.t

(** A full program memory of random words that decode, never [halt]. With [waits] set to
    [`Input_pins], the only waits are on input pins, which random inputs release within a
    few cycles. A deadline wait on a random [t] or a fifo wait would stall the core for
    the rest of the run. *)
val program
  :  ?waits:[ `Any | `Input_pins ]
  -> Splittable_random.t
  -> config:Program_config.t
  -> int list

(** One word of [program]. *)
val word
  :  ?waits:[ `Any | `Input_pins ]
  -> Splittable_random.t
  -> side_set_count:int
  -> int
