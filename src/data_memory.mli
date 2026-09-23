(** The one data memory every engine streams from.

    The engines take turns at the read port, engine [n] on every cycle whose count modulo
    the number of engines is [n], and each keeps the last word it read. [reads] is the
    address each engine's pointer holds next cycle and [words] the word at its pointer
    now. After the pointer moves the word is there within two cycles whichever turn it
    moved on, which is why an engine refuses a data pull the cycle after a pull or a seek
    rather than read a word that may not have arrived. Writes land only while every engine
    is halted, so no running engine ever loses its turn. At most two engines. *)

open! Core
open! Hardcaml

module type Config = sig
  val engines : int
end

module Make (_ : Config) : sig
  module I : sig
    type 'a t =
      { clocking : 'a Clocking.t
      ; halted : 'a list
      ; writes : 'a Engine.Program_write.t list
      ; reads : 'a list
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t = { words : 'a list } [@@deriving hardcaml]
  end

  val hierarchical
    :  ?instance:string
    -> memory:Engine.Memory.t
    -> Scope.t
    -> Signal.t I.t
    -> Signal.t O.t
end
