(** The pico-examples PIO programs, each translated at the least [k] the kernel certifies,
    under the configuration its own C code sets, with pins of the core's. *)

open! Core
open Protocol_emulator

(** The core's clock, 50 MHz. *)
val clock_hz : int

(** The C code's configuration of a pico-examples program, and its state machine clock
    where the example fixes it. [Translate.Setup.default] for any other program. *)
val setup : Pioasm.Program.t -> period:int -> Translate.Setup.t

val sm_hz : Pioasm.Program.t -> float option

module Verdict : sig
  type t =
    | Certified of
        { k : int
        ; words : int
        }
    | Not_certified of { reason : string }
    | Refused of Translate.Refusal.t list
  [@@deriving sexp_of]
end

(** [k] as [per_cycle] [wait t+]s of [p] cycles and a fraction in 65536ths. *)
val scale : float -> int * int * int

(** Translates and certifies at [k]: the relation check, then [Timed_program.check]. *)
val certify
  :  Pioasm.Program.t
  -> k:float
  -> (Translate.t * Timed_program.t, Verdict.t) Result.t

(** The least whole [k] up to [upto] (64) that certifies. *)
val least : ?upto:int -> Pioasm.Program.t -> Verdict.t

(** [k] at [clock_hz] for the example's own rate. *)
val real_time : Pioasm.Program.t -> float option

module Row : sig
  type t =
    { file : string
    ; program : string
    ; verdict : Verdict.t
    ; real_time : (float * bool) option (** [k] at 50 MHz, and whether it certifies. *)
    ; contract : string list
    }
end

val row : file:string -> Pioasm.Program.t -> Row.t

(** A markdown table, then the totals. *)
val to_string : Row.t list -> string

(** The most cycles from [b]'s last edge to an edge of [a], where [apart] holds of the
    bits before it, that the kernel accepts on the certified rows; [None] when it accepts
    none. *)
val least_apart
  :  Timed_program.t
  -> dirs:bool
  -> a:int
  -> b:int
  -> apart:(own:bool -> other:bool -> bool)
  -> int option
