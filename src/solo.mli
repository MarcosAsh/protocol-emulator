(** One engine with a private data memory, as the tests and proofs drive it. *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; config : 'a Engine.Config.t
    ; start : 'a
    ; program_write : 'a Engine.Program_write.t
    ; data_write : 'a Engine.Program_write.t (** Only while halted. *)
    ; tx : 'a With_valid.t
    ; rx_pop : 'a
    ; clear_irq : 'a
    ; stop : 'a
    ; flush : 'a
    ; inputs : 'a
    }
  [@@deriving hardcaml]
end

module O = Engine.O

val hierarchical
  :  ?instance:string
  -> memory:Engine.Memory.t
  -> Scope.t
  -> Signal.t I.t
  -> Signal.t O.t
