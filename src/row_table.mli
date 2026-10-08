(** What the kernel and the osr kernel share in checking a row per pc: the words they
    read, the rejections they give and the fixed point that proposes their rows. *)

open! Core
open! Hardcaml

(** The word at [pc] as the program memory holds it; words past the program read zero. *)
val word : int array -> int -> Bits.t

(** A pc a check rejects and the names of the conjuncts that fail there. *)
module Rejection : sig
  type t =
    { pc : int
    ; fails : string list
    }
  [@@deriving sexp_of]

  (** The named conjuncts that do not hold at [pc], if any. *)
  val of_conjuncts : pc:int -> (string * Bits.t) list -> t option
end

(** A worklist from pc 0: [visit pc state] gives each successor and what it passes on,
    which [join] adds to that pc's state. After 64 changes at a pc, [widen] each new
    state, so a loop cannot keep it moving. *)
val fixpoint
  :  'state array
  -> visit:(int -> 'state -> (int * 'image) list)
  -> join:('state -> 'image -> 'state)
  -> widen:('state -> 'state)
  -> equal:('state -> 'state -> bool)
  -> 'state array
