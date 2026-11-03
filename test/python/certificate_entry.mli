(** The keys [bench.load] certifies a Python firmware entry with: the certificate the chip
    checks [words] against under [assumptions], the period it takes as loaded, and the
    floor and single-edge flags, as dict lines four spaces in. *)

open! Core
open Protocol_emulator
open Protocol_emulator_test

val print : System_lockstep.Assumptions.t -> config:Program_config.t -> int list -> unit

(** [print] for [timed] under what it was analysed under. *)
val print_timed : Timed_program.t -> unit
