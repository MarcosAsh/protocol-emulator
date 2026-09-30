(** The chip checks a certificate's edges itself: one engine runs [checker] over the pin
    another drives and raises its irq and halts if any edge leaves the cycle the
    certificate gives it. The rows come from the ones the kernel accepts. *)

open! Core

(** The cycles from a frame's first edge, the write at [first], to every later pin write
    up to [last], and last the least to the next frame's first edge. Each is exact: a
    write whose row has jitter, a wait on the world, a write to [t] or [p] inside the
    frame, or a write between the frame and the next is refused. Refused too if the write
    at [first] does not say it leaves the pin low, and unless the kernel accepts the rows. *)
val edges
  :  ?period:int
  -> config:Program_config.t
  -> Asm.Program.t
  -> first:int
  -> last:int
  -> int list Or_error.t

(** [edges] as data memory words for [checker] to read from [base]: the first check's [p],
    then a word per later edge and one for the least, each with the cycles from the edge
    before in bits 15 to 1 and whether another edge follows in bit 0, then [base] above
    the data memory, so no row loads [p] under [min_gap]. Refused if a load would be under
    [min_gap]: a first edge under [min_gap + 12], a gap under [min_gap], or a least under
    [min_gap + 3] after the last edge. Refused too if the least is [2^14] or more from the
    first edge, which keeps the stamps [checker] compares well inside their 16 bits, or if
    the rows run past the data memory. *)
val rows : base:int -> int list -> int list Or_error.t

(** The least [p] [checker] loads without missing a deadline of its own, whatever the line
    does. *)
val min_gap : int

(** Checks every frame on [pin] against the rows at [base]. The line idles high; once the
    checker has seen it high, the first fall is a frame's first edge [F], and each later
    frame's is the first low cycle from the last one's least. Inside a frame the line may
    move, its level differing from the cycle before, only at [F + edge] for an edge before
    the least, and it is high after the last. Frames that keep to this raise nothing.

    Any other move raises the irq and halts: by the cycle before the least, or for a move
    in the four cycles before it, within ten cycles of the next frame's first edge, never
    if none comes. The one it can miss is a one-cycle low pulse in the cycle before the
    least with the next first edge a multiple of [2^16] cycles later, as the capture's 16
    bits read it as that edge's stamp; nothing else is blind, first edges included. A fall
    stamped before the line is first seen high restarts it, unchecked. No deadline is
    missed whatever the line does. *)
val checker : pin:int -> base:int -> string

val checker_config : pin:int -> Program_config.t
