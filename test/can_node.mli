(** A CAN 2.0A node on one transceiver (CTX on OUT1, CRX on IN1), built from two firmwares
    kept out of the library: [Receiver] and [Sender]. Engines OR what they drive, so only
    one of them may use CTX at a time. Neither arbitrates, sends error or overload frames,
    or counts errors; both take standard data and remote frames only. *)

open! Core
open Protocol_emulator

val rx_pin : int

(** CAN 2.0A frames off CRX, resynced on every falling edge, ACKed on CTX when the CRC
    holds. The ACK delimiter and EOF are not checked. Each frame pushes [words]. An error
    pushes its [Error_code] and [irq], then waits for a host word, and first for a dominant
    bit, since the error may leave the capture armed. If the ACK is not back on CRX by the
    slot's sample, it assumes a transceiver in standby. *)
module Receiver : sig
  (** 500 kbit/s at 48 MHz, sampled at 75%. *)
  val period : int

  val sample : int

(** The shortest period the kernel accepts for the firmware sampling three quarters in. *)
  val shortest_period : int

(** The most cycles CRX may take to show CTX (transceiver loop plus synchroniser) at
      [sample]. The single edge assumption holds up to this delay, or if CRX never shows
      CTX. *)
  val longest_loop : int

  val config : Program_config.t

  (** The firmware for a bit period and sample point, [sample] from 1 to [period - 5]. *)
  val source : period:int -> sample:int -> string

  (** [Timed_program.check] of [source] at [period], with the single capture edge. *)
  val check
    :  period:int
    -> sample:int
    -> (Timed_program.t, Timed_program.Refusal.t) Result.t

  (** At [period] and [sample]. *)
  val firmware : Timed_program.t

  module Error_code : sig
    type t =
      | Stuffing
      | Refused
      | Form
      | Crc
    [@@deriving sexp_of, compare, equal, enumerate]

    val to_word : t -> int
    val of_word : int -> t option
  end

  (** What it pushes for a frame it ACKs. *)
  val words : Can.Frame.t -> int list

  module Event : sig
    type t =
      | Frame of Can.Frame.t
      | Error of Error_code.t
    [@@deriving sexp_of, compare, equal]
  end

  (** Whole frames, then what an error left: its frame's words and its code last. *)
  val read : int list -> Event.t list Or_error.t
end

(** [Can.firmware], which also reads CRX 11 cycles before its ACK slot ends and pushes the
    level: 0 when a receiver ACKed the frame, 1 when none did. *)
module Sender : sig
  val config : Program_config.t
  val firmware : Timed_program.t

  (** The least period the host may load, as [Can.shortest_period]. *)
  val shortest_period : int
end

val protocol : Protocol.t
