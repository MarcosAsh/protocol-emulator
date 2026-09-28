(** The chip's cores ([engine_n], each with its own program memory and host fields) and
    the pins between them; they share one [Data_memory], written only while all are
    halted. A pin is the OR of what engines drive, which keeps a mis-configured double
    drive defined. An engine reads another's driven bidirectional pin instead of the pad,
    and any engine's drive on a wire. [formal/chip_frame.sv] proves two engines sharing no
    pad drive and read as alone, except reading the other's bidirectional pads and wires,
    provided neither gets a new config without a clear. *)

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
      ; pads : 'a
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
