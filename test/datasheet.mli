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
        } (** Widths in cycles, of the pin in the run of [Bench.stimulus]. *)
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

(** [spacing ~a ~b () n]: [n] cycles at least before an edge of [a] where [hold] holds of
    the two pins' bits before it, and since [b]'s last edge where [apart] does. With
    [dirs] the bits are the directions. *)
val spacing
  :  ?dirs:bool
  -> ?hold:(own:bool -> other:bool -> bool)
  -> ?apart:(own:bool -> other:bool -> bool)
  -> a:int
  -> b:int
  -> unit
  -> int
  -> Kernel.Spacing.Spec.t

(** The same spacing with the pins' roles swapped. *)
val swap : Kernel.Spacing.Spec.t -> Kernel.Spacing.Spec.t

(** The kernel's bound on one pin at one level: high, or for [dirs] held low. *)
val level : ?dirs:bool -> pin:(Program_config.t -> int) -> high:bool -> unit -> Bound.t

(** The pin [set] drives, and the one side-set does. *)
val set_pin : Program_config.t -> int

val side_pin : Program_config.t -> int

(** [Bound.Run], and the widths of every low in a run. *)
val run
  :  pin:(Program_config.t -> int)
  -> (clock_hz:int -> Levels.t -> int list)
  -> Bound.t

val lows : Levels.t -> int list

(** The limits of the bench firmware no protocol file holds yet ([Library]). *)
val others : t list

(** Of those firmware, the ones with no limit, and why. *)
val exempt : (string * string) list

module Verdict : sig
  type t =
    { limit : Limit.t
    ; needed : int (** The least, or most, cycles the margin leaves. *)
    ; bound : int option (** The firmware's: least for [At_least], most for [At_most]. *)
    ; ok : bool
    }
end

(** Every one of [limits] on [bench], found by its name. *)
val check : t list -> Bench.t -> (t * Verdict.t) list

(** A line per limit: its parameter, the limit, the bound in cycles and ns, and FAIL where
    it does not clear the margin. *)
val to_string : Bench.t -> (t * Verdict.t) list -> string

(** Raises unless every limit clears its margin, and for firmware with no limit that is
    not [exempt]. *)
val check_exn : t list -> exempt:(string * string) list -> Bench.t -> unit
