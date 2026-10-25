(** Philips RC-6 mode 0 infrared remote control on one line, OUT0, as SB-Projects' page on
    it gives it (updated 17 July 2025): high for a mark, with no 36 kHz carrier on it.
    Every time is a whole number of units of 444 us, which the host loads. A frame is a
    leader of 6 units marked and 2 not, a start bit 1, mode bits 000, a trailer bit of 2
    units a half, 8 address bits and 8 command bits msb first, and 6 units of signal free
    time. A bit is a unit's mark then a unit's space for a one, the reverse for a zero.

    The host sends the unit once, then per frame the two words of [words]. A word late is
    an underflow fault. *)

open! Core
open Protocol_emulator

val pin : int

(** 21333 cycles at 48 MHz. *)
val standard_unit : int

(** The least unit [firmware] takes: the kernel accepts the analyser's rows at every load
    of it or more. *)
val shortest_unit : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

module Message : sig
  type t =
    { toggle : bool
    ; address : int
    ; command : int
    }
  [@@deriving sexp_of, equal]
end

(** A frame's trailer bit, then its address and command in one word. *)
val words : toggle:bool -> address:int -> command:int -> int list

(** Decodes one level per cycle, high a mark: every mark and space must be within 5% of
    its nominal, a frame must be mode 0, and its signal free time at least 95% of 6 units. *)
val decode : clock_hz:int -> bool list -> (Message.t list * Measured.t) Or_error.t

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
