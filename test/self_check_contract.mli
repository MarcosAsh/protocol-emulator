(** [Self_check.checker]'s contract as a circuit, for the proof on the rtl. It is the
    reference monitor from [Self_check_monitor], stepped one cycle at a time. [line] in
    the [n]th cycle after clear is the level the checker samples in its cycle [n]; the
    outputs describe the cycles before. *)

open! Core
open! Hardcaml

(** Width of a position in a frame (a least is under [2^14], as in [Self_check.rows]). *)
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
      ; late : 'a (** the irq is due ten cycles after a start, not before a least *)
      ; phase : 'a
      (** 0 after clear, 1 waiting for the line to go high, 2 waiting for a frame, 3
          inside a frame, 4 irq due *)
      ; position : 'a (** in a frame, the cycles since its start *)
      ; boot : 'a (** cycles since clear, counting up to [watch_from] *)
      ; previous : 'a (** the line a cycle ago *)
      ; flags : 'a (** stale, blind, early, at last, fresh and least high, msb first *)
      }
    [@@deriving hardcaml]
  end

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
