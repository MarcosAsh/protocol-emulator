(** The chip checks a certificate's edges itself: one engine runs [checker] over the pin
    another drives and raises its irq and halts if any edge leaves the cycle the
    certificate gives it. The rows come from the ones the kernel accepts. *)

open! Core

(** The cycles from a frame's first edge, the write at [first], to every later pin write
    up to [last], then the least to the next frame's first edge. Refused unless each is
    exact, the write at [first] leaves the first pin it writes low, and the kernel
    accepts. *)
val edges
  :  ?period:int
  -> config:Program_config.t
  -> Asm.Program.t
  -> first:int
  -> last:int
  -> int list Or_error.t

(** [edges] as data memory words for [checker] at [base]. Refused if a load of [p] would
    be under [min_gap], if the least is [2^14] or more cycles from the first edge, or if
    the rows run past the data memory. *)
val rows : base:int -> int list -> int list Or_error.t

(** The least [p] [checker] loads without missing a deadline of its own, whatever the line
    does. *)
val min_gap : int

(** Checks each frame on [pin], the first from the first fall after it sees the line high,
    against the rows at [base]. A move off the rows raises the irq and halts by the cycle
    before the least, or for one in the four cycles before it, within ten cycles of the
    next first edge. Blind only where a fall's 16-bit stamp repeats an older one: a
    one-cycle low pulse in the cycle before a least and the next first edge, or a fall in
    the first cycle it reads and one in the first frame, each [2^16 k] cycles apart. It
    misses no deadline of its own. *)
val checker : pin:int -> base:int -> string

val checker_config : pin:int -> Program_config.t
