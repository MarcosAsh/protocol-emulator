(** The core measuring itself: OUT0 wired back to IN0. *)

open! Core
open Protocol_emulator

(** Toggles OUT0 every [period] cycles and pushes the capture time of each rising edge on
    IN0, which is wired back to OUT0. *)
val firmware : period:int -> string

val config : Program_config.t
val protocol : Protocol.t
