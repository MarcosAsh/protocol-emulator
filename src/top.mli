(** The Tiny Tapeout top: reset synchroniser, input synchronisers, host port on ui[2:0]
    and uo[0], the core's pins on ui[7:3], uo[7:1] and uio[7:0].

    There are [engines] cores, instances [engine_0] onwards, each with its own program
    memory. A pin carries the OR of what the engines drive onto it, and where one engine
    drives a bidirectional pin the others read that level instead of the pad's, so two
    engines can talk over a pin with nothing connected outside. *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a (** Required by Tiny Tapeout and always high in silicon; unused here. *)
    ; ui_in : 'a
    ; uio_in : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { uo_out : 'a
    ; uio_out : 'a
    ; uio_oe : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical
  :  ?instance:string
  -> memory:Engine.Memory.t
  -> engines:int
  -> Scope.t
  -> Signal.t I.t
  -> Signal.t O.t
