(** I2C: a master the host drives a byte a word, the same waiting on a slave that
    stretches SCL, a slave, and a logger that reads a slave and sends each byte over UART. *)

open! Core
open Protocol_emulator

val sda : int
val scl : int

(** Master with SCL a quarter period [quarter] cycles. It first clears the bus (UM10204
    3.1.16): up to nine SCL pulses while SDA reads low, then a START and a STOP. *)
val master : quarter:int -> string

(** The master without the bus clear, as the bench's marked copy runs it. *)
val master_without_bus_clear : quarter:int -> string

(** [master] with the quarter period from the host, as its first word: a bus slower than a
    quarter of 31 cycles, which is as long as [set] makes one. *)
val master_host_rate : string

val config : Program_config.t

(** [master] under [stretch_config], each SCL high timed from the poll that sees it, 0 to
    3 cycles after the input. SCL low after 65536 polls, or at an idle bus, lets both
    lines go and answers 0xffff up to a START word. The bus clear ignores SCL. *)
val master_stretch : quarter:int -> string

(** [master_stretch] with the quarter from the host, as [master_host_rate]. *)
val master_stretch_host_rate : string

(** [config] with SCL the jump pin, and [mov pins] reading SDA alone. *)
val stretch_config : Program_config.t

(** Slave. The host sends [address lsl 1] first, then reads every byte the master writes
    to that address and supplies every byte it reads. *)
val slave : Timed_program.t

val slave_config : Program_config.t

(** Reads bytes from the slave at 0x50 and logs each one over UART on [logger_uart_pin], a
    quarter period of 8 and a bit period of 16. *)
val logger : Timed_program.t

val logger_uart_pin : int
val logger_config : Program_config.t

(** Listens to an I2C bus and pushes, for every START or repeated START, the cycles from
    SDA's fall to SCL's, UM10204's t_HD;STA, low 16 bits. Drives no pin. A START that
    finds the rx fifo full is dropped. *)
val start_hold : sda:int -> scl:int -> string

val start_hold_config : scl:int -> Program_config.t

(** A host word for [master]: start[15] read[14] data[13:6] stop[5]. *)
val word : ?start:bool -> ?read:bool -> ?stop:bool -> int -> int

val protocol : Protocol.t
