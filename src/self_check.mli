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

(** Checks each frame on [pin], the first from the first fall after it sees the line high,
    against the rows at [base]. A move off the rows raises the irq and halts by the cycle
    before the least, or for one in the four cycles before it, within ten cycles of the
    next first edge. Blind only where a fall's 16-bit stamp repeats an older one: a
    one-cycle low pulse in the cycle before a least and the next first edge, or a fall in
    the first cycle it reads and one in the first frame, each [2^16 k] cycles apart. It
    misses no deadline of its own. *)
val checker : pin:int -> base:int -> string

val checker_config : pin:int -> Program_config.t
