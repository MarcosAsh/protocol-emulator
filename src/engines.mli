(** The chip's cores ([engine_n], each with its own program memory and host fields) and
    the pins between them; they share one [Data_memory], written by the host only while
    all are halted, and by [Frame_rx] where no engine pulling data runs and no check
    reads. A pin is the OR of what engines drive, which keeps a mis-configured double
    drive defined. An engine reads another's driven bidirectional pin instead of the pad,
    and any engine's drive on a wire. [formal/chip_frame.sv] proves two engines sharing no
    pad drive and read as alone, except reading the other's bidirectional pads and wires,
    provided neither gets a new config without a clear. An engine starts only on a program
    the [Load_checker] accepted, under the configuration it was checked with, and watches
    the premises that check took ([Engine.Premises]). A routed engine's pushes go to the
    next engine's tx fifo, which its host then cannot write. *)

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
      ; start_all : 'a
      (** Starts every engine on one cycle, only when all are halted and, gated, all
          certified. *)
      ; rd : 'a (** [Both_edges]' two samples of the 10BASE-T pin. *)
      ; frame : 'a Frame_rx.Control.t
      ; stamps : 'a Edge_stamps.Control.t
      (** On the pads, timed by engine [engine]'s [now]. *)
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
      ; frame : 'a Frame_rx.Status.t
      ; stamps : 'a Edge_stamps.O.t
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
