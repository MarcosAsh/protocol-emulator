(** USB Power Delivery r3.2 v1.2 (Aug 2026), a packet's transmitter: preamble, SOP, 4b5b
    payload and CRC-32, EOP, all in BMC at 300 kbps on one line. The host encodes the 4b5b
    symbols and CRC, as the core's CRC is 16 bits at most, and writes a packet's words
    within the 213 us of its preamble. *)

open! Core
open Protocol_emulator

(** The line the firmware drives. *)
val pin : int

(** Cycles a bit at 48 MHz. *)
val bit_cycles : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

module Message : sig
  type t =
    { header : int
    ; data_objects : int list
    }
  [@@deriving sexp_of, compare, equal]

  (** From a Revision 3.x Source and DFP. *)
  val source_capabilities : message_id:int -> int list -> t

  (** A Fixed Supply PDO. *)
  val fixed_5v_3a : int

  val crc : t -> int

  (** The bits after the preamble, in the order on the line. *)
  val line_bits : t -> int list

  (** What the host writes: the bits less one, then the bits 16 a word, LSB first. *)
  val words : t -> int list

  (** A bound on the cycles from the firmware taking the first word to the line's last
      edge. *)
  val cycles : t -> int
end

(** The messages of [bench]'s run. *)
val sent : Message.t list

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
