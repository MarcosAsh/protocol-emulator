(** A pad sampled on both clock edges, each through two flops, so 10BASE-T gets twice the
    clock's sample rate. Bit 0 is the earlier sample. Cyclesim runs the falling flops on
    the rising edge, so only an event or gate-level simulation shows the half cycle. *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; pad : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { samples : 'a } [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
