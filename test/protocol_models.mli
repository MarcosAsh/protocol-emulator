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

module I2c_slave : sig
  type t

  val create : address:int -> memory:int array -> t
  val drive_low : t -> bool
  val step : t -> sda:int -> scl:int -> t
  val log : t -> string list
end
