(** Static timing of a program: the phase [now - t] on entry to every instruction, as an
    interval over all executions, with the slack at every deadline wait. Pin and fifo
    waits leave it unbounded above until the next anchor. Every pin write, side-set too,
    is an edge at the phase it shows on the pin, and the interval's width is its jitter. *)

open! Core

module Pin_event : sig
  type t =
    | Edge of Interval.t
    | Sample of Interval.t
  [@@deriving sexp_of]
end

(** What side-set does to its pins. [at] is the phase the level shows, for a wait its own
    phase and not its release. [changes] is false when every way in already holds that
    level, and otherwise [at] covers only the ways in that can change it. *)
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
    (** The phase minus [slope * x] on the way in. In a counted loop the phase drifts but
        this stays put; where the loop falls through, x is zero and the phase lies in it.
        [slope] is zero and [offset] unbounded elsewhere. *)
    ; slack : Interval.t option
    ; may_miss : bool
    ; pin_event : Pin_event.t option
    ; side_event : Side_event.t option
    ; flip : Interval.t option
    (** Where the second half of a Manchester bit shows, which is where this instruction
        issues when it comes right after a Manchester [out]. *)
    ; gaps : (int * Interval.t) list
    (** For an instruction that makes a pin edge, the cycles since the previous edge, for
        each instruction it can follow. This is a timing that needs no deadline. *)
    ; since_edge : (int * Interval.t) list
    (** For every instruction, the cycles on the way in since the last pin edge showed,
        for each instruction it can follow. [gaps] is this plus the cycle to its own edge. *)
    ; may_underrun : bool
    (** An [out] that may take a data autopull sooner than [Isa.data_settle] cycles after
        the data pointer moved. *)
    ; x : Interval.t
    ; y : Interval.t
    ; period : Interval.t
    (** What the registers hold on the way in, which a proof by induction needs to tell
        one turn of a loop from the next. *)
    ; since_arm : Interval.t option
    (** Cycles since [capture_arm], leaving out a capturing wait's own stall. Once
        [captured], the capture is younger than this. *)
    ; captured : bool (** A wait has seen the captured edge since the arm. *)
    ; awaiting : bool (** Armed, and no wait for the edge has released since. *)
    }
  [@@deriving sexp_of]
end

(** A wait for the captured edge: on the capture pin, for the captured level or edge. *)
val captures : Program_config.t -> Isa.Wait.t -> bool

(** [period] is what every run-time load of [p] carries, [period_floor] the least it does.
    [single_capture_edge]: the capture pin is at the other level at [capture_arm] and
    holds the captured level until its wait releases; without it [mov t, capture] is
    unbounded. A state changed [max_passes] times at an address is widened. *)
val analyse
  :  ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> ?max_passes:int
  -> config:Program_config.t
  -> Isa.t list
  -> Row.t list

(** A line per row: address, instruction, phase, the slack of a deadline wait, then
    [edge], [sample] or [side] for what it does to the pins, and [MAY UNDERRUN] on a data
    pull that may come too soon. *)
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

(** Analyses a program under its own side-set count and wrap addresses. Refuses it if any
    deadline wait can be reached with a phase above zero, or any data autopull may come
    too soon. The error lists every such row as [to_string] prints it. Only reachable rows
    count. The assumptions are [analyse]'s. *)
val check
  :  ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> Asm.Program.t
  -> Verdict.t Or_error.t
