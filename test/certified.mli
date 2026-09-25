(** The firmware library as the analyser certifies it and the RTL proves it. Each entry
    says what its certificate rests on: [period] is the bit period the host loads, for
    firmware that takes it from the fifo; [single_capture_edge] says the line makes one
    edge between arming the capture and waiting for it, which is what a start bit gives a
    receiver that arms in time; [no_wrap] says the proof by induction holds while the core
    is within 84 ms of its deadline and of the edge it last captured, which is what a
    program that can wait forever needs said of its 24-bit clock. *)

open! Core
open Protocol_emulator

type t =
  { name : string
  ; source : string
  ; config : Program_config.t
  ; period : int option
  ; single_capture_edge : bool
  ; no_wrap : bool
  }

val all : t list
val find_exn : string -> t
