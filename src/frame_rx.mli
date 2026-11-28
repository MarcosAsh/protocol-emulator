(** 10BASE-T receive into the data memory: [Manchester_rx] on both clock edges at gain 1/8
    ([fifty] picks 10 samples a bit for 50 MHz, else 8 for 40), with its own CRC-32. [arm]
    (re)starts it: the next frame lands from [base] up and its end disarms it with
    [finished]. A word lands only where [may_write] lets it and below the memory's end,
    else [dropped] says so. Assumes a line receiver with squelch, idle low. *)

open! Core
open! Hardcaml

(** [Manchester_rx]'s configuration here: 8 or 10 samples a bit, two per cycle, gain 1/8. *)
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
    ; ready : 'a (** A word is waiting and fits: [write.valid] is [ready &: may_write]. *)
    ; status : 'a Status.t
    }
  [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
