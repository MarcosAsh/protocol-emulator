(** USB low speed: a transmitter, a receiver and a device on the core, and a host port and
    the demo board around a [Machine] that runs [device], with D+ and D- as a shared wire.
    The host side sends tokens and data and listens; the board side reads the words the
    core pushes, answers requests from a table of descriptors after [latency] cycles,
    which is what makes the core send NAKs, and reloads the core when the address changes. *)

open! Core
open Protocol_emulator

(** Low speed USB packets with the core's CRC and stuff counter. Host words: the bit
    period once, then per packet SYNC, PID, data bytes less one, the data. *)
val tx : Timed_program.t

val scratch_pin : int
val dp_pin : int
val dm_pin : int
val config : Program_config.t

(** Receives low speed packets on [rx_dp_pin] and [rx_dm_pin]: one host word per byte, the
    byte in the high half, then the CRC register as a final word. *)
val rx : half_period:int -> string

val rx_dm_pin : int
val rx_dp_pin : int
val rx_config : Program_config.t

(** USB low speed device for [address], endpoints 0 and 1. The host sends the bit period
    first. A token that is not ours is ignored together with the data that follows it.
    After a SETUP or OUT that is ours the data goes to the host, a tag word first (1 for
    DATA0, 2 for DATA1), and is acknowledged if its CRC is good; a bad one raises the
    interrupt. An IN that is ours gets a NAK two and a half bit times after the end of its
    EOP, or, when the host has queued a reply for that endpoint, the reply: a word with
    the endpoint in the low byte and the PID in the high byte, a word with the number of
    data bits in the low byte and of data words in the high byte, then the data two bytes
    a word, the first byte low, all of it in the fifo before the token arrives. SYNC, the
    CRC-16 and the bit stuffing are added here. A reply queued for the other endpoint is
    dropped, which the host hears of as tag 4, and that IN gets a NAK. The host's ACK
    comes back as tag 3. D+ is IO0, D- is IO1, and IO2 is a flag the program keeps for
    itself. *)
val device : address:int -> half_period:int -> string

val device_dp_pin : int
val device_dm_pin : int
val device_flag_pin : int
val device_config : Program_config.t

module Request : sig
  type t =
    { request_type : int
    ; request : int
    ; value : int
    ; index : int
    ; length : int
    }

  val get_descriptor : ?interface:bool -> kind:int -> length:int -> unit -> t
  val set_address : int -> t
  val set_configuration : int -> t
end

type t

(** Cycles to a bit: 48 MHz. *)
val bit_period : int

(** PIDs, with their check bits. *)
val ack : int

val nak : int
val data0 : int
val data1 : int

(** A token's bytes after SYNC, PID first, CRC5 last. *)
val token : address:int -> pid:int -> endpoint:int -> int list

(** A data packet's bytes after SYNC, PID first, CRC16 last. *)
val data : pid:int -> int list -> int list

(** The words a board queues to answer an IN on [endpoint] with [payload]. *)
val reply : endpoint:int -> pid:int -> int list -> int list

(** [descriptors] by descriptor type. *)
val create
  :  ?reset_cycles:int
  -> descriptors:(int * int list) list
  -> latency:int
  -> unit
  -> t

(** The host holds SE0 long enough for a bus reset. The board sees it on the wire and
    reloads the core for address 0. *)
val reset : t -> unit

(** A control read: SETUP, IN until the data is complete, the status OUT. *)
val control_in : t -> Request.t -> int list

(** A control write with no data: SETUP and the status IN. *)
val control_out : t -> Request.t -> unit

(** The board queues a report for the next IN on the interrupt endpoint. *)
val report : t -> int list -> unit

(** One IN; [None] is a NAK. *)
val interrupt_in : t -> endpoint:int -> int list option

(** What each load of the core saw, in order: the address it was assembled for and, per
    cycle, the input pins and the word the board wrote, if any. Enough to run the same
    thing again somewhere else. *)
val recording : t -> (int * (int * int option) list) list

val naks : t -> int
val faults : t -> Machine.Fault.t
val protocol : Protocol.t
