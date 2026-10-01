(** Per-program settings the host writes before a start, as in the RP2040 PIO. *)

open! Core

module Shift_direction : sig
  type t =
    | Left
    | Right
  [@@deriving sexp, compare, equal]
end

type t =
  { side_set_count : int
  ; side_set_base : int
  ; side_set_pindirs : bool
  ; in_base : int
  ; in_count : int (** Number of pins read by [mov x, pins]. *)
  ; out_base : int (** Base of [out pins] and [mov pins]. *)
  ; out_count : int (** Number of pins written by [mov pins] and [mov pindirs]. *)
  ; set_base : int
  ; set_count : int
  ; jmp_pin : int
  ; capture_pin : int
  ; capture_rising : bool
  ; in_shift : Shift_direction.t
  ; out_shift : Shift_direction.t
  ; autopush : bool
  ; push_threshold : int
  ; autopull : bool
  ; pull_threshold : int
  ; crc_width : int (** 1 to 16. *)
  ; crc_poly : int (** Right-aligned; the top bit is implicit. *)
  ; crc_init : int
  ; crc_reflect : bool
  (** LSB first, as USB, with the polynomial given reflected; else MSB first. *)
  ; stuff_threshold : int (** Run length that raises [stuff_pending]; 0 turns it off. *)
  ; stuff_level : bool (** The level whose runs count. *)
  ; wrap_bottom : int
  ; wrap_top : int
  (** After [wrap_top], unless a jump is taken, go to [wrap_bottom] in zero cycles. The
      defaults, last address and 0, change nothing. *)
  ; period_fraction : int
  (** 65536ths of a cycle added to [t] at each [wait t+]: edges average [p + f / 65536]
      apart, each within a cycle. Any other write to [t] clears the fraction. *)
  ; autopull_data : bool
  (** Autopull reads data memory instead of the tx fifo; [pull] still reads the fifo. *)
  ; manchester : bool
  (** [out pins, 1] drives a Manchester pair: [out_base] the complement, [out_base + 1]
      the bit, both flipping at the next issue. The [out]'s length is the first half. *)
  }
[@@deriving sexp, compare, equal]

(** One output at OUT0, shift right, no side-set or autopush/pull, stuffing off, whole
    cycle period. CRC is CRC-16/USB (0x8005 reflected as 0xa001, init 0xffff). *)
val default : t

val validate : t -> unit Or_error.t
