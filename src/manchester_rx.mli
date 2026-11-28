(** 10BASE-T receive: Manchester decoding with digital clock recovery, for the 8x4 die. A
    bit's second half carries its value. A transition at least 3/4 of a bit after the
    expected position of the last is the next mid-bit one and moves the expected position
    by its error over [2^gain_shift]; earlier ones are ignored. With none for 3/2 of a bit
    the carrier is gone. After 0xd5 bits pack sixteen to a word, first bit lowest. *)

open! Core
open! Hardcaml

module type Config = sig
  (** Samples in a 100 ns bit: 4 at 40 MHz, 5 at 50 MHz, 8 and 10 with a falling-edge
      sampler beside the rising one. One rate, or two that [rate] picks between. *)
  val samples_per_bit : int list

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
      ; rate : 'a
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
