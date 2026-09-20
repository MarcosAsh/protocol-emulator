(** Static timing of a program: the phase [now - t] on entry to every instruction, as an
    interval over all executions, with the slack at every deadline wait. Waits on pins and
    fifos leave the phase unbounded above until the next anchor. A wait for the captured
    edge bounds the capture anchor by the time since [capture_arm].

    Every pin write is an edge, placed at the phase the change shows on the pin, and every
    pin read a sample; the width of the interval is the jitter in cycles. *)

open! Core

module Pin_event : sig
  type t =
    | Edge of Interval.t
    | Sample of Interval.t
  [@@deriving sexp_of]
end

module Row : sig
  type t =
    { pc : int
    ; instruction : Isa.t
    ; phase : Interval.t
    ; slack : Interval.t option
    ; may_miss : bool
    ; pin_event : Pin_event.t option
    }
  [@@deriving sexp_of]
end

(** [period] is the value every run-time load of [p] is assumed to carry, for firmware
    that takes its bit period from the host. *)
val analyse : ?period:int -> config:Program_config.t -> Isa.t list -> Row.t list

val to_string : side_set_count:int -> Row.t list -> string
