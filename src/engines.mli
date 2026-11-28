(** The chip's cores and the pins between them, a pin the OR of what they drive. They
    share one [Data_memory]; a walk ends on any word that lands, or waits to land, where
    it reads. Two engines sharing no pad run as if alone ([formal/chip_frame.sv]), given
    no new config without a clear. An engine starts only on a program the [Load_checker]
    accepted, and a latched fault halts it until the clear ([formal/fail_safe.sv]). *)

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
      (** Starts every engine on one cycle, only when all are halted and, if gated, all
          certified. *)
      ; rd : 'a (** [Both_edges]' two samples of the 10BASE-T pin, or USB's D+. *)
      ; dm : 'a (** And of USB's D-. *)
      ; frame : 'a Frame_rx.Control.t
      ; frame_usb : 'a (** [Usb_frame_rx] in [Frame_rx]'s place. *)
      ; frame_owner : 'a
      (** The engine the receivers belong to. Their words land only in its data turns, and
          it alone reads their status pins. *)
      ; stamps : 'a Edge_stamps.Control.t
      (** On the pads, timed by engine [engine]'s [now]. *)
      }
    [@@deriving hardcaml]
  end

  (** Cycles in each engine's turn at the [Load_checker], twice the longest firmware's
      walk. A walk longer than its turn is aborted. *)
  val turn_cycles : int

  (** Each engine's last [Load_checker] verdict. [busy] runs from the check's ask (which
      waits for the engine's turn) until its verdict. [certified] runs from an accepted
      check until a program or configuration write or the next check. [refused] means a
      start without certification, which leaves the engine halted until the next check. *)
  module Check : sig
    type 'a t =
      { verdicts : 'a Load_checker.Verdict.t list
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
      ; usb : 'a Usb_frame_rx.Status.t
      ; stamps : 'a Edge_stamps.O.t
      }
    [@@deriving hardcaml]
  end

  (** [gated] (the default, and what the chip does) starts an engine only once it is
      certified. Without it a start always counts and the checker only reports. That is
      what the core proofs assume, and a gated chip does no more than they cover. *)
  val hierarchical
    :  ?instance:string
    -> ?gated:bool
    -> memory:Engine.Memory.t
    -> Scope.t
    -> Signal.t I.t
    -> Signal.t O.t
end
