(** The Tiny Tapeout top: reset and input synchronisers, host port on ui[2:0] and uo[0],
    core pins on ui[7:3], uo[7:1] and uio[7:0], and [engines] cores sharing pins as in
    [Engines]. [journal], off by default, adds [Journal], armed through [Host_port]. *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a (** Always high in silicon; unused. *)
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
  -> ?journal:bool
  -> memory:Engine.Memory.t
  -> engines:int
  -> Scope.t
  -> Signal.t I.t
  -> Signal.t O.t
