(** Datasheet limits on the bench firmware's pins, each with the sheet it is read from,
    and the firmware's bound at the clock it ships at: the kernel's, on the analyser's
    rows, or for a width the pin's levels cannot tell apart, an exact run of the words
    with the host on time. *)

open! Core
open Protocol_emulator

module Sheet : sig
  type t =
    { part : string
    ; document : string (** With its revision. *)
    ; page : string
    }
end

(** The pin's levels in a run, high or low, and the cycles each lasted. *)
module Levels : sig
  type t = (bool * int) list
end

module Bound : sig
  type t =
    | Kernel of (Program_config.t -> int -> Kernel.Spacing.Spec.t)
    (** The kernel accepts the spacing, at a number of cycles, on the analyser's rows. *)
    | Run of
        { pin : Program_config.t -> int
        ; widths : clock_hz:int -> Levels.t -> int list
        } (** Widths in cycles, of the pin in [stimulus]'s run. *)
end

module Limit : sig
  type t =
    | At_least of float (** In ns. *)
    | At_most of float
end

type t =
  { firmware : string (** As in [Bench]. *)
  ; parameter : string
  ; limit : Limit.t
  ; sheet : Sheet.t
  ; bound : Bound.t
  }

val all : t list

(** What a run gives the host: bursts of words, each once the one before is in the core,
    its fifo empty and the pin quiet for [quiet] cycles. *)
module Stimulus : sig
  type t =
    { bursts : int list list
    ; quiet : int
    ; cycles : int
    }
end

val stimulus : Bench.t -> Stimulus.t option
val levels : Bench.t -> pin:int -> Stimulus.t -> Levels.t

module Verdict : sig
  type t =
    { limit : Limit.t
    ; needed : int (** The least, or most, cycles the limit leaves. *)
    ; bound : int option (** The firmware's: least for [At_least], most for [At_most]. *)
    ; ok : bool
    }
end

(** Every limit on [bench], by [bench]'s name unless [limits] are given. *)
val check : ?limits:t list -> Bench.t -> (t * Verdict.t) list

(** A line per limit: its parameter, the limit, the bound in cycles and ns, and FAIL where
    it does not meet the limit. *)
val to_string : Bench.t -> (t * Verdict.t) list -> string

(** Raises unless every limit is met. *)
val check_exn : Bench.t -> unit
