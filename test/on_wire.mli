(** Firmware moved between pins. A wire is the OR of what the engines drive on it, so an
    open drain line rides on one as its pull, 1 while an engine holds the line low. *)

open! Core

(** Open drain firmware moved from pads to wires, with [pins] mapping each pad to its wire.
    Drives of [pindirs] become drives of [pins], waits and jumps on a line wait and jump on
    the other level, and each [in pins] reads the wires inverted through [y] first. The
    program and its host words stay the same. It must hold nothing in [y] across a read,
    which no library I2C firmware does. Raises on any other use of a pin. *)
val open_drain_on_wire : pins:(int * int) list -> string -> string

(** The pins a firmware's waits name, moved by [pins] like the rest of its configuration. *)
val move_pins : pins:(int * int) list -> string -> string
