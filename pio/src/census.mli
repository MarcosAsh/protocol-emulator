(** The pico-examples PIO programs, each translated at the smallest [k] the kernel
    certifies, using the configuration its C code sets and the core's pins. *)

open! Core
open Protocol_emulator

(** The core's clock, 48 MHz. *)
val clock_hz : int

(** The configuration the C code gives a pico-examples program, including its state
    machine clock if the example fixes one. Other programs get [Translate.Setup.default]. *)
val setup : Pioasm.Program.t -> period:int -> Translate.Setup.t

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

(** Splits [k] into [per_cycle] [wait t+]s of [p] cycles plus a fraction in 65536ths. *)
val scale : float -> int * int * int

(** Translates and certifies at [k] with the relation check, then [Timed_program.check].
    [place] moves the pins. *)
val certify
  :  ?place:(Translate.Setup.t -> Translate.Setup.t)
  -> Pioasm.Program.t
  -> k:float
  -> (Translate.t * Timed_program.t, Verdict.t) Result.t

(** The smallest whole [k] that certifies, trying up to [upto] (64). *)
val least : ?upto:int -> Pioasm.Program.t -> Verdict.t

(** The [k] that gives the example's own rate at [clock_hz]. *)
val real_time : Pioasm.Program.t -> float option

(** A datasheet limit on an example's pins, compared with the kernel's bound at
    [clock_hz]. *)
module Limit : sig
  type t =
    { parameter : string
    ; at_least_ns : int
    ; sheet : string
    ; edge : string (** What the kernel bounds, in plain words. *)
    ; bound : int option (** The cycles the kernel proves, or [None]. *)
    }

  val ok : t -> bool

  (** One line with the parameter, the bound in cycles and us, the limit and the sheet. *)
  val to_string : t -> string
end

(** The example's limits with the kernel's bound on [timed]. So far only pio/i2c's tHD;STA
    (pico-examples#796). *)
val limits : Pioasm.Program.t -> Timed_program.t -> Limit.t list

module Row : sig
  type t =
    { file : string
    ; program : string
    ; verdict : Verdict.t
    ; real_time : (float * bool) option
    (** [k] at 48 MHz, and whether it certifies there and meets every limit. *)
    ; refused_limits : string list (** The limits it fails at that [k]. *)
    ; contract : string list
    }
end

val row : file:string -> Pioasm.Program.t -> Row.t

(** A markdown table followed by the totals. *)
val to_string : Row.t list -> string

(** The largest gap, in cycles, that the kernel accepts on the certified rows between
    [b]'s last edge and an edge of [a], where [apart] holds for the bits before it. [None]
    if it accepts no gap. *)
val least_apart
  :  Timed_program.t
  -> dirs:bool
  -> a:int
  -> b:int
  -> apart:(own:bool -> other:bool -> bool)
  -> int option
