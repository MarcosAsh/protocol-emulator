(** Runs the model as a host and a peer would drive it, and records every pin on every
    cycle, for [generate.exe run]. Cycle [c] shows the pins after the model's [c]th step,
    counted from 0. *)

open! Core

(** IN0 to IN4, OUT0 to OUT6, IO0 to IO7, then W0 to W7 for the wires. *)
val pin_name : int -> string

(** An input held at [level] from [cycle] on, until a later one for the same pin. *)
module Input : sig
  type t =
    { pin : int
    ; level : bool
    ; cycle : int
    }
  [@@deriving sexp_of]

  (** [PIN=LEVEL] or [PIN=LEVEL@CYCLE], the pin by number or name; no output pin. *)
  val of_string : string -> t
end

(** A word the host writes into the tx fifo once it has room, no earlier than [cycle]. *)
module Tx : sig
  type t =
    { word : int
    ; cycle : int
    }
  [@@deriving sexp_of]

  (** [WORD] or [WORD@CYCLE]. *)
  val of_string : string -> t
end

type t

(** The host writes the tx words in the order given and reads the rx fifo every cycle.
    [cycles] must be positive. *)
val run : Machine.t -> cycles:int -> tx:Tx.t list -> inputs:Input.t list -> t

(** True once any fault was set. *)
val faulted : t -> bool

(** A strip per pin that is ever high or is driven, then its edges with their cycles and
    the cycles since the last, the rx words with the cycle each was pushed, and each fault
    with the cycle and pc that set it. *)
val to_string : t -> string

(** The same pins as a VCD, a cycle being 20 ns as at the chip's 50 MHz. *)
val to_vcd : t -> string
