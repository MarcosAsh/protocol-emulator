(** The one data memory every engine streams from. Engine [n] reads on cycles [n] modulo
    the engine count and keeps its last word; [reads] is each pointer's next address,
    [words] the word at it now. A moved pointer's word arrives within two cycles, hence
    the data-pull refusal after a pull or seek. Writes land only while all engines are
    halted. At most two engines. *)

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
