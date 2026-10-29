(** 1-Wire master at standard speed on one open drain pin, IO0.

    The host sends the unit in cycles as its first word: 6 us, 288 cycles at 48 MHz. Every
    slot is five deadlines: the line falls, a one or a read lets go after 1 unit (6 us),
    the line is sampled at 2 (12 us), a zero lets go at 11 (66 us) and the next slot
    starts at 12 (72 us). That is 13.9 kbit/s, a unit clear of the standard's 60 us. A
    read is a write of 0xff and every byte comes back as seen on the line. A reset is 80
    units low (480 us), the presence sample 12 units after the release, and 68 units more
    to make up the 480 us high.

    Host words after the unit: [reset], which answers 0 when a device pulled the line low
    and 1 when none did, and [byte b], which answers the byte sampled.

    Each edge follows a deadline wait, so the times are exact to one cycle (20.8 ns),
    except the reset's end and the presence sample, two cycles later (reset 480.04 us).
    The shortest unit kept up with is 5 cycles, which dispatching a host word needs.

    The host checks the ROM's CRC: the core's CRC unit sees every bit shift, including
    the ones that open a read slot, so it cannot be pointed at the read bits alone. *)

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

(** A slave with a ROM that answers a reset with a presence pulse and READ ROM (0x33) with
    its eight bytes. It is the datasheet's worst case where that is the master's problem:
    a zero it sends is held for 15 us from the falling edge and no longer. It times what
    the master drives: a low of 1 to 15 us is a one or a read, 60 to 120 us a zero, 480 us
    or more a reset and anything else a violation, as is a slot shorter than 60 us, less
    than 1 us between slots or less than 480 us high after a reset. *)
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
