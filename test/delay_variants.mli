(** The swept firmware made late on purpose: [k] cycles of [nop] in front of its tightest
    deadline wait, from none to three past the wait's slack, each with the kernel's
    verdict and the model's run under the sweep's stimulus. Up to the slack the wait
    absorbs them and no edge moves; past it the wait is reached late. *)

open! Core
open Protocol_emulator

(** The model's run under the sweep's stimulus. *)
module Model : sig
  type t =
    { fault : Machine.Fault.t
    ; moved : bool (** An edge is somewhere the firmware does not put it. *)
    }
end

module Variant : sig
  type t =
    { k : int
    ; source : string
    ; config : Program_config.t (** With the program's side-set and wrap. *)
    ; words : int list
    ; analyser : unit Or_error.t (** [Analyser.check] under the sweep's assumptions. *)
    ; kernel : unit Or_error.t (** [Kernel.check] on the analyser's rows. *)
    ; rejections : Kernel.Rejection.t list
    ; model : Model.t Lazy.t (** Some take a while. *)
    }

  (** The kernel accepts it, which it does only if the analyser passes it too. *)
  val accepted : t -> bool

  (** The model set a fault or moved an edge. *)
  val late : t -> bool
end

type t =
  { swept : Swept.t
  ; certified : Certified.t
  ; wait_pc : int
  ; slack : int
  ; edges : int list list
  (** The firmware's own edges on the model, each run's in cycles from its first. *)
  }

(** [k] cycles as source lines of [nop]s with the side-set [side], as few as the delay
    field allows. *)
val nops : side_set_count:int -> side:int -> int -> string list

(** Finds the tightest wait. *)
val of_swept : Swept.t -> t

(** The variant with [k] extra cycles. *)
val variant : t -> int -> Variant.t

(** Every [k] from 0 to [slack + 3]. *)
val every : t -> Variant.t list
