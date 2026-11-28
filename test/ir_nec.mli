(** NEC infrared remote control on one line, OUT0, as SB-Projects' page gives it (updated
    17 July 2025): the LED's drive, high for the on third of a 38 kHz carrier. Frame: 9 ms
    burst, 4.5 ms space, address, inverse, command, inverse, LSB first, each bit a 560 us
    burst and a space to 1.125 ms or 2.25 ms, then a last burst. Times are whole thirds of
    a carrier period, loaded once, then per message [words]. Late words only delay. *)

open! Core
open Protocol_emulator

(** The line the firmware drives. *)
val pin : int

(** The shortest third [firmware] takes: the kernel accepts the analyser's rows at this
    load and any longer one. *)
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

(** Decodes one level per cycle (high is carrier on). Every carrier period, burst, space,
    bit and message period must be within 5% of its nominal (sigrok's tolerance), and
    every byte must be followed by its inverse. *)
val decode : clock_hz:int -> bool list -> (Message.t list * Measured.t) Or_error.t

(** [shortest_third] cycles a third of 38 kHz. *)
val trace_clock_hz : int

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
