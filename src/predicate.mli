(** Compiles a predicate over input pin events to firmware that pulses a verdict pin a
    fixed number of cycles after each match.

    After the event the firmware anchors [t], adds a budget and waits on it before the
    verdict, so every match lands at the same cycle. The kernel certifies that wait is
    never late, which makes the latency exact; a latency the code cannot meet is a missed
    deadline, and refused with the cycles it is short by. *)

open! Core

module Edge : sig
  type t =
    { pin : int
    ; rising : bool
    }
  [@@deriving sexp_of, compare, equal]
end

module Level : sig
  type t =
    { pin : int
    ; high : bool
    }
  [@@deriving sexp_of, compare, equal]
end

(** [Edge_while] reads the guard once, [Certificate.guard_at] cycles after the edge. *)
type t =
  | Edge of Edge.t
  | Edge_while of
      { edge : Edge.t
      ; guard : Level.t
      }
[@@deriving sexp_of, compare, equal]

(** As in ["pin 0 falls while pin 1 is high"]. *)
val to_string : t -> string

(** Cycles count from the one in which the core first samples the event. [latency] is to
    the verdict's issue, so the pin shows it a cycle later; [blind_after_match] and
    [blind_after_reject] are the cycles after an event in which a second goes unseen. *)
module Certificate : sig
  type t =
    { latency : int
    ; guard_at : int option
    ; blind_after_match : int
    ; blind_after_reject : int option
    ; verdict_pc : int
    }
  [@@deriving sexp_of]
end

module Firmware : sig
  type t =
    { source : string
    ; program : Asm.Program.t
    ; config : Program_config.t
    ; certificate : Certificate.t
    }
end

(** [verdict_pin] defaults to OUT0. The event and guard pins must be inputs or wires. *)
val compile : ?verdict_pin:int -> latency:int -> t -> Firmware.t Or_error.t
