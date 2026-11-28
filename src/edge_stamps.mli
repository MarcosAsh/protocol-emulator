(** Edge times on any input pin, for the host. A cycle in which a pin under [mask] moves
    queues [now] and every pad's level, so the host diffs entries to see which moved.
    [now] is the caller's time base (the chip uses [engine]'s capture clock). The queue is
    four deep: an edge while full is dropped and sets [lost] until [flush], which empties
    it. The head of an empty queue reads zero. *)

open! Core
open! Hardcaml

val depth : int
val level_bits : int

module Entry : sig
  type 'a t =
    { time : 'a
    ; pins : 'a
    }
  [@@deriving hardcaml]
end

module Control : sig
  type 'a t =
    { mask : 'a
    ; engine : 'a (** Whose [now] times the edges; for the caller. *)
    ; flush : 'a
    ; pop : 'a
    }
  [@@deriving hardcaml]
end

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; pads : 'a
    ; now : 'a
    ; control : 'a Control.t
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { head : 'a Entry.t
    ; level : 'a
    ; lost : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
