(** The pins one engine can move. From the clear on, a pin outside it keeps 0 in [pin_out]
    and [pin_dir] whatever the host and inputs do; [formal/frame_step.sv] proves this for
    every config and every program whose words keep to its [Writes]. Side-set reaches at
    most [Isa.max_side_set] pins whatever [side_set_count] says (a wider window writes 0
    above them); [out] is as wide as the program's widest, plus one pin for Manchester;
    [mov] writes [out_count]. Holds only while the config holds between clears: a new
    config without a clear leaves old pins driven. *)

open! Core
open! Hardcaml

(** What a program writes: its widest [out] to pins and pindirs (0 for none) and whether
    it sets or movs either. Side-set comes from the config alone. *)
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

  val of_program : Isa.t list -> Bits.t t

  (** Every writer at its widest; any program keeps to it. *)
  val any : Bits.t t
end

(** Masks over [Isa.pin_space], pin 0 in the low bit. *)
module Make (Comb : Comb.S) : sig
  val pin_out : Comb.t Engine.Config.t -> Comb.t Writes.t -> Comb.t
  val pin_dir : Comb.t Engine.Config.t -> Comb.t Writes.t -> Comb.t
end

type t =
  { pin_out : int list
  ; pin_dir : int list
  }
[@@deriving sexp_of, equal]

(** Covers the core only while it runs just these words. *)
val of_program : Program_config.t -> Isa.t list -> t

(** The config's, under any program. *)
val of_config : Program_config.t -> t

(** Pins both can move. By the frame lemma each engine keeps 0 on pins only the other can
    move, provided neither gets a new config without a clear. [formal/chip_frame.sv]
    re-proves it on the two-engine top, and that with no shared pad each drives as alone
    and reads as alone on pins the other cannot move. Shared wires take no pads. *)
val shared : t -> t -> int list
