(** The chip's cores ([engine_n], each with its own program memory and host fields) and
    the pins between them. They share one [Data_memory], which the host writes only while
    all engines are halted, and engine [n]'s host writes only while the checker walks no
    other engine. [Frame_rx] or [Usb_frame_rx] write it only in their owner's turns, where
    it keeps its word or pulls no data.

    A walk ends on its own host's data word, on a received word waiting in its engine's
    turn (whether it lands or not), and on any word landing where it has read. The owner
    reads the receiver's finished, good (FCS, or the CRC its PID names), receiving and
    error (a dropped word or a stuffing error) on the status pins, from
    [Isa.first_status_pin] up. The other engines read 0 there, so when the pins move
    depends on no other engine.

    A pin is the OR of what the engines drive, which keeps a misconfigured double drive
    defined. An engine reads another's driven bidirectional pin instead of the pad, and
    any engine's drive on a wire. [formal/chip_frame.sv] proves that two engines sharing
    no pad drive and read as if alone, except for reading the other's bidirectional pads
    and wires, provided neither gets a new config without a clear. An engine starts only
    on a program the [Load_checker] accepted, under the configuration it was checked with,
    and watches the premises that check took ([Engine.Premises]). A routed engine's pushes
    go to the next engine's tx fifo, which its host then can't write.

    An engine with a fault latched halts and lets go of its pins, as at reset, until the
    clear. A start does nothing meanwhile ([formal/fail_safe.sv] proves it). *)

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
