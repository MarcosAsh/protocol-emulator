(** A four deep fifo between the host and the core. A push into a full fifo and a pop from
    an empty one are ignored; the core turns those into fault bits. [head] is the oldest
    word and is valid when [empty] is low. *)

open! Core
open! Hardcaml

val depth : int
val level_bits : int

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; push : 'a With_valid.t
    ; pop : 'a
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
