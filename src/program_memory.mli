(** Program memory with the port semantics of the IHP single port SRAM macro, built from
    flops for simulation and the FPGA. A read returns the word one cycle later and holds
    it until the next read. A write with [ren] also set is a write-through: the new word
    appears on [dout] the next cycle. [bm] is the bit mask for writes. *)

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
