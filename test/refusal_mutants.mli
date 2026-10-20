(** Bench firmware made to break a datasheet limit, for [Named_refusal]. *)

open! Core

(** i2c_standard with a START held one quarter, not three: tHD;STA, tSU;STA and tSU;STO
    come up short. *)
val i2c_short_start : Bench.t

(** sk6812 with a bit of 56 cycles, not 59: the bit's period and two lows come up short. *)
val ws2812_short_bit : Bench.t
