(** 10BASE-T transmit from a 40 MHz clock: a bit every four cycles, Manchester coded by
    the assist on TD+ (IO0) and TD- (IO1). The host puts the preamble, start of frame and
    frame into the data memory, then pushes the frame's length in bits minus two. Its
    first word is a tenth of the link pulse interval in cycles (100 ns pulse, 16 ms). A
    bit is a two cycle [out] and two cycle jump, so loops need no deadline. *)

open! Core
open Protocol_emulator

val td_plus : int
val cycle_ns : int
val link_tenth : int
val firmware : Timed_program.t
val config : Program_config.t

module Frame : sig
  (** CRC-32 of IEEE 802.3, over bytes taken least significant bit first. *)
  val crc32 : int list -> int

  (** A broadcast UDP datagram over IPv4, from 10.0.0.2 port 1234 to port 1234, padded to
      the shortest frame and to an even length, without its FCS. *)
  val udp : payload:string -> int list

  (** Seven of 0x55 and 0xd5, the start of frame. *)
  val preamble : int list

  (** The bytes on the wire: the preamble, the start of frame, [frame] and its FCS. *)
  val wire : int list -> int list

  (** Bytes two to a word, the first in the low half, as the data memory takes them. *)
  val words : int list -> int list
end

(** The far end of the cable. It samples TD+ and TD- every cycle and holds them to the
    standard. In a frame every half bit is two cycles, TD- is TD+'s complement and every
    bit has its edge in the middle. The frame is whole bytes behind seven 0x55 and 0xd5,
    ending high 250 to 350 ns. A link pulse is 100 ns (80 to 200), 8 to 24 ms apart. *)
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

val protocol : Protocol.t
