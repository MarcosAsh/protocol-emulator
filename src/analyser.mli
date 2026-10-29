(** Static timing of a program: the phase [now - t] on entry to every instruction, as an
    interval over all executions, with the slack at every deadline wait. Waits on pins and
    fifos leave the phase unbounded above until the next anchor. A wait for the captured
    edge bounds the capture anchor by the time since [capture_arm].

    Every pin write is an edge, placed at the phase the change shows on the pin, and every
    pin read a sample; the width of the interval is the jitter in cycles. Side-set makes
    an edge too, which is how SPI and I2C drive their clocks. *)

open! Core

module Pin_event : sig
  type t =
    | Edge of Interval.t
    | Sample of Interval.t
  [@@deriving sexp_of]
end

(** What side-set does to its pins: [at] is the phase the level shows on the pins. A wait
    drives them when it is reached, so [at] is its own phase and not its release.
    [changes] is false when the pins hold that level already on every way in, a hold and
    not an edge; otherwise [at] covers only the ways in that can change the level. *)
module Side_event : sig
  type t =
    { at : Interval.t
    ; changes : bool
    }
  [@@deriving sexp_of]
end

module Row : sig
  type t =
    { pc : int
    ; instruction : Isa.t
    ; phase : Interval.t
    ; slope : int
    ; offset : Interval.t
    (** The phase less [slope * x] on the way in. In a counted loop the phase drifts but
        this holds still; where the loop falls through, x is zero and the phase lies in it.
        [slope] is zero and [offset] unbounded elsewhere. *)
    ; slack : Interval.t option
    ; may_miss : bool
    ; pin_event : Pin_event.t option
    ; side_event : Side_event.t option
    ; flip : Interval.t option
    (** Where the second half of a Manchester bit shows, which is where this instruction
        issues when it is the next after a Manchester [out]. *)
    ; gaps : (int * Interval.t) list
    (** For an instruction that makes a pin edge, the cycles since the edge before it, for
        each instruction it can follow: a timing that needs no deadline. *)
    ; since_edge : (int * Interval.t) list
    (** For every instruction, the cycles on the way in since the last pin edge showed,
        for each instruction it can follow; [gaps] is this plus the cycle to its own edge. *)
    ; may_underrun : bool
    (** An [out] that may take a data autopull sooner than [Isa.data_settle] cycles after
        the data pointer moved. *)
    ; x : Interval.t
    ; y : Interval.t
    ; period : Interval.t
    (** What the registers hold on the way in, which is what a proof by induction needs to
        tell one turn of a loop from the next. *)
    ; since_arm : Interval.t option
    (** Cycles since [capture_arm], a capturing wait's own stall left out; once
        [captured], the capture is younger. *)
    ; captured : bool (** A wait has seen the captured edge since the arm. *)
    ; awaiting : bool (** Armed, and no wait for the edge has released since. *)
    }
  [@@deriving sexp_of]
end

(** A wait for the captured edge: on the capture pin, for the captured level or edge. *)
val captures : Program_config.t -> Isa.Wait.t -> bool

(** Assumptions about the world, each named so a report can say what it rests on. [period]
    is the value every run-time load of [p] carries. [single_capture_edge] says the capture
    pin is at the other level when [capture_arm] issues and holds the captured level until
    the wait for it releases; without it [mov t, capture] leaves the phase unbounded.
    [period_floor], in place of [period], assumes only that every load carries at least
    it. A state changed [max_passes] times at an address, 256 by default, is widened. *)
val analyse
  :  ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> ?max_passes:int
  -> config:Program_config.t
  -> Isa.t list
  -> Row.t list

(** A line per row: address, instruction, phase, the slack of a deadline wait, [edge],
    [sample] or [side] for what it does to the pins, and [MAY UNDERRUN] on a data pull
    that may come too soon. *)
val to_string : side_set_count:int -> Row.t list -> string

module Verdict : sig
  type t =
    { words : int
    ; deadline_waits : int
    ; worst_slack : int option
    }
  [@@deriving sexp_of]

  val to_string : t -> string
end

(** Analyses a program under its own side-set count and wrap addresses and refuses it if
    any deadline wait can be reached with a phase above zero, or any data autopull may
    come too soon. The error lists every such row as [to_string] prints it. Only reachable
    rows count. The assumptions are [analyse]'s. *)
val check
  :  ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> Asm.Program.t
  -> Verdict.t Or_error.t
