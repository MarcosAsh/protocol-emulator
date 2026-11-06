(** Edge times on any input pin, for the host. A cycle in which a pin under [mask] differs
    from the cycle before queues [now] and every pad's level, so edges on several pins in
    one cycle share an entry and the host diffs consecutive entries to see which moved.
    [now] is the time base the caller picks (the chip uses [engine]'s, the clock its
    [capture] reads), so a stamp on the capture pin equals that engine's capture.

    The queue is four deep. An edge while full is dropped and sets [lost] until [flush],
    which also empties the queue. [pop] takes the head; the head of an empty queue reads
    zero. *)

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
