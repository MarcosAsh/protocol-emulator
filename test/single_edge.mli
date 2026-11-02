(** The single capture edge a receiver's certificate rests on, watched from outside the
    core as formal/phase_step.sv assumes it: the capture pin is at the other level when
    [capture_arm] takes effect and, once at the captured level, stays there until a wait
    for it releases. The chip does not watch it; this is how a test does. *)

open! Core
open Protocol_emulator

type t

val create : unit -> t

(** The step [before] took on [inputs] to [after]. *)
val step : t -> before:Machine.t -> inputs:int -> after:Machine.t -> t

(** Whether it held on every step so far. *)
val held : t -> bool
