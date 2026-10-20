(** UART, 8N1 LSB first: transmitters at a bit period fixed at assembly, from the host, or
    from one anchor, and a receiver that samples mid bit. *)

open! Core
open Protocol_emulator

val tx : period:int -> string

(** [tx ~period:16], checked when it compiles. *)
val tx16 : Timed_program.t

(** Each host word goes out as a 26-bit frame: start bit, the low byte, the low 16 bits of
    [now] in the cycle the start bit first shows on the pin, stop bit, all LSB first. *)
val tx_stamped : period:int -> string

(** [tx] with the bit period from the host, as its first word. *)
val tx_host_rate : string

(** [tx] with no wait on the host: frames back to back from one anchor, a byte a frame by
    autopull in the low half of each host word. The host has to keep up; a byte that is
    late sets the underflow fault and the line sends what [osr] holds instead. *)
val tx_stream : period:int -> string

val stream_config : Program_config.t

(** [rx] on another line, which the configuration has to name as well: [in_base],
    [jmp_pin] and [capture_pin]. *)
val rx_on : pin:int -> period:int -> string

val rx : period:int -> string
val rx_config : Program_config.t

(** [rx_on] with half the bit period from the host, as its first word, and the stop bit
    checked at its middle. *)
val rx_host_rate_on : pin:int -> string

val rx_host_rate : string

(** 9600 to 230400 baud, each on the bench as [tx_host_rate] at OUT0, uart_tx_<baud>, held
    to [limits_at]. *)
val bauds : int list

(** A bit within 2% of [baud] (Maxim AN2141), on [firmware]'s line. *)
val limits_at : baud:int -> string -> Datasheet.t list

(** [tx_stamped], whose proof adds that the stamp in each frame is the cycle its start bit
    shows. Kept out of [protocol] until the kernel's tests take it in. *)
val stamped : Certified.t

(** The keyboard demo's log to Pico B at 115200 baud, which it loads from
    test/uart_tx_host_rate.hex. *)
val log : Bench.t

val protocol : Protocol.t
