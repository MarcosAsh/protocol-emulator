open! Core
open Protocol_emulator

val assemble : string -> int list
val uart_tx : period:int -> string
val uart_tx_host_rate : string
val uart_rx : period:int -> string
val rx_config : Program_config.t
val spi_master : half_period:int -> string
val sck_pin : int
val mosi_pin : int
val miso_pin : int
val spi_config : Program_config.t

(** Mode 0 slave without chip select. Replies are host words [byte lsl 8]; sck half
    periods of four cycles or more. *)
val spi_slave : string

val slave_sck_pin : int
val slave_mosi_pin : int
val slave_miso_pin : int
val spi_slave_config : Program_config.t
val sda : int
val scl : int
val i2c_master : quarter:int -> string
val i2c_config : Program_config.t

(** Slave. The host sends [address lsl 1] first, then reads every byte the master writes
    to that address and supplies every byte it reads. *)
val i2c_slave : string

val i2c_slave_config : Program_config.t
val i2c_word : ?start:bool -> ?read:bool -> ?stop:bool -> int -> int
