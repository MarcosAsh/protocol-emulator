(** USB full speed receive: NRZI with bit stuffing, clock recovered from every edge. Each
    D+ edge is a bit boundary and restarts the phase, so the bit is the sample half a bit
    later, then one a bit after that until the next edge. The line state there is J, K or
    SE0 from D+ and D-; a K after a J starts a SYNC, and a 1 after at least three 0s ends
    it. A 0 after six 1s is dropped; a seventh 1 is a stuffing error, which ends the
    packet. SE0 ends it too.

    After SYNC the bits are packed sixteen to a word, first bit lowest, so the PID lands
    in the low half. A packet that ends on a half word gives its last byte in a low half
    of its own. [dp] and [dm] are pad samples through the synchroniser, earliest in bit 0. *)

open! Core
open! Hardcaml

module type Config = sig
  (** Samples in an 83.3 ns bit: 8 at 48 MHz on both edges, 4 on one. A power of two. *)
  val samples_per_bit : int

  (** 1, or 2 with both clock edges sampling. *)
  val samples_per_cycle : int
end

module Make (_ : Config) : sig
  module I : sig
    type 'a t =
      { clocking : 'a Clocking.t
      ; dp : 'a
      ; dm : 'a
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { bit : 'a With_valid.t
      ; packet_active : 'a
      ; sync_seen : 'a
      ; packet_end : 'a (** SE0, or a stuffing error. *)
      ; stuff_error : 'a
      ; aligned : 'a (** At [packet_end]: whole bytes since SYNC. *)
      ; word : 'a With_valid.t
      }
    [@@deriving hardcaml]
  end

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
