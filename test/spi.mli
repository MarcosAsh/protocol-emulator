(** SPI mode 0 without chip select: a master at a half period fixed at assembly, the same
    from one anchor, and a slave. [Spi_cs] has the four modes with a chip select. *)

open! Core
open Protocol_emulator

val master : half_period:int -> string
val sck_pin : int
val mosi_pin : int
val miso_pin : int
val config : Program_config.t
val stream_config : Program_config.t

(** Mode 0 slave without chip select. Replies are host words [byte lsl 8]; sck half
    periods of four cycles or more. *)
val slave : Timed_program.t

val slave_sck_pin : int
val slave_mosi_pin : int
val slave_miso_pin : int
val slave_config : Program_config.t
val protocol : Protocol.t
