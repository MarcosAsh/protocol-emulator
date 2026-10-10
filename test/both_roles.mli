(** Both roles on one chip: engine 0 a controller and engine 1 a target, each the
    library's firmware, talking on wires no pad shows. A wire is the OR of what the
    engines drive on it, so an open drain line rides on one as its pull, 1 while an engine
    holds the line low. *)

open! Core
open Protocol_emulator

(** Open drain firmware moved from pads to wires, [pins] mapping each pad to its wire:
    drives of [pindirs] become drives of [pins], waits and jumps on a line wait and jump
    on the other level, and each [in pins] reads the wires inverted through [y] first. The
    program and its host words stay the library's; it has to hold nothing in [y] across a
    read, which no library I2C firmware does. Raises on any other use of a pin. *)
val open_drain_on_wire : pins:(int * int) list -> string -> string

(** The pins a firmware's waits name, moved by [pins], as its configuration moves the
    rest. *)
val move_pins : pins:(int * int) list -> string -> string

module I2c : sig
  val sda : int
  val scl : int

  (** [Firmware.i2c_master_host_rate_without_bus_clear]: the host's first word is the
      quarter period. Nothing outside can hold a wire, and the target reads a bus clear's
      START then STOP as an address bit. *)
  val controller : string

  val controller_config : Program_config.t

  (** [Firmware.i2c_slave]: the host's first word is [address lsl 1]. *)
  val target : string

  val target_config : Program_config.t
end

(** The same roles on the bench's I2C bus, IO2 and IO3, where the pads show them and other
    parts share the bus: the controller is
    [Firmware.i2c_master_host_rate_held ~quarters:2], Fast-mode, without its bus clear,
    and the target [Firmware.i2c_slave]. An engine reads the other's drive, and the pad,
    pulled up, where neither drives. *)
module Bus : sig
  val controller : string
  val controller_config : Program_config.t
  val target : string
  val target_config : Program_config.t

  (** The pull-ups, for [model] and [rtl]. *)
  val pads : int
end

(** [Spi_cs.master] and [Spi_target] in one mode, on wires. *)
module Spi : sig
  val pins : Spi_target.Pins.t
  val half_period : int
  val controller : Spi_cs.Mode.t -> string
  val controller_config : Program_config.t
  val target : Spi_cs.Mode.t -> string
  val target_config : Program_config.t
end

(** [Firmware.uart_tx_host_rate] to [Firmware.uart_rx_host_rate_on], both at the bit
    period their host sends first. *)
module Uart : sig
  val line : int
  val transmitter : string
  val transmitter_config : Program_config.t
  val receiver : string
  val receiver_config : Program_config.t
end

(** One engine's firmware, and the host words it gets: a fifo's worth before the start,
    the rest each as soon as the fifo has room. *)
module Side : sig
  type t =
    { timed : Timed_program.t
    ; words : int list
    }
end

module Outcome : sig
  type t =
    { controller : int list (** What each engine pushed, in order. *)
    ; target : int list
    ; faults : Machine.Fault.t list
    ; irq : bool list
    ; mismatch : System_lockstep.Mismatch.t option (** On the RTL, the first. *)
    }
  [@@deriving sexp_of]
end

(** [controller] on engine 0 and [target] on engine 1, started together, on the [System]
    model alone, the pads at [pads], 0 unless given. *)
val model
  :  ?pads:int
  -> cycles:int
  -> controller:Side.t
  -> target:Side.t
  -> unit
  -> Outcome.t

(** The same on [Engines] beside the model, compared every cycle. *)
val rtl
  :  ?pads:int
  -> cycles:int
  -> controller:Side.t
  -> target:Side.t
  -> unit
  -> Outcome.t

(** What the bench runs: each pair with its host words, every firmware passed by the
    kernel. I2C writes two bytes to the target at 0x42 and reads two back after a repeated
    START, then calls 0x77, which nothing on the wires or the bench's bus answers; SPI
    sends three frames, the target answering each byte; UART sends four bytes at each of
    [Rates.bauds]. *)
module Case : sig
  type t =
    { name : string
    ; controller_name : string
    ; controller : Timed_program.t
    ; target_name : string
    ; target : Timed_program.t
    ; controller_words : int list
    ; target_words : int list
    ; pads : int
    ; cycles : int (** Enough for the model to finish. *)
    }

  (** Standard-mode's quarter at 48 MHz, 121 cycles for 99.2 kHz, and Fast-mode's, 32 for
      375 kHz: the fastest each mode's limits allow ([Rates]). *)
  val standard : int

  val fast : int

  (** Each firmware the cases name, by name. *)
  val firmware : (string * Timed_program.t) list

  val all : t list
end
