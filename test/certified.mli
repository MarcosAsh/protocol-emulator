(** The firmware library as the analyser certifies it and the RTL proves it. Each entry
    says what its certificate rests on. [period] is the bit period the host loads, for
    firmware that takes it from the fifo. [period_floor], where the host picks the rate,
    is the least period it may load, for the deadlines alone (jitter and sample times hold
    at [period]). [single_capture_edge]: the line makes one edge between arming the
    capture and waiting for it. [no_wrap]: the induction holds while the core is within 84
    ms of its deadline and of its last captured edge, which a 24-bit clock needs when a
    wait or a host-length loop can leave it far behind. [any_data]: the data memory reads
    as anything every cycle, where the rest read zeros, which covers every table a table
    interpreter can load. *)

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
  ; any_data : bool
  }

val plain
  :  ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> ?no_wrap:bool
  -> ?any_data:bool
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

(** [plain] for firmware [%firmware] checked, under the assumptions it was checked under.
    One checked at a least period, [~period_floor], needs the [period] the host loads. *)
val of_firmware
  :  ?period:int
  -> ?no_wrap:bool
  -> ?any_data:bool
  -> string
  -> Timed_program.t
  -> t
