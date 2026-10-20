(** Simulates a circuit one cycle at a time on bits that are 0, 1, a bit of one data word
    or unknown. A known result holds for every value of the unknown bits and every data
    word, so what it shows of a circuit, it shows for all of them.

    Logic and muxes keep data bits; arithmetic and compares need known operands, else
    their result is unknown, but for an [==] that some known bit already decides. A mux
    whose select is unknown keeps the bits on which its cases agree. Registers take reset,
    then clear, then enable, as Cyclesim does, and start at [initialize_to] or unknown.
    Memories, instances, falling edges and a second clock are refused. *)

open! Core
open! Hardcaml

module Bit : sig
  type t =
    | Zero
    | One
    | Data of
        { index : int
        ; inverted : bool
        }
    | Unknown
  [@@deriving compare, equal, sexp_of]

  val to_string : t -> string
end

(** Index 0 is the least significant bit. *)
module Value : sig
  type t = Bit.t array [@@deriving compare, equal, sexp_of]

  val of_bits : Bits.t -> t
  val unknown : width:int -> t

  (** Bits [0 .. width - 1] of the data word. *)
  val data : width:int -> t

  val to_bits : t -> Bits.t option
  val is_known : t -> bool

  (** Each bit of the first is the second's, or the second's is unknown. *)
  val within : t -> t -> bool

  val to_string : t -> string
end

type t

(** [describe] names a signal in refusals, by its Verilog name and line when there is one.
    [initial] is a register's value at the start where [initialize_to] does not give it,
    as a Verilog [reg r = 0] does. *)
val create
  :  ?describe:(Signal.t -> string)
  -> ?initial:(Signal.t -> Bits.t option)
  -> Circuit.t
  -> t Or_error.t

val circuit : t -> Circuit.t
val describe : t -> Signal.t -> string

(** Registers, by uid order. *)
val registers : t -> Signal.t list

module State : sig
  type t [@@deriving equal, sexp_of]

  val find : t -> Signal.t -> Value.t
  val set : t -> Signal.t -> Value.t -> t

  (** Each register's bits where both agree, the rest unknown: a state within it holds
      what holds of both. *)
  val merge : t -> t -> t

  (** Every register within the other's. *)
  val within : t -> t -> bool
end

val initial : t -> State.t

(** The outputs during a cycle with these inputs, and the state after it. An input the
    function does not know is unknown. *)
val step
  :  t
  -> State.t
  -> inputs:(string -> Value.t option)
  -> (string * Value.t) list * State.t

(** What an output or register reads, from the inputs and registers it depends on in one
    cycle: the registers and inputs in its combinational cone. *)
val cone : t -> Signal.t -> Signal.t list
