(** A loaded Mealy table on the serial bit, after NXP FlexIO's state mode (AN5239): line
    codes as data rather than gates. With [Program_config.line_code] on, every 1-bit
    [out pins] and [in pins] steps the engine's table, the transmit side from one state
    register and the receive side from another, both 0 after a start.

    Word [s] (0 to 7) holds state [s]'s two 5-bit entries, for input 0 in the low byte and
    input 1 in the high; word 8 holds the [Modes]. An [out]'s input is the bit the osr
    gives, or with [tx_relative] whether it differs from the pin at [out_base]. It drives
    [out] on that pin, or with [tx_toggle] flips the pin where [out] is set, and with
    [out_count] 2 or more drives the next pin as the complement. An [in]'s input is the
    pin at [in_base], or with [rx_relative] whether it moved since the last [in]. It
    shifts in [out], flipped with [rx_toggle] where the pin was high at the last [in];
    with [flag] it shifts nothing: the bit is dropped, past the CRC and the stuff counter
    too. Either way the state moves to [next], and [flag] is what [jmp stuff] reads until
    [stuff_reset] or the next step. [stuff_reset] leaves the states, so a table that
    stuffs moves to the state after the stuffed bit, which the firmware drives, as it
    raises [flag]. *)

open! Core

val states : int

(** The bits of a written state, and of the state registers. *)
val state_bits : int

val entry_bits : int

(** The bits of a word's address. *)
val address_bits : int

(** The word that holds the modes. *)
val modes_word : int

module Entry : sig
  type t =
    { next : int
    ; out : int
    ; flag : bool
    }
  [@@deriving sexp_of, compare, equal]
end

module Modes : sig
  type t =
    { tx_relative : bool
    ; rx_relative : bool
    ; tx_toggle : bool
    ; rx_toggle : bool
    }
  [@@deriving sexp_of, compare, equal]

  val none : t
end

type t =
  { words : int array
  ; modes : Modes.t
  }
[@@deriving sexp_of, compare, equal]

(** Every entry stays in state 0 and drives 0. *)
val off : t

(** [f s] is state [s]'s entries for input 0 and input 1. *)
val of_states : ?modes:Modes.t -> (int -> Entry.t * Entry.t) -> t

(** The words the host writes from 0, the modes last. *)
val words : t -> int list

val of_words : int list -> t Or_error.t
val entry : t -> state:int -> input:int -> Entry.t

(** NRZI: a 0 flips the line, a 1 holds it. *)
val nrzi : t

(** USB transmit: NRZI on D+ (and D- with [out_count] 2), and [flag] at the sixth one,
    where the firmware flips the pair for the stuffed zero. *)
val usb_transmit : t

(** USB receive from D+: a 1 where the line held and a 0 where it moved, and the zero
    after six ones dropped. *)
val usb_receive : t

(** CAN transmit: the pin follows the bit, and [flag] at the fifth of a level, where the
    firmware flips the pin for the stuffed bit. *)
val can_transmit : t

(** CAN receive: the level, and the bit after five of a level dropped. *)
val can_receive : t
