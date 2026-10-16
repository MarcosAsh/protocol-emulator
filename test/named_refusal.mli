(** A datasheet limit a bench firmware fails, found on the bench's own run: which edge
    breaks it, how long that edge really was, and a picture of the window round it. *)

open! Core

type t =
  { bench : Bench.t
  ; entry : Datasheet.t
  ; verdict : Datasheet.Verdict.t
  ; edge : int option
  (** Counted from 1 over the edges of the pins drawn, [None] if the run never breaks the
      limit and only the kernel's bound does. *)
  ; cycle : int (** The run's cycle of that edge. *)
  ; measured : int option (** In cycles. *)
  ; pins : int list (** The pins drawn. *)
  ; trace : int array (** The pins' word each cycle. *)
  }

(** Every limit of [limits] on [bench] that fails, each located on the run. *)
val refusals : Datasheet.t list -> Bench.t -> t list

(** One line: the edge, the parameter, the run's width against the limit at the bench's
    clock, and the sheet. *)
val to_line : t -> string

(** The window round the edge as an SVG, [names] labelling pins. *)
val to_svg : ?names:(int * string) list -> t -> string
