(** The IHP 512x16 macro behind the [Program_memory] interface. BIST is tied off and
    [A_DLY] is tied high as the datasheet requires. *)

open! Core
open! Hardcaml

val name : string

val hierarchical
  :  ?instance:string
  -> Scope.t
  -> Signal.t Program_memory.I.t
  -> Signal.t Program_memory.O.t
