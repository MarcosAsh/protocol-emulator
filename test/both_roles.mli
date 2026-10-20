(** Both roles on one chip: engine 0 a controller and engine 1 a target, each the
    library's firmware, talking on wires no pad shows. A wire is the OR of what the
    engines drive on it, so I2C rides on wires as [I2c.master_on_wires] and
    [I2c.slave_on_wires]. *)

open! Core
open Protocol_emulator

(** [Spi_cs.master] and [Spi_target] in one mode, on wires 22 to 25. *)
module Wire_spi : sig
  val pins : Spi_target.Pins.t
  val half_period : int
  val controller : Spi_cs.Mode.t -> string
  val controller_config : Program_config.t
  val target : Spi_cs.Mode.t -> string
  val target_config : Program_config.t
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
    START, then calls 0x77, which nothing answers, in Standard-mode and Fast-mode; SPI
    sends three frames in each mode, the target answering each byte; UART sends four bytes
    at each of [Uart.bauds]. *)
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

  (** Each firmware the cases name, by name. *)
  val firmware : (string * Timed_program.t) list

  val all : t list
end
