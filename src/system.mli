(** Several [Machine]s on one set of pins: the model of [Engines].

    A pin carries the OR of what the engines drive onto it. An engine reads its own
    outputs back by itself; of the others it sees a bidirectional pin that one of them
    drives instead of the pad, and on a wire what any of them drives. All of this is taken
    from the state before the step, as the pins are registers in the hardware. The engines
    share one data memory, so every [Machine] is given the same data. *)

open! Core

type t = private { engines : Machine.t list }

val create : Machine.t list -> t

(** One cycle of every engine. [pads] is the level at the pad of every pin. *)
val step : t -> pads:int -> t

(** What engine [n] is handed as [inputs] for the next step. *)
val seen : t -> int -> pads:int -> int

(** What the chip drives onto the pads and which bidirectional pads it drives. *)
val pin_out : t -> int

val pin_dir : t -> int

(** The host at one engine, by its number. *)
val update : t -> int -> f:(Machine.t -> Machine.t) -> t
