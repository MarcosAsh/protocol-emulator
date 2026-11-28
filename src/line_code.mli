(** A loaded Mealy table on the serial bit, after NXP FlexIO's state mode (AN5239), making
    line codes data instead of gates. With [Program_config.line_code] on, every 1-bit
    [out pins] and [in pins] steps the table, from separate transmit and receive state
    registers, both 0 after a start. Word [s] (0 to 15) holds state [s]'s two 6-bit
    entries [{flag, out, next}], word 16 the [Modes]. [flag] is what [jmp stuff] reads. *)

open! Core

val states : int

(** The bits of a written state, and of the state registers. *)
val state_bits : int

val entry_bits : int

(** Where [out] and [flag] sit in an entry, above [next]. *)
val out_bit : int

val flag_bit : int

(** The bits of a word's address. *)
val address_bits : int

(** The word that holds the modes. *)
val modes_word : int

(** Where [tx_stuff] sits in the modes word, and the bits the modes take. *)
val tx_stuff_bit : int

val modes_bits : int

(** The most bits [tx_stuff] keeps owed; past that the oldest is lost. *)
val owed_max : int

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
    ; rx_start : int
    ; tx_stuff : bool
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

(** The words the host writes from 0, the modes last. *)
val words : t -> int list

val of_words : int list -> t Or_error.t
val entry : t -> state:int -> input:int -> Entry.t

(** [transmit]'s first [used] states, then [receive]'s moved up by [used], with the
    receive side starting there. Raises if [receive] steps past the room left. *)
val combine : transmit:t -> used:int -> receive:t -> t

(** NRZI: a 0 flips the line, a 1 holds it. *)
val nrzi : t

(** USB transmit: NRZI on D+ (and D- with [out_count] 2), with [flag] at the sixth one,
    where the firmware flips the pair for the stuffed zero. *)
val usb_transmit : t

(** [usb_transmit] with [tx_stuff]: the core stuffs at full speed, where the firmware has
    no time to spare between bits. *)
val usb_stuffing : t

(** USB receive from D+: a 1 where the line held, a 0 where it moved, and the zero after
    six ones dropped. *)
val usb_receive : t

(** CAN transmit: the pin follows the bit, with [flag] at the fifth of a level, where the
    firmware flips the pin for the stuffed bit. *)
val can_transmit : t

(** CAN receive: the level, with the bit after five of a level dropped. *)
val can_receive : t

(** [usb_transmit] and [usb_receive] in one table, 13 states. *)
val usb : t

(** [can_transmit] and [can_receive] in one table, 11 states. *)
val can : t
