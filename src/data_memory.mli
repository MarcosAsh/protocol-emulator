(** The one data memory every engine streams from. Engine [n] reads on cycles [n] modulo
    the engine count and keeps its last word; [reads] is each pointer's next address,
    [words] the word at it now. A moved pointer's word arrives within two cycles, hence
    the data-pull refusal after a pull or seek. [writes] land only while all engines are
    halted, and write [n] only while the checker walks no engine but [n]. [dma] lands
    whenever valid, unless a host write takes the cycle, and takes that cycle's read: the
    caller holds it off any read an engine or the checker needs, as [keeps] tells. At most
    two engines. *)

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
      (** Engine [n] runs and its next address is the one it last read, unwritten since:
          it skips the read, so a write may take its turn. *)
      ; host_write : 'a (** A host write lands this cycle, which [dma] must stay off. *)
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
