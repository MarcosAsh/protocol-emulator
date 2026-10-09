(** The firmware library as the analyser certifies it and the RTL proves it. Each entry
    says what its certificate rests on: [period] is the bit period the host loads, for
    firmware that takes it from the fifo; [period_floor], where the host picks the rate,
    is the least period it may load, for the deadlines alone, as jitter and sample times
    hold at [period]; [single_capture_edge] says the line makes one edge between arming
    the capture and waiting for it, which is what a start bit gives a receiver that arms
    in time; [no_wrap] says the proof by induction holds while the core is within 84 ms of
    its deadline and of the edge it last captured, which a program needs said of its
    24-bit clock when a wait, or a loop as long as the host says, can leave it arbitrarily
    far behind either. *)

open! Core
open Protocol_emulator

type t =
  { name : string
  ; source : string
  ; config : Program_config.t
  ; period : int option
  ; period_floor : int option
  ; single_capture_edge : bool
  ; no_wrap : bool
  }

val plain
  :  ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> ?no_wrap:bool
  -> string
  -> string
  -> Program_config.t
  -> t

(** [plain] with one edge before the capture and no wrap, as a receiver needs. *)
val receiver
  :  ?period:int
  -> ?period_floor:int
  -> string
  -> string
  -> Program_config.t
  -> t

(** The library's firmware no protocol file holds yet ([Library]). *)
val others : t list
