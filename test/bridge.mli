(** A UART to SPI bridge across both engines. Engine 0 receives on IN0 and sends each byte
    on a wire as UART; engine 1 receives it there and clocks it out MSB first on OUT0
    (MOSI) and OUT1 (SCK), mode 0, no chip select. Each firmware is [Uart.rx_on] whose
    good frame runs a library transmitter from [isr] instead of pushing. *)

open! Core
open Protocol_emulator

(** Cycles a bit on IN0 and on the wire, and an SPI half period. *)
val period : int

val wire : int
val sck_pin : int
val mosi_pin : int

(** Engine 0, certified by the kernel. *)
val relay : Timed_program.t

(** Engine 1, certified by the kernel. *)
val controller : Timed_program.t

(** Fewest cycles from one frame's start bit on IN0 to the next that the bridge keeps up
    with. *)
val spacing : int

(** IN0's level in a cycle, for frames of [(start, byte)]. *)
val line : (int * int) list -> int -> int

module Frame : sig
  type t =
    { stop : int (** The cycle IN0's stop bit begins, the frame's last possible edge. *)
    ; wire_fall : int (** The cycle the wire's start bit shows. *)
    ; first_rise : int (** SCK's first rise. *)
    ; last_fall : int (** SCK's last fall. *)
    ; byte : int (** What MOSI showed at SCK's eight rises. *)
    }
  [@@deriving sexp_of]
end

module Outcome : sig
  type t =
    { frames : Frame.t list
    ; faults : Machine.Fault.t list
    ; irq : bool list
    ; mismatch : System_lockstep.Mismatch.t option (** On the RTL, the first. *)
    }
  [@@deriving sexp_of]
end

(** Both engines started together, frames of [(start, byte)] on IN0, on the [System] model
    alone. *)
val model : cycles:int -> (int * int) list -> Outcome.t

(** The same on [Engines] beside the model, compared every cycle. *)
val rtl : cycles:int -> (int * int) list -> Outcome.t

(** On the Tiny Tapeout top, its pins judged by sigrok's UART and SPI decoders. *)
val scenario : Pin_trace.Scenario.t
