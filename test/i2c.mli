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

(** [master_host_rate] without the bus clear, whose START then STOP [slave] reads as the
    first bit of an address: for a bus no outside slave can hold. *)
val master_host_rate_without_bus_clear : string

(** [master_host_rate] with each START held, and each repeated START and STOP set up,
    [quarters] quarter periods where it has one, as UM10204's tHD;STA, tSU;STA and tSU;STO
    need at its clock: Standard-mode 3, Fast-mode 2. Without [clear_bus] it starts at
    [idle]. *)
val master_host_rate_held : ?clear_bus:bool -> quarters:int -> unit -> string

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

(** The quarters for Standard-mode, 121 for 99.2 kHz, and Fast-mode, 32 for 375 kHz, the
    fastest UM10204's limits allow at 48 MHz with an even clock. *)
val standard_quarter : int

val fast_quarter : int

(** [master] and [slave] on wires 20 (SDA) and 21 (SCL) by [On_wire.open_drain_on_wire],
    the master without its bus clear. Host words as theirs. *)
val wire_sda : int

val wire_scl : int
val master_on_wires : string
val master_on_wires_config : Program_config.t
val slave_on_wires : string
val slave_on_wires_config : Program_config.t

(** [config] with SCL on the bench's IO2, SDA on IO3, and [jmp_pin]. *)
val on_bench_pins : jmp_pin:int -> Program_config.t -> Program_config.t

val protocol : Protocol.t
