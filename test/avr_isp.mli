(** An AVR in-system programmer's SPI side, after the ATmega48/88/168 datasheet
    (Atmel-2545W, November 2016) section 32.8: RESET and SCK held low, a 20 ms wait, then
    4-byte instructions on mode 0 SPI. The limits assume a target as shipped, clocked at 1
    MHz, so a CPU clock cycle is 1 us. *)

open! Core
open Protocol_emulator

(** SCK is OUT0, RESET the pin after it, MOSI OUT3 and MISO IN0. *)
val sck : int

val reset : int
val mosi : int
val miso : int

(** SCK's high and low, in cycles. *)
val half : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

(** The host's two words for an instruction of 4 [bytes]. *)
val instruction : int list -> int list

val programming_enable : int list
val read_signature : int -> int list
val read_fuse : int list

(** The bench's and scenario's: programming enable, the three signature bytes, the low
    fuse. *)
val instructions : int list list

module Atmega88 : sig
  type t

  val create : unit -> t
  val step : t -> sck:bool -> reset:bool -> mosi:bool -> t

  (** MISO's level now. *)
  val miso : t -> bool

  (** Each instruction as its 4 bytes were taken. *)
  val log : t -> int list list

  val violations : t -> string list
end

val bench : Bench.t
val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
