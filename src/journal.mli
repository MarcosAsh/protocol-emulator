(** A flight recorder: every cycle an input pad changes or the host acts, an entry of the
    pads, what the host did and the cycles since the last entry, into a ring in the data
    memory's top half. Enough to replay a run from the arm; the host logs its own words.
    Freezes with an end entry on a disarm, a fault, or a burst it cannot keep. *)

open! Core
open! Hardcaml

(** The input and bidirectional pads, input pins in the low bits. *)
val pad_bits : int

(** The ring's words, from [base]. *)
val words : int

val base : int

(** A [System] pad word as the journal keeps it. *)
val pads_of_pins : int -> int

module Code : sig
  (** The first four are the [command] input's values; [Arm] starts a journal and the last
      three end one. *)
  type t =
    | Pads
    | Control
    | Tx
    | Rx_pop
    | Arm
    | Disarm
    | Fault
    | Lost
  [@@deriving sexp_of, compare ~localize, equal, enumerate]

  val to_int : t -> int
end

(** Two words in the ring: the pads above the code, then [delta], the cycles since the
    entry before, or 0 for [Arm]. [Lost]'s delta is the first cycle it missed. *)
module Entry : sig
  type t =
    { code : Code.t
    ; pads : int
    ; delta : int
    }
  [@@deriving sexp_of, compare, equal]
end

module Log : sig
  (** Without the arm the ring wrapped, and holds the last entries only. *)
  type t =
    { from_arm : bool
    ; entries : Entry.t list
    }
  [@@deriving sexp_of]
end

(** An ended journal from its ring, read from [base] up. *)
val decode : int list -> Log.t Or_error.t

(** Arms the journal, or without [on] disarms it. *)
module Arm : sig
  type 'a t =
    { valid : 'a
    ; on : 'a
    }
  [@@deriving hardcaml]
end

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; arm : 'a Arm.t
    ; pads : 'a
    ; command : 'a (** [Code]'s first four; the host acts at most once a cycle. *)
    ; fault : 'a (** Its rise ends the journal. *)
    ; slot : 'a (** The ring can take a word this cycle. *)
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { write : 'a Engine.Program_write.t } [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
