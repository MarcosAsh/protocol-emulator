(** 10BASE-T transmit from a 40 MHz clock: a bit every four cycles, Manchester coded by
    the assist on TD+ (IO0) and TD- (IO1). The host puts a whole frame into the data
    memory, from the preamble to the FCS, and then pushes its length in bits less one; the
    first word it ever sends is a tenth of the link pulse interval in cycles. Between
    frames the line is idle but for a 100 ns link pulse every ten of those, 16 ms
    at 64000.

    Each bit is an [out] of two cycles, its first half, and the jump of two that follows
    it, its second, so the loop needs no deadline and ends when the count runs out. After
    the last bit the line stays high 275 ns, the TP_IDL the standard asks for, and goes
    idle. The host computes the FCS: there is no cycle to spare between the last bit of
    the frame and the first of the FCS for the core to fetch it, and the CRC unit would
    take in the FCS bits as they went out. *)

open! Core
open Protocol_emulator

val td_plus : int
val cycle_ns : int
val link_tenth : int
val firmware : string
val config : Program_config.t

module Frame : sig
  (** CRC-32 of IEEE 802.3, over bytes taken least significant bit first. *)
  val crc32 : int list -> int

  (** A broadcast UDP datagram over IPv4, from 10.0.0.2 port 1234 to port 1234, padded to
      the shortest frame and to an even length, without its FCS. *)
  val udp : payload:string -> int list

  (** The bytes on the wire: the preamble, the start of frame, [frame] and its FCS. *)
  val wire : int list -> int list

  (** Bytes two to a word, the first in the low half, as the data memory takes them. *)
  val words : int list -> int list
end

(** The far end of the cable. It samples TD+ and TD- every cycle and holds them to the
    standard: inside a frame every half bit is two cycles, TD- the complement of TD+ and
    every bit has its edge in the middle; the frame is whole bytes behind seven of 0x55
    and 0xd5, and ends high for 250 to 350 ns before the line goes idle; a link pulse is
    100 ns, 80 to 200 allowed, and 8 to 24 ms after the last one. *)
module Receiver : sig
  type t

  val create : unit -> t
  val step : t -> td_plus:int -> td_minus:int -> t

  (** The bytes after the start of frame, FCS included, of every frame so far. *)
  val frames : t -> int list list

  (** Cycles between one link pulse and the next. *)
  val link_intervals : t -> int list

  val violations : t -> string list
end
