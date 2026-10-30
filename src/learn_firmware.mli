(** Firmware for one engine, written from what [Learn] found, that sends any frame of the
    learned protocol, never-recorded ones included; the host computes nothing but the
    words. It is checked like any other firmware: the analyser and then the kernel must
    accept it under the period it was written for, or there is no firmware.

    The host writes the period first, then for each frame its kind (when there is more
    than one) and its bits, 16 to a word, LSB first in the order sent; a UART's word is a
    character, its parity included. Every run starts at a deadline, [wait t+] on the
    period, so each edge is a whole number of units after the frame's first. *)

open! Core

module Pins : sig
  type t =
    | Line of int (** The line, as an output pin. *)
    | Clocked of
        { clock : int
        ; data : int
        ; deselect : bool
        (** Hold the pin after [clock] high throughout, as a chip select no frame uses. *)
        }
  [@@deriving sexp_of]
end

type t =
  { source : string
  ; period : int (** Cycles a [wait t+]; a unit may take more than one. *)
  ; ticks : int (** Periods a unit. *)
  ; timed : Timed_program.t
  }

(** Errors if the kernel refuses the firmware, or a run is too long for it. *)
val generate : clock_hz:float -> pins:Pins.t -> Learn.t -> t Or_error.t

(** The host's words for one frame, after the period. *)
val words : t -> Learn.t -> kind:int -> bool array -> int list

(** Runs the firmware on the model of an engine for [frames], the host writing each as the
    fifo has room, and records the pins it drives, for [Learn.decode]. Errors on a fault. *)
val simulate
  :  clock_hz:float
  -> pins:Pins.t
  -> t
  -> Learn.t
  -> (int * bool array) list
  -> Recording.t Or_error.t
