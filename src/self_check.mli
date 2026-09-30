(** The chip checks a certificate's edges itself: one engine runs [checker] over the pin
    another drives and raises its irq and halts if any edge leaves the cycle the
    certificate gives it. The rows come from the ones the kernel accepts. *)

open! Core

(** The cycles from a frame's first edge, the write at [first], to every later pin write
    up to [last], and last the least to the next frame's first edge. Each is exact: a
    write whose row has jitter, a wait on the world, a write to [t] or [p] inside the
    frame, or a write between the frame and the next is refused. Refused too unless the
    kernel accepts the rows. *)
val edges
  :  ?period:int
  -> config:Program_config.t
  -> Asm.Program.t
  -> first:int
  -> last:int
  -> int list Or_error.t

(** [edges] as data memory words for [checker] to read from [base]: the cycles from the
    first edge to the first check, then a word per edge with the cycles to the next in
    bits 15 to 1 and whether one follows in bit 0, [base] above the data memory in the
    last, so no row loads [p] under [min_gap]. Refused if a gap, or the first edge less
    three cycles, is under [min_gap], if the last edge is [2^14] or more from the first,
    where a glitch would stamp the 14 bits of capture [checker] compares as an earlier
    edge did, or if the rows run past the data memory. *)
val rows : base:int -> int list -> int list Or_error.t

(** The least [p] [checker] loads without missing a deadline of its own. *)
val min_gap : int

(** Checks every frame on [pin] against the rows at [base]. The pin idles high and starts
    each frame with a falling edge, which the capture stamps; from it each later edge has
    to fall in its cycle: the level a cycle before it must be the level after the one
    before, and no falling edge may be captured in between. A one-cycle pulse from three
    cycles before an edge to seven after it can go unseen. *)
val checker : pin:int -> base:int -> string

val checker_config : pin:int -> Program_config.t
