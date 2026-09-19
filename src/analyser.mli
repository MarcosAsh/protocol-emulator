(** Static timing of a program: the phase [now - t] on entry to every instruction, as an
    interval over all executions, with the slack at every deadline wait. Waits on pins and
    fifos leave the phase unbounded above until the next anchor. A wait for the captured
    edge bounds the capture anchor by the time since [capture_arm]. *)

open! Core

module Row : sig
  type t =
    { pc : int
    ; instruction : Isa.t
    ; phase : Interval.t
    ; slack : Interval.t option
    ; may_miss : bool
    }
  [@@deriving sexp_of]
end

val analyse : config:Program_config.t -> Isa.t list -> Row.t list
val to_string : side_set_count:int -> Row.t list -> string
