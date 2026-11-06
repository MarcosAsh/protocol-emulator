(** Both roles on one chip: engine 0 is a controller, engine 1 a target, each running the
    library's firmware over wires no pad shows. A wire is the OR of what the engines drive
    on it, so I2C uses [I2c.master_on_wires] and [I2c.slave_on_wires]. *)

open! Core
open Protocol_emulator

(** [Spi_cs.master] and [Spi_target] in one mode, on wires 22 to 25. *)
module Wire_spi : sig
  val pins : Spi_target.Pins.t
  val half_period : int
  val controller : Spi_cs.Mode.t -> string
  val controller_config : Program_config.t
  val target : Spi_cs.Mode.t -> string
end

(** One engine's firmware and its host words: a fifo's worth before the start, the rest as
    soon as the fifo has room. *)
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
    ; mismatch : System_lockstep.Mismatch.t option (** The first mismatch, on the RTL. *)
    }
  [@@deriving sexp_of]
end

(** [controller] on engine 0 and [target] on engine 1, started together, on the [System]
    model alone. The pads read [pads] (0 by default). Each engine watches its
    certificate's premises, as the chip does. *)
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
    kernel. I2C: write two bytes to the target at 0x42, read two back after a repeated
    START, then call 0x77 (nothing answers), in Standard-mode and Fast-mode. SPI: three
    frames in each mode, the target answering each byte. UART: four bytes at each of
    [Uart.bauds]. *)
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
