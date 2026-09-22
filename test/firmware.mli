open! Core
open Protocol_emulator

val assemble : string -> int list
val uart_tx : period:int -> string
val uart_tx_host_rate : string
val uart_rx : period:int -> string

(** [uart_rx] on another line, which the configuration has to name as well: [in_base],
    [jmp_pin] and [capture_pin]. *)
val uart_rx_on : pin:int -> period:int -> string

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

(** Toggles OUT0 every [period] cycles and pushes the capture time of each rising edge on
    IN0, which is wired back to OUT0. *)
val edge_meter : period:int -> string

val edge_meter_config : Program_config.t

(** Pushes the low 16 bits of [now] for every edge on [pin], rising and falling, starting
    with the first edge after it starts. Edges have to come at least five cycles apart. *)
val edge_logger : pin:int -> string

val edge_logger_config : pin:int -> Program_config.t
val i2c_word : ?start:bool -> ?read:bool -> ?stop:bool -> int -> int

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
val usb_device : address:int -> half_period:int -> string

val usb_device_dp_pin : int
val usb_device_dm_pin : int
val usb_device_flag_pin : int
val usb_device_config : Program_config.t
