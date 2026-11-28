(** 1-Wire master at standard speed on one open drain pin, IO0. The host's first word is
    the unit in cycles (6 us, 288 at 48 MHz). A slot has five deadlines: fall, release at
    1 unit for a one or read, sample at 2, release at 11 for a zero, next slot at 12. Then
    [reset] answers 0 if a device pulled the line low, [byte b] the byte sampled. Shortest
    unit 5 cycles. The CRC unit sees every shifted bit, so the host checks the ROM CRC. *)

open! Core
open Protocol_emulator

val pin : int

(** 300 cycles: 6.25 us at 48 MHz, not the 6 us above; every time stays in the standard. *)
val standard_unit : int

val firmware : Timed_program.t
val config : Program_config.t
val reset : int
val byte : int -> int

(** Dallas CRC-8, x^8 + x^5 + x^4 + 1, over bytes taken LSB first. Zero over a whole ROM. *)
val crc8 : int list -> int

(** The eight bytes of a ROM in the order they are read: family, serial LSB first, CRC. *)
val rom : family:int -> serial:int -> int list

(** A slave with a ROM, answering a reset with a presence pulse and READ ROM (0x33) with
    its eight bytes, holding a zero 15 us. It times what the master drives: low 1 to 15 us
    a one or read, 60 to 120 a zero, 480 or more a reset, else a violation, as is a slot
    under 60 us or gap under 1 us, or high under 480 us after a reset. *)
module Slave : sig
  type t

  val create : clock_hz:int -> rom:int list -> t
  val drive_low : t -> bool
  val step : t -> master_low:bool -> t
  val log : t -> string list

  (** [high] is the time between two slots, which is the recovery time after a zero. *)
  val measured : t -> Measured.t

  val violations : t -> string list
end

val protocol : Protocol.t
