(** The pins one engine can move. From the clear on, a pin outside its footprint keeps 0
    in [pin_out] and in [pin_dir], whatever the host and the input pins do:
    [formal/frame_step.sv] proves it of the engine for every config and every program
    whose words keep to its [Writes].

    Each writer reaches a window of pins from a base in the config, placed as [Pins.write]
    places it and only on the pins that take it: side-set from [side_set_base], [set] from
    [set_base], [out] and [mov] from [out_base]. Side-set reaches no more than the
    [Isa.max_side_set] pins a word carries bits for, whatever [side_set_count] a host
    writes: a wider window only ever writes 0 above them. An [out] is as wide as its
    count, not [out_count], so the window of the outs is as wide as the program's widest
    one, and two wide for a Manchester bit, which drives the pin above [out_base] too.
    [mov] writes [out_count] pins.

    The config holds from one clear to the next. A new one without a clear leaves the pins
    the last program drove where they were. *)

open! Core
open! Hardcaml

(** What a program writes to the pins: its widest [out] to pins and to pindirs, 0 for
    none, and whether it sets or moves to either. Side-set comes from the config alone,
    since every word but a jump carries it. *)
module Writes : sig
  type 'a t =
    { out_pins_width : 'a
    ; out_dirs_width : 'a
    ; sets_pins : 'a
    ; sets_dirs : 'a
    ; movs_pins : 'a
    ; movs_dirs : 'a
    }
  [@@deriving hardcaml]

  (** What these words write between them. *)
  val of_program : Isa.t list -> Bits.t t

  (** Every writer at its widest, which any program keeps to. *)
  val any : Bits.t t
end

(** The footprint as masks over the [Isa.pin_space] pins, pin 0 in the low bit. *)
module Make (Comb : Comb.S) : sig
  val pin_out : Comb.t Engine.Config.t -> Comb.t Writes.t -> Comb.t
  val pin_dir : Comb.t Engine.Config.t -> Comb.t Writes.t -> Comb.t
end

type t =
  { pin_out : int list
  ; pin_dir : int list
  }
[@@deriving sexp_of, equal]

(** A firmware's, from the config its program runs under and the program's words. It
    covers what the core does as long as it goes only with those words. *)
val of_program : Program_config.t -> Isa.t list -> t

(** The config's, under any program. *)
val of_config : Program_config.t -> t

(** The pins both can move, on [pin_out] or on [pin_dir]. By the frame lemma, each of two
    engines keeps 0 on the pins only the other can move, as long as neither is given a new
    config without a clear. [formal/chip_frame.sv] proves it again on the two-engine top,
    and that two engines sharing no pad each drive their pads as they would alone and each
    reads as it would alone on every pin the other cannot move. A shared wire is how two
    engines talk and takes nothing from either's pads. *)
val shared : t -> t -> int list
