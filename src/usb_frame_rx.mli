(** USB full speed receive into the data memory, as [Frame_rx] does 10BASE-T: [Usb_rx] at
    8 samples a bit on both clock edges, and the CRC-5 and CRC-16 after the PID, each
    checked against its residue at the packet's end. A token is good if [crc5_ok], a data
    packet if [crc16_ok].

    [arm] (re)starts it: the next packet's words land from [base] up, PID in the first low
    half, and its end disarms it with [finished]. A word lands only where [may_write] lets
    it, and only below the data memory's end; otherwise it is counted and [dropped] says
    so. A word waits for [may_write] until the next arrives, and [finished] until the last
    lands. [half] marks a last word that holds one byte. *)

open! Core
open! Hardcaml
module Rx_config : Usb_rx.Config

val word_count_bits : int

(** The CRC registers' values after a good packet, reflected as USB sends them. *)
val crc5_residue : int

val crc16_residue : int

module Control : sig
  type 'a t =
    { arm : 'a
    ; base : 'a
    }
  [@@deriving hardcaml]
end

module Status : sig
  type 'a t =
    { words : 'a (** Of the packet so far, saturating. *)
    ; finished : 'a
    ; crc5_ok : 'a
    ; crc16_ok : 'a
    ; half : 'a
    ; aligned : 'a
    ; stuff_error : 'a
    ; dropped : 'a
    ; receiving : 'a (** Past SYNC. *)
    ; armed : 'a
    }
  [@@deriving hardcaml]
end

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; dp : 'a (** Two samples a cycle, earliest in bit 0, from [Both_edges]. *)
    ; dm : 'a
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
