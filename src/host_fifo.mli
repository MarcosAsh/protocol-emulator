(** Eight deep. Push when full and pop when empty are ignored; [full] is low in a cycle
    that pops, so a push can land then. [flush] empties the fifo, and a word pushed in the
    same cycle is lost with the rest. *)

open! Core
open! Hardcaml

val depth : int
val level_bits : int

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; push : 'a With_valid.t
    ; pop : 'a
    ; flush : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { head : 'a
    ; level : 'a
    ; empty : 'a
    ; full : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
