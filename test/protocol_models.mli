open! Core

val runs : int list -> (int * int) list
val decode_uart : int list -> period:int -> int list
val serial_levels : int list -> period:int -> stop:int -> int list

module Spi_slave : sig
  type t

  val create : int list -> t
  val miso : t -> int
  val step : t -> sck:int -> mosi:int -> t
  val received : t -> int list
end

(** Mode 0 master. [create] queues the bytes to send; the clock runs while any are left,
    with [gap] idle cycles between bytes. *)
module Spi_peer : sig
  type t

  val create : ?gap:int -> half_period:int -> int list -> t
  val sck : t -> int
  val mosi : t -> int
  val step : t -> miso:int -> t
  val received : t -> int list
  val idle : t -> bool
end

module I2c_slave : sig
  type t

  val create : address:int -> memory:int array -> t
  val drive_low : t -> bool
  val step : t -> sda:int -> scl:int -> t
  val log : t -> string list
end

(** Master at the pins, driving a scripted transaction with a quarter bit period of
    [quarter] cycles. [sda] and [scl] are 0 when it drives the line low. Its log holds the
    bytes it read and the acks it saw. *)
module I2c_peer : sig
  module Op : sig
    type t =
      | Start
      | Write of int
      | Read of { ack : bool }
      | Stop
    [@@deriving sexp_of]
  end

  type t

  val create : quarter:int -> Op.t list -> t
  val sda : t -> int
  val scl : t -> int
  val step : t -> sda:int -> t
  val log : t -> string list
  val idle : t -> bool
end

(** USB low speed at the bit level: CRCs, bit stuffing, NRZI, and a sniffer that turns the
    D+ and D- levels sampled every cycle back into packets. *)
module Usb_ls : sig
  val crc5 : int list -> int
  val crc16 : int list -> int
  val bits_of_bytes : int list -> int list

  module Line : sig
    type t =
      | J
      | K
      | Se0
    [@@deriving sexp_of, equal]
  end

  (** The line states of one packet, one per bit time, SYNC and EOP included. *)
  val encode : int list -> Line.t list

  module Sniffer : sig
    type t

    val create : bit_period:int -> t
    val step : t -> dp:int -> dm:int -> t

    (** Packets seen so far, bytes after SYNC, PID first. *)
    val packets : t -> int list list
  end
end
