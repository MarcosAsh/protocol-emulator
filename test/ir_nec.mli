(** NEC infrared remote control on one line, OUT0, as SB-Projects' page on it gives it
    (updated 17 July 2025): the LED's drive, high for the on third of a 38 kHz carrier,
    duty 1/3. A frame is a 9 ms AGC burst, a 4.5 ms space, then the address, its inverse,
    the command and its inverse, LSB first, each bit a 560 us burst and a space to 1.125
    ms for a zero or 2.25 ms for a one, and a last burst. A repeat code is a 9 ms AGC
    burst, a 2.25 ms space and a burst. Each message starts 110 ms or more after the one
    before. Every time is a whole number of thirds of a carrier period, which the host
    loads, and each comes out at least the spec's nominal.

    The host sends the third once, then per message the words of [words]. A word late only
    delays its message. *)

open! Core
open Protocol_emulator

(** The line the firmware drives. *)
val pin : int

(** 422 cycles at 48 MHz: a 37.9 kHz carrier. *)
val standard_third : int

(** The least third [firmware] takes: the kernel accepts the analyser's rows at every load
    of it or more. *)
val shortest_third : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

module Message : sig
  type t =
    | Frame of
        { address : int
        ; command : int
        }
    | Repeat_code
  [@@deriving sexp_of, equal]
end

(** A message's words: 0 then the command and address as one word, command high, for a
    frame; 1 for a repeat code. *)
val words : Message.t -> int list

(** A frame and two repeat codes; the bench runs the first two. *)
val sent : Message.t list

(** Decodes one level per cycle, high the carrier on: every carrier period, burst, space,
    bit and message period within 5% of its nominal, sigrok's tolerance, and every byte
    followed by its inverse. *)
val decode : clock_hz:int -> bool list -> (Message.t list * Measured.t) Or_error.t

(** [shortest_third] cycles a third of 38 kHz. *)
val trace_clock_hz : int

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
