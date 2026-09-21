(** 1-Wire master at standard speed on one open drain pin, IO0.

    Everything is a whole number of units, and the host sends the unit in cycles as its
    first word: 6 us, 300 cycles at 50 MHz. Every slot is the same five deadlines whatever
    it carries: the line falls, after one unit it takes the value of the bit, so a one or
    a read lets go after 6 us, after two units the line is sampled, at 12 us, after ten
    units a zero lets go, at 60 us, and the next slot starts after eleven, at 66 us. That
    is 15.2 kbit/s, inside the 60 to 120 us the standard gives a slot. A read is a write
    of 0xff, and every byte comes back as it was seen on the line, so a write reads back
    as itself unless something held the line. A reset is 80 units low, 480 us, the
    presence sample 12 units after the release, at 72 us, and 68 units more to make up the
    480 us the line has to stay high.

    Host words after the unit: [reset], which answers 0 when a device pulled the line low
    and 1 when none did, and [byte b], which answers the byte sampled.

    Each edge is the instruction after a deadline wait, so the resolution is one cycle, 20
    ns, and the times above are exact, but for the end of the reset pulse and the presence
    sample, which sit behind the jump that ends a loop and come two cycles later: the
    reset is 480.04 us. The shortest unit the program keeps up with is 5 cycles, which the
    dispatch of a host word needs; the standard has no use for it, but overdrive slots, a
    unit of 1 us, fit with room to spare.

    The CRC of the ROM is checked by the host. The core's CRC unit would do the
    polynomial, but it sees every single bit shift, the ones written to open a read slot
    as well as the bits read in it, so it cannot be pointed at the read bits alone. *)

open! Core
open Protocol_emulator

val pin : int
val cycle_ns : int

(** Cycles in 6 us at 50 MHz. *)
val standard_unit : int

val firmware : string
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

  val create : cycle_ns:int -> rom:int list -> t
  val drive_low : t -> bool
  val step : t -> master_low:bool -> t
  val log : t -> string list

  (** [high] is the time between two slots, which is the recovery time after a zero. *)
  val measured : t -> Measured.t

  val violations : t -> string list
end
