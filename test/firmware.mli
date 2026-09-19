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
val sda : int
val scl : int
val i2c_master : quarter:int -> string
val i2c_config : Program_config.t
val i2c_word : ?start:bool -> ?read:bool -> ?stop:bool -> int -> int
