(** Protocols as tables: one interpreter firmware, certified once with the data memory
    left free, runs any Mealy machine written as 256 entries in data memory. Every step of
    every table is timed exactly, so no table can make the core miss a deadline. Cycles
    below count from when a step's outputs show on the pins. *)

open! Core
open Protocol_emulator

module Pin : sig
  type t =
    | A
    | B
  [@@deriving sexp_of, equal, enumerate]
end

(** What a step does after its outputs show, and how long it lasts. *)
module Kind : sig
  type t =
    | Plain (** [hold + 19] cycles to the next step's outputs *)
    | Shift (** p <- 2p + the in_base pin, read at 7; [hold + 26] *)
    | Pull (** p <- the next host word, without waiting; [hold + 28] *)
    | Push (** the host <- p; [hold + 31] *)
    | Stamp (** the host <- the low 16 bits of the cycle at 13; [hold + 31] *)
    | Burst
    (** Waits for a host word w, then sends bits 4 to [4 + w[3:0]] of it on out_base, each
        [hold + 6] cycles; the next outputs show [hold + 22] after the last bit. *)
    | Await_host (** waits for a host word into p; [hold + 16] from the wait *)
    | Await of
        { pin : Pin.t
        ; level : bool
        } (** waits for the pin at the level; [hold + 17] from the wait *)
  [@@deriving sexp_of, equal]

  val all : t list
  val code : t -> int

  (** What the interpreter adds to [t] beyond the hold. *)
  val added : t -> int

  val burst_bit : int

  (** The shortest step, or burst bit. *)
  val least : t -> int
end

(** Where the interpreter's pins are: [inputs] (1 to 6) pins from [in_base], the first of
    them the one [Shift] reads, and 6 outputs from [out_base], driven, or with
    [open_drain] on the bidirectional pins, where a 1 pulls the line low. *)
module Wiring : sig
  type t =
    { inputs : int
    ; in_base : int
    ; out_base : int
    ; open_drain : bool
    ; await_a : int
    ; await_b : int
    }
  [@@deriving sexp_of]

  (** One input on pin 0, outputs from pin 5, the awaits on pins 0 and 1. *)
  val default : t

  (** [2 ^ (7 - inputs)] *)
  val states : t -> int
end

val entries : int
val output_bits : int
val max_hold : int
val burst_bits : int
val interpreter : Wiring.t -> string
val config : Wiring.t -> Program_config.t

(** The kernel's verdict on [interpreter], the data memory unknown to it. *)
val check : Wiring.t -> (Timed_program.t, Timed_program.Refusal.t) Result.t

module type State = sig
  type t [@@deriving equal, sexp_of]
end

(** An entry. [cycles] is the step's length as [Kind] times it, the hold plus
    [Kind.added], or a burst's bit: from [Kind.least kind] to 65535 more. *)
module Step : sig
  type 'state t =
    { outputs : int
    ; kind : Kind.t
    ; cycles : int
    ; next : 'state
    }
  [@@deriving sexp_of]
end

(** A protocol as a table. [step] gives each state's entry for the host bit p[15] and the
    inputs, both as the step before left them; the first step is the first state's entry
    for host bit false and inputs 0. *)
type 'state t =
  { name : string
  ; wiring : Wiring.t
  ; state : (module State with type t = 'state)
  ; states : 'state list
  ; step : 'state -> host_bit:bool -> inputs:int -> 'state Step.t
  }

(** The 512 data words, or why the table is outside the class. *)
val words : _ t -> int list Or_error.t

(** A host word whose bits the host bit shows in turn as [Shift] moves them up. *)
val host_bits : bool list -> int

(** A host word a [Burst] sends: 1 to 12 bits, the first first. *)
val burst_word : bool list -> int

module Uart_tx : State
module Uart_rx : State
module Uart_burst : State
module Spi_master : State
module Dshot_bits : State
module I2c_slave : State

(** UART 8N1 on out_base, a bit at a time: each host word is [uart_word byte], whose bits
    the table reads as the host bit and shifts on. A bit is [bit] cycles, at least
    [Kind.least Shift]. *)
val uart_tx : bit:int -> Uart_tx.t t

val uart_word : int -> int

(** UART 8N1 from in_base: [Await] on the start bit's edge, then a [Shift] in the middle
    of each bit, then a [Push] of the byte, first bit highest. A bit is [bit] cycles, from
    [Kind.least Shift]; frames need about a bit and a half of idle between them. *)
val uart_rx : bit:int -> Uart_rx.t t

(** The same by burst: each host word is a whole frame, [uart_frame byte]. A bit is [bit]
    cycles, at least [Kind.burst_bit]. *)
val uart_tx_burst : bit:int -> Uart_burst.t t

val uart_frame : int -> int

(** SPI mode 0, full duplex: MOSI on out_base, SCK on the next pin, MISO on in_base. Each
    host word is a byte in its high 8 bits; the byte read comes back in the low 8 bits of
    a pushed word. SCK is low for [half] cycles and high for [half]. *)
val spi_master : half:int -> Spi_master.t t

(** DShot from host frame words, MSB first, on out_base. *)
val dshot : zero_high:int -> bit:int -> Dshot_bits.t t

(** Takes writes to [address] on SDA [sda] and SCL [sda + 1], open drain, and acks the
    address and each byte. Each byte goes to the host as [0x8000 lor byte]. The host keeps
    a [marker] word queued for every byte: it reaches the host bit as the eighth bit comes
    in. START and STOP are watched for on the first bit of a byte only, as [I2c.slave]
    does. *)
val i2c_slave : address:int -> sda:int -> I2c_slave.t t

val marker : int
