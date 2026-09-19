(** Flop stand-in for the IHP single port SRAM: registered read, write-through when [ren]
    and [wen] are both set, [bm] masks writes. *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clock : 'a
    ; men : 'a
    ; wen : 'a
    ; ren : 'a
    ; addr : 'a
    ; din : 'a
    ; bm : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { dout : 'a } [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
