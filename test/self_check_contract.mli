(** [Self_check.checker]'s contract as a circuit, for the proof on the rtl: the reference
    monitor of [Self_check_monitor] read one cycle at a time. [line] in the [n]th cycle
    after clear is the level the checker samples in its cycle [n]; the outputs speak of
    the cycles before. *)

open! Core
open! Hardcaml

(** The width of a position in a frame: a least under [2^14], as [Self_check.rows] has it. *)
val position_bits : int

module type Config = sig
  val max_inner : int
end

module Make (_ : Config) : sig
  module I : sig
    type 'a t =
      { clocking : 'a Clocking.t
      ; line : 'a
      ; inner : 'a list (** each edge but the least, from the frame's first *)
      ; count : 'a (** how many of [inner] are edges, at least one *)
      ; least : 'a
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { violated : 'a (** a break of the contract in an earlier cycle *)
      ; overdue : 'a (** the checker's irq is due by now *)
      ; ended : 'a (** frames that reached their least, up to 3 *)
      ; late : 'a (** the irq is due ten after a start, not before a least *)
      }
    [@@deriving hardcaml]
  end

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
