(** The glitch map. Engine 0 sends 0xFF UART frames on wire 20, each with a low pulse one
    cycle wide [k] cycles after its start bit shows, and engine 1's [uart_rx] reads them.
    The receiver's rows name the one [k] each sample sees; a sweep of [k] over the frame
    holds every byte the receiver pushes to that. *)

open! Core
open Protocol_emulator

(** Cycles a bit, the one [Certified]'s [uart_rx] is proved at. *)
val period : int

(** Every [k] swept: from the first that leaves the start bit, to two periods past the
    stop bit. *)
val pulses : int list

(** A generator with its pulse at [k], checked by the kernel. *)
module Image : sig
  type t =
    { k : int
    ; timed : Timed_program.t
    ; pulse : Interval.t (** From the rows: its falling edge less the start bit's. *)
    }
end

val image : int -> Image.t

(** [Firmware.uart_rx] on the wire, checked by the kernel under the single-edge
    assumption. *)
val receiver : Timed_program.t

module Sample : sig
  type t =
    { pc : int
    ; pass : int (** Which time the frame reaches [pc], from 0. *)
    ; at : Interval.t (** Cycles from the start bit showing. *)
    }
  [@@deriving sexp_of]
end

(** Where the capture may be against the edge it releases on, by the analyser's rows or by
    the kernel's own step on [mov t, capture]. *)
module Capture_age : sig
  type t =
    | Rows
    | Kernel
  [@@deriving sexp_of]
end

(** The receiver's samples along a frame, from its rows, the last the stop bit check. The
    re-arm after it is [Isa.jmp_cycles] later. *)
val samples : Capture_age.t -> Sample.t list

module Outcome : sig
  type t =
    { words : int list (** What the receiver pushed. *)
    ; framing_error : bool
    }
  [@@deriving sexp_of, equal]
end

(** What the rows say a pulse at [k] does: a data bit's sample clears that bit, the
    check's raises the framing error, and a pulse after the re-arm is a start bit. *)
val predict : int -> Outcome.t

(** One frame, its word pushed at cycle 10, on the model alone. *)
val model : Image.t -> Outcome.t

(** The same on [Engines] beside the model, with any mismatch. *)
val rtl : Image.t -> Outcome.t * System_lockstep.Mismatch.t option

(** The receiver's words and the generator's, as the board loads them. *)
val receiver_config : Program_config.t

val generator_config : Program_config.t
