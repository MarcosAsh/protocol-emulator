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

(** [tx_stamped], whose proof adds that the stamp in each frame is the cycle its start bit
    shows. Kept out of [protocol] until the kernel's tests take it in. *)
val stamped : Certified.t

(** The keyboard demo's log to Pico B at 115200 baud, which it loads from
    test/uart_tx_host_rate.hex. *)
val log : Bench.t

val protocol : Protocol.t
