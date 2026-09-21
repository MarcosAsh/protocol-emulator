(** The cores of the chip and the pins between them. Each engine is an instance [engine_n]
    with its own program memory and its own host port fields.

    A pin carries the OR of what the engines drive onto it: an output pin what they hold,
    a bidirectional pin what those with its direction bit set hold. Where another engine
    drives a bidirectional pin an engine reads that level instead of the pad's, and on a
    wire it reads what any engine drives, so engines can talk over a pin or a wire with
    nothing connected outside. Two engines driving one pin is a mistake in the
    configuration; the OR keeps it defined. *)

open! Core
open! Hardcaml

module type Config = sig
  val engines : int
end

module Make (_ : Config) : sig
  module I : sig
    type 'a t =
      { clocking : 'a Clocking.t
      ; hosts : 'a Engine.Host.t list
      ; pads : 'a (** The level at the pad of every pin. *)
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { engines : 'a Engine.O.t list
      ; pin_out : 'a
      ; pin_dir : 'a
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
