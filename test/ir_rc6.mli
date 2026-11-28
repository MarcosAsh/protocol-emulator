(** Philips RC-6 mode 0 infrared remote control on one line, OUT0, as SB-Projects' page
    gives it (updated 17 July 2025): high for a mark, no 36 kHz carrier. Times are whole
    units of 444 us, which the host loads. A frame: leader of 6 units marked and 2 not,
    start bit 1, mode 000, 2-unit trailer bit, 8 address and 8 command bits msb first, 6
    units free. The unit is sent once, then per frame [words]. A late word underflows. *)

open! Core
open Protocol_emulator

val pin : int

(** 21333 cycles at 48 MHz. *)
val standard_unit : int

(** The shortest unit [firmware] takes: the kernel accepts the analyser's rows at this
    load and any longer one. *)
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

(** Decodes one level per cycle (high is a mark). Every mark and space must be within 5%
    of its nominal, a frame must be mode 0, and its signal free time at least 95% of 6
    units. *)
val decode : clock_hz:int -> bool list -> (Message.t list * Measured.t) Or_error.t

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
