(** Datasheet limits on the bench firmware's pins, each with the sheet it is read from,
    and the firmware's bound at the clock it ships at: the kernel's, on the analyser's
    rows, or for a width the pin's levels cannot tell apart, an exact run of the words
    with the host on time. A bound has to clear its limit by the margin, not just meet it. *)

open! Core
open Protocol_emulator

module Sheet : sig
  type t =
    { part : string
    ; document : string (** With its revision. *)
    ; page : string
    }
end

module Margin : sig
  type t =
    | Cycle (** One cycle of the clock. *)
    | Ns of
        { ns : float
        ; why : string
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
  ; margin : Margin.t
  ; bound : Bound.t
  }

val all : t list

module I2c_mode : sig
  type t =
    | Standard
    | Fast
  [@@deriving sexp_of]
end

(** An I2C master's limits from UM10204's table for every device in [mode], each width a
    release starts less the mode's slowest rise, and SCL's period at least 1/fSCL. *)
val um10204 : I2c_mode.t -> string -> t list

(** A UART's bit within 2% of [baud]. *)
val uart : baud:int -> string -> t list

(** Firmware with no limit, and why. *)
val exempt : (string * string) list

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
    ; needed : int (** The least, or most, cycles the margin leaves. *)
    ; bound : int option (** The firmware's: least for [At_least], most for [At_most]. *)
    ; ok : bool
    }
end

(** Every limit on [bench], by [bench]'s name unless [limits] are given, a run's bounds on
    [bench]'s stimulus unless one is given. *)
val check : ?limits:t list -> ?stimulus:Stimulus.t -> Bench.t -> (t * Verdict.t) list

(** A line per limit: its parameter, the limit, the bound in cycles and ns, and FAIL where
    it does not clear the margin. *)
val to_string : Bench.t -> (t * Verdict.t) list -> string

(** Raises unless every limit clears its margin, and for firmware with no limit that is
    not [exempt]. *)
val check_exn : Bench.t -> unit
