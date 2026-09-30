(** Data rows beside the kernel's timing rows, one per pc: bits of the osr's last word
    shifted out since ([shifted], run on to [shift_limit] past the core's 16), that plus x
    ([sum], which a counted loop keeps), and whether a pull or an autopull took the word
    ([pulled]). formal/data_step.sv proves the core follows [step]; test_osr_kernel.ml
    proves by SAT that [accepts] keeps it in the rows given the kernel's x. Composed on
    paper: an out at a [pulled] row sends bits [shifted, shifted + n) of that word (from 0
    if it autopulls), or underflow is set, unless a [crc_send] is in force. Meaningful only for a program the kernel
    accepts; an empty row is never reached. *)

open! Core
open! Hardcaml

(** [Isa.data_bits] twice over: an osr shifted this far holds nothing of its word. *)
val shift_limit : int

module Row : sig
  type 'a t =
    { shifted_lo : 'a
    ; shifted_hi : 'a
    ; sum_lo : 'a
    ; sum_hi : 'a
    ; pulled : 'a
    }
  [@@deriving hardcaml]
end

(** What a row asks of the row it steps to. *)
module Holds : sig
  type 'a t =
    { shifted : 'a
    ; sum : 'a
    ; pulled : 'a
    }
  [@@deriving hardcaml]
end

(** Whether the instruction may leave by each way out: none from an empty row or a halt. *)
module Ways : sig
  type 'a t =
    { next : 'a
    ; target : 'a
    }
  [@@deriving hardcaml]
end

module Conjuncts : sig
  type 'a t =
    { next : 'a Holds.t
    ; target : 'a Holds.t
    }
  [@@deriving hardcaml]
end

(** [next_shifted] and [next_pulled] after the instruction. [takes]: it is a [pull], or an
    [out] that autopulls, and the osr takes the fifo's head or the data memory's word if
    there is one. *)
module Step : sig
  type 'a t =
    { next_shifted : 'a
    ; next_pulled : 'a
    ; takes : 'a
    }
  [@@deriving hardcaml]
end

module Make (Comb : Comb.S) : sig
  val step
    :  side_set_count:Comb.t
    -> autopull:Comb.t
    -> pull_threshold:Comb.t
    -> word:Comb.t
    -> shifted:Comb.t
    -> pulled:Comb.t
    -> Comb.t Step.t

  (** A row that holds every step from [row] on the way out named by [taken], with x in
      [x_lo, x_hi] as the kernel's row has it; a sum it cannot follow is full. *)
  val image
    :  side_set_count:Comb.t
    -> autopull:Comb.t
    -> pull_threshold:Comb.t
    -> word:Comb.t
    -> x_lo:Comb.t
    -> x_hi:Comb.t
    -> row:Comb.t Row.t
    -> taken:bool
    -> Comb.t Row.t

  val ways
    :  side_set_count:Comb.t
    -> word:Comb.t
    -> x_lo:Comb.t
    -> x_hi:Comb.t
    -> row:Comb.t Row.t
    -> Comb.t Ways.t

  val conjuncts
    :  side_set_count:Comb.t
    -> autopull:Comb.t
    -> pull_threshold:Comb.t
    -> word:Comb.t
    -> x_lo:Comb.t
    -> x_hi:Comb.t
    -> row:Comb.t Row.t
    -> next:Comb.t Row.t
    -> target:Comb.t Row.t
    -> Comb.t Conjuncts.t

  val accepts
    :  side_set_count:Comb.t
    -> autopull:Comb.t
    -> pull_threshold:Comb.t
    -> word:Comb.t
    -> x_lo:Comb.t
    -> x_hi:Comb.t
    -> row:Comb.t Row.t
    -> next:Comb.t Row.t
    -> target:Comb.t Row.t
    -> Comb.t

  val is_full : Comb.t Row.t -> Comb.t
  val sum_is_full : Comb.t Row.t -> Comb.t
end

module Table : sig
  type t = Bits.t Row.t array

  (** Rows from a fixed point over the program, on the kernel's x. Not trusted: [check]
      has the last word. *)
  val propose : config:Program_config.t -> words:int list -> Kernel.Table.t -> t
end

(** Checks every pc on the kernel's rows; words past the program read zero. *)
val check
  :  config:Program_config.t
  -> words:int list
  -> kernel:Kernel.Table.t
  -> Table.t
  -> unit Or_error.t

(** [step] as a circuit, for the RTL proof to use the same definition. *)
module I : sig
  type 'a t =
    { side_set_count : 'a
    ; autopull : 'a
    ; pull_threshold : 'a
    ; word : 'a
    ; shifted : 'a
    ; pulled : 'a
    }
  [@@deriving hardcaml]
end

module O = Step

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
