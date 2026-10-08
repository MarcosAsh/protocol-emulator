(** Several [Machine]s on one set of pins: the model of [Engines]. Pins are the OR of the
    engines' drive; an engine reads another's driven bidirectional pin instead of the pad,
    and any engine's drive on a wire, all from the state before the step since the pins
    are registered. Every [Machine] gets the same data, as the memory is shared. An engine
    with a fault drives nothing and is stopped a step later, as [Engines] does. *)

open! Core

type t = private { engines : Machine.t list }

val create : Machine.t list -> t

(** One cycle of every engine. *)
val step : t -> pads:int -> t

val pin_out : t -> int
val pin_dir : t -> int

(** The host acting on engine [n]. *)
val update : t -> int -> f:(Machine.t -> Machine.t) -> t
