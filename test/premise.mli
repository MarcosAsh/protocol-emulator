(** Watches the single-edge premise a receiver's certificate rests on, as
    [formal/phase_step.sv] assumes it: the capture pin is at the other level when
    [capture_arm] issues and, once at the captured level, stays there until a wait for it
    releases. A wait for it is a wait on the capture pin for the captured level or edge.
    Like [Coverage] it only watches the model from outside, so it runs beside the
    [Machine] or in [Lockstep.run]. *)

open! Core
open Protocol_emulator

type t

val create : unit -> t

(** [after] is [Machine.step before], perhaps stopped or resumed since. An instruction
    completed when [before] was neither halted nor stalled and [after] has moved past it
    or begun its delay, and the level is the one [after] sampled. *)
val record : t -> before:Machine.t -> after:Machine.t -> unit

module Count : sig
  type t =
    { arms : int
    ; at_captured_level : int (** Arms that issued with the pin at the captured level. *)
    ; left_captured_level : int
    (** Arms after which the pin reached the captured level and left it again before the
        wait for it released. *)
    }
  [@@deriving sexp_of]
end

val count : t -> Count.t
