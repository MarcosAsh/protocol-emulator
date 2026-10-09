open! Core
open Protocol_emulator

val assemble : string -> int list

(** Low speed USB packets with the core's CRC and stuff counter. Host words: the bit
    period once, then per packet SYNC, PID, data bytes less one, the data. *)
val usb_tx : Timed_program.t

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

(** Listens to an I2C bus and pushes, for every START or repeated START, the cycles from
    SDA's fall to SCL's, UM10204's t_HD;STA, low 16 bits. Drives no pin. A START that
    finds the rx fifo full is dropped. *)
val start_hold : sda:int -> scl:int -> string

val start_hold_config : scl:int -> Program_config.t

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
