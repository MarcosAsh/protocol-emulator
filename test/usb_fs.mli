(** USB full speed: a device on engine 0, which [Usb_frame_rx], re-armed, feeds every
    packet, and which answers from records the host loads into the data memory before the
    start. *)

open! Core
open Protocol_emulator

(** D+ is IO0 and D- IO1; the receiver's finished, good and receiving are status pins. *)
val dp_pin : int

val dm_pin : int
val finished_pin : int
val good_pin : int
val receiving_pin : int

(** Out through the line table's NRZI on D+, D- its complement; set on both, so SE0 and J
    go out as they are. *)
val config : Program_config.t

val line_table : Line_code.t

(** Where the receiver lands each packet. *)
val rx_base : int

(** The records the program reads at fixed places, and where a host's may start. *)
val nak_record : int

val ack_record : int
val first_record : int

(** Cycles from the [mov t, now] after a good packet to the deadline the reply's SYNC
    starts at, on every way to a reply. *)
val turnaround : int

(** The device. The host sends its IN token word for endpoint 0 first. A packet with a bad
    CRC wakes nothing. An IN that matches the pending reply's token word gets its record,
    if the record's word is in the fifo; any other IN to this address gets a NAK, as does
    one whose record is still on its way. A SETUP or OUT to this address and endpoint 0
    readies an ACK for the data packet after it: a SETUP's PID and eight bytes go to the
    host as five words, the first holding the PID low, after which the record is ACKed,
    and an OUT's ACK sends tag 2. After a record goes out, the host's ACK sends tag 3, and
    anything else tag 4. Between packets, with nothing pending, the program takes the next
    word from the fifo: a reply's IN token word, its record's address following it, or
    another address's IN token word, which becomes the address from then on. A record
    holds its line bits less one, then the line bits, sixteen a word, first bit lowest.
    Endpoint bits 1-3 of an IN are not compared. *)
val device : string

(** The words of [packet]'s record, its bytes after SYNC, PID first: SYNC and the bit
    stuffing are added, and the line table adds the NRZI. *)
val record : int list -> int list

(** The token word a reply for an IN to this address and endpoint waits behind. *)
val in_token : address:int -> endpoint:int -> int

(** The data memory the host loads: NAK and ACK at their fixed places, then each packet's
    record. *)
module Layout : sig
  type t =
    { words : int array
    ; addresses : (int list * int) list
    }

  val create : int list list -> t
  val address : t -> int list -> int
end

(** Certified with the data memory read as anything, as packets land in it, and the core
    within 84 ms of its deadline, as it waits on the bus for as long as the host is quiet. *)
val certified : Certified.t

val protocol : Protocol.t
