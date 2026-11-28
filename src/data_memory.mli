(** The one data memory every engine streams from, at most two. Engine [n] reads on cycles
    [n] modulo the count and keeps its last word; a moved pointer's word arrives within
    two cycles. [writes] land only while all engines are halted, and write [n] only while
    the checker walks no engine but [n]. [dma] lands whenever no host write takes the
    cycle, and takes that cycle's read, so the caller holds it off unless [keeps]. *)

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
      ; walked : 'a list (** The checker walks engine [n]. *)
      ; writes : 'a Engine.Program_write.t list
      ; reads : 'a list
      ; dma : 'a Engine.Program_write.t
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { words : 'a list
      ; whose_turn : 'a (** Whose read this cycle is, unless a write takes it. *)
      ; keeps : 'a list
      (** Engine [n] runs and its next address is the one it last read, unwritten since,
          so it skips the read and a write may take its turn. *)
      ; host_write : 'a (** A host write lands this cycle, so [dma] must stay off. *)
      ; written : 'a With_valid.t (** The address any write lands at this cycle. *)
      }
    [@@deriving hardcaml]
  end

  val hierarchical
    :  ?instance:string
    -> memory:Engine.Memory.t
    -> Scope.t
    -> Signal.t I.t
    -> Signal.t O.t
end
