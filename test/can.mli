(** CAN 2.0A transmitter on [tx_pin], recessive high, with the core's CRC-15.

    The host sends the bit period once, then per frame the number of bits after SOF less
    one and those bits, ID to the last data bit, MSB first sixteen to a word. The firmware
    sends SOF, the bits, the CRC, a recessive delimiter, ACK slot and ACK delimiter, EOF
    and the intermission, and a stuff bit after five equal bits from SOF to the CRC's
    last. A frame's words fit the fifo; one late is an underflow fault, not a moved edge.

    Stuffing is in the firmware: the stuff counter only counts runs of one level. It sends
    and reads nothing else: no arbitration, and the ACK slot is not read. The pin is
    dominant from reset until a bit after the period arrives. *)

open! Core
open Protocol_emulator

val tx_pin : int
val firmware : Timed_program.t
val config : Program_config.t

(** 500 kbit/s at 48 MHz. *)
val period : int

(** The least period the host may load: the kernel accepts the analyser's rows at every
    load of it or more. *)
val shortest_period : int

module Frame : sig
  type t =
    { id : int
    ; rtr : bool
    ; dlc : int
    ; data : int list
    }
  [@@deriving sexp_of, compare, equal]

  val data : id:int -> int list -> t
  val remote : id:int -> dlc:int -> t
end

(** CRC-15/CAN, MSB first from 0: 0x4599, check 0x059e. *)
val crc15 : bool list -> int

(** Every bit on the line from SOF to the end of the intermission, stuff bits included. *)
val line : Frame.t -> bool list

(** The host words of one frame. *)
val words : Frame.t -> int list

(** Levels one per bit from SOF, as a decoder samples them: removes the stuff bits, then
    checks each stuff bit, the CRC, the delimiters, the ACK slot and EOF. *)
val decode : bool list -> Frame.t Or_error.t
