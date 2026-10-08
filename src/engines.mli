(** The chip's cores ([engine_n], each with its own program memory and host fields) and
    the pins between them; they share one [Data_memory], written only while all are
    halted. A pin is the OR of what engines drive, which keeps a mis-configured double
    drive defined. An engine reads another's driven bidirectional pin instead of the pad,
    and any engine's drive on a wire. [formal/chip_frame.sv] proves two engines sharing no
    pad drive and read as alone, except reading the other's bidirectional pads and wires,
    provided neither gets a new config without a clear. An engine starts only on a program
    the [Load_checker] accepted, under the configuration it was checked with.

    An engine with a fault latched halts and lets go of its pins, as at reset, until the
    clear; a start does nothing meanwhile. [formal/fail_safe.sv] proves it. *)

open! Core
open! Hardcaml

module type Config = sig
  val engines : int
end

module Make (_ : Config) : sig
  module I : sig
    type 'a t =
      { clocking : 'a Clocking.t
      ; hosts : 'a Engine.Host.t list
      ; pads : 'a
      ; check_setup : 'a Load_checker.Setup.t
      }
    [@@deriving hardcaml]
  end

  (** The [Load_checker]'s last verdict, and each engine's: [certified], from an accepted
      check until a program or configuration write or the next check; and [refused], a
      start without it, which leaves the engine halted, until the next check. *)
  module Check : sig
    type 'a t =
      { verdict : 'a Load_checker.Verdict.t
      ; certified : 'a list
      ; refused : 'a list
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { engines : 'a Engine.O.t list
      ; pin_out : 'a
      ; pin_dir : 'a
      ; check : 'a Check.t
      }
    [@@deriving hardcaml]
  end

  (** [gated], the default and the chip, starts an engine only once it is certified.
      Without it a start always counts and the checker only reports: what the proofs of
      the cores take, a gated chip doing no more than they cover. *)
  val hierarchical
    :  ?instance:string
    -> ?gated:bool
    -> memory:Engine.Memory.t
    -> Scope.t
    -> Signal.t I.t
    -> Signal.t O.t
end
