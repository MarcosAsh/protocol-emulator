(** A CAN 2.0A node on one transceiver, CTX on OUT1 and CRX on IN1, from two firmwares
    kept out of the library: [Receiver] and [Sender]. Engines OR what they drive, so only
    one of them runs on CTX at a time. Neither arbitrates, sends error or overload frames,
    or counts errors; both take standard data and remote frames only. *)

open! Core
open Protocol_emulator

val rx_pin : int

(** Samples CRX [sample] cycles into each bit, after a hard sync on SOF, and again from
    every recessive to dominant edge with no limit on the phase error it takes up, as
    can2040 does. It listens once the bus has been idle for eleven bits, and after a frame
    it ACKed takes a SOF from the intermission's third bit on. Stuff bits are checked and
    dropped and the CRC-15 checked, and a frame whose CRC holds is ACKed on CTX for its
    ACK slot, by the receiver's own bit timing. The ACK delimiter and EOF are not checked.

    The host reads, for each frame ACKed: the ID; RTR at bit 6 with the DLC; the data
    bytes two to a word, the first in the high byte, after a zero byte if their number is
    odd; then 0. A stuff error, a frame with IDE or r0 recessive, a dominant CRC delimiter
    or a CRC that fails ends the frame with its [Error_code] instead, raises [irq], and
    waits for a host word before it listens again. *)
module Receiver : sig
  (** 500 kbit/s at 48 MHz, sampled at 75%. *)
  val period : int

  val sample : int

  (** The least period whose firmware, sampled three quarters in, the kernel accepts. *)
  val shortest_period : int

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
