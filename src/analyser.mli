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

(** Assumptions about the world, each named so a report can say what it rests on. [period]
    is the value every run-time load of [p] carries, for firmware that takes its bit
    period from the host. [single_capture_edge] says the capture pin is at the other level
    when [capture_arm] issues and holds the captured level until the wait for it releases,
    which is what a start bit gives a receiver that arms in time; without it a wait on the
    capture pin proves nothing about the capture register, and [mov t, capture] leaves the
    phase unbounded. *)
val analyse
  :  ?period:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> Isa.t list
  -> Row.t list

val to_string : side_set_count:int -> Row.t list -> string
