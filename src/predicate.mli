(** Compiles a predicate over input pin events to firmware that pulses a verdict pin a
    certified number of cycles after each match. A deadline wait pads each match to the
    latency, so the kernel's acceptance fixes it and a latency the code cannot meet is
    refused, short by the wait's lateness. [formal/event_step.sby] proves the event wait
    releases, and a poll or guard jump goes, by the sample of the cycle it issues in. *)

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

(** [Edge_while] reads the guard once, [guard_at] cycles after the edge. [Quiet] pulses
    once the pin has held still for the latency since its last edge. *)
type t =
  | Edge of Edge.t
  | Edge_while of
      { edge : Edge.t
      ; guard : Level.t
      }
  | Quiet of { pin : int }
[@@deriving sexp_of, compare, equal]

(** As in ["pin 0 falls while pin 1 is high"] or ["pin 2 stops moving"]. *)
val to_string : t -> string

(** The inverse of [to_string], words separated by any number of spaces. *)
val of_string : string -> t Or_error.t

(** How the firmware sees events. [Waits]: in the cycle they are sampled, but for
    [blind_after_match] or [blind_after_reject] cycles after one. [Polls]: an edge shows
    up to [min_run - 1] cycles late, and a run of the pin shorter than [min_run], or an
    edge in the last [unseen_before_verdict] cycles before a verdict, may go unseen. *)
module Sampling : sig
  type t =
    | Waits of
        { guard_at : int option
        ; blind_after_match : int
        ; blind_after_reject : int option
        }
    | Polls of
        { min_run : int
        ; unseen_before_verdict : int
        }
  [@@deriving sexp_of]
end

(** The verdict issues [latency] to [latency + jitter] cycles after the cycle in which the
    core first samples the event, so the pin shows it a cycle later. *)
module Certificate : sig
  type t =
    { latency : int
    ; jitter : int
    ; sampling : Sampling.t
    ; verdict_pcs : int list
    }
  [@@deriving sexp_of]
end

module Firmware : sig
  type t =
    { source : string
    ; program : Asm.Program.t
    ; config : Program_config.t
    ; budget_from_host : int option
    (** A budget too long for [set], which the host writes into the tx fifo first. *)
    ; certificate : Certificate.t
    }
end

(** [verdict_pin] defaults to OUT0. The pins watched must be inputs, bidirectional pins or
    wires. *)
val compile : ?verdict_pin:int -> latency:int -> t -> Firmware.t Or_error.t
