(** 10BASE-T receive: Manchester decoding with digital clock recovery, for the 8x4 die.
    Not wired into the engines. A bit's second half carries its value, so every bit has a
    transition in its middle. The first transition from idle is taken as one, as the
    preamble's alternating bits have no others. A transition at least 3/4 of a bit after
    the expected position of the last one is the next mid-bit transition: its bit is the
    level after it, and the expected position moves by its error over [2^gain_shift].
    Earlier ones are bit boundaries and are ignored. With none for 3/2 of a bit the
    carrier is gone: the TP_IDL after a frame, or a broken one.

    After 0xd5 the bits are a frame, packed sixteen to a word, first bit lowest, so the
    first byte lands in the low half as the data memory holds it. A frame that ends on a
    half word gives its last byte in a low half of its own.

    [rd] is samples of RD+ minus RD-, already through the synchroniser, earliest in bit 0.
    The 8x4 integration needs: an external line receiver with squelch (a comparator on the
    transformer's secondary, idle reading low), a path from [word] into the data memory or
    rx fifo (10 Mb/s is a word every 1.6 us, faster than the host port drains), and the
    32-bit CRC unit of branch crc32-parked to check the FCS. *)

open! Core
open! Hardcaml

module type Config = sig
  (** Samples in a 100 ns bit: 4 at 40 MHz, 5 at 50 MHz, 8 and 10 with a falling-edge
      sampler beside the rising one. *)
  val samples_per_bit : int

  (** 1, or 2 with both clock edges sampling. *)
  val samples_per_cycle : int

  (** 0 re-centres on every mid-bit transition; 3 moves an eighth of the way. *)
  val gain_shift : int
end

module Make (_ : Config) : sig
  module I : sig
    type 'a t =
      { clocking : 'a Clocking.t
      ; rd : 'a
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { bit : 'a With_valid.t
      ; frame_active : 'a
      ; sfd_seen : 'a
      ; frame_end : 'a
      ; word : 'a With_valid.t
      }
    [@@deriving hardcaml]
  end

  (** Fixed point: phases count [2^fraction_bits] to a sample. *)
  val fraction_bits : int

  val count_bits : int
  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
