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

(** Reads bytes from the slave at 0x50 and logs each one over UART on [logger_uart_pin], a
    quarter period of 8 and a bit period of 16. *)
val i2c_logger : string

val logger_uart_pin : int
val i2c_logger_config : Program_config.t

(** Low speed USB packets with the core's CRC and stuff counter. Host words: the bit
    period once, then per packet SYNC, PID, data bytes less one, the data. *)
val usb_tx : string

val usb_scratch_pin : int
val usb_dp_pin : int
val usb_dm_pin : int
val usb_config : Program_config.t

(** Receives low speed packets on [usb_rx_dp_pin] and [usb_rx_dm_pin]: one host word per
    byte, the byte in the high half, then the CRC register as a final word. *)
val usb_rx : half_period:int -> string

val usb_rx_dm_pin : int
val usb_rx_dp_pin : int
val usb_rx_config : Program_config.t
val i2c_word : ?start:bool -> ?read:bool -> ?stop:bool -> int -> int
