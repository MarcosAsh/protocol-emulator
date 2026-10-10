(** 10BASE-T receive into the data memory: [Manchester_rx] on both clock edges at gain 1/8
    ([fifty] picks 10 samples a bit for a 50 MHz clock, else 8 for 40 MHz), and the FCS
    checked by a CRC-32 of its own.

    [arm] (re)starts it: the next frame's words land from [base] up, and its end disarms
    it with [finished], so one frame at a time stays put for the host. A word lands only
    where [may_write] lets it, and only below the data memory's end; otherwise it is
    counted and [dropped] says so. [fcs_ok] is the CRC-32 residue at the last whole byte.
    [half] marks a last word that holds one byte. Assumes an external line receiver with
    squelch, idle reading low. *)

open! Core
open! Hardcaml

(** [Manchester_rx]'s configuration here: 8 or 10 samples a bit, two a cycle, gain 1/8. *)
module Rx_config : Manchester_rx.Config

val word_count_bits : int

(** Wide enough to name a pad. *)
val pin_bits : int

(** The reflected CRC-32 polynomial, and what the register holds after a good FCS. *)
val poly : int

val residue : int

module Control : sig
  type 'a t =
    { arm : 'a
    ; base : 'a
    ; fifty : 'a
    }
  [@@deriving hardcaml]
end

module Status : sig
  type 'a t =
    { words : 'a (** Of the frame so far, saturating. *)
    ; finished : 'a
    ; fcs_ok : 'a
    ; half : 'a
    ; dropped : 'a
    ; receiving : 'a (** Past the start of frame. *)
    ; armed : 'a
    }
  [@@deriving hardcaml]
end

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; rd : 'a (** Two samples a cycle, earliest in bit 0, from [Both_edges]. *)
    ; control : 'a Control.t
    ; may_write : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { write : 'a Engine.Program_write.t
    ; status : 'a Status.t
    }
  [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
