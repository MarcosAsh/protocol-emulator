(** PS/2 device (keyboard side): open drain data on IO0, clock on IO1. The host's first
    word is a quarter clock period in cycles (1000 at 48 MHz is 12 kHz). Later words are
    bytes to send, with start, parity and stop. The device drops a frame if the host holds
    the clock low and raises the interrupt. A request to send pushes
    [data lor (parity lsl 8) lor (stop lsl 9)]. Shortest quarter: 8 cycles. *)

open! Core
open Protocol_emulator

val data_pin : int
val clock_pin : int

(** 20.8 us at 48 MHz. *)
val standard_quarter : int

val firmware : Timed_program.t
val config : Program_config.t

(** The host at the other end. It times the clock the device makes (30 to 50 us low and
    high) and checks data moves only while the clock is high, 5 us after the rise to 5 to
    25 us before the fall, and each frame's start, odd parity and stop. Its script holds
    the clock low 100 us at given cycles, to inhibit the device or send it a byte. *)
module Host : sig
  module Action : sig
    type t =
      | Inhibit
      | Send of int
    [@@deriving sexp_of]
  end

  type t

  val create : clock_hz:int -> (int * Action.t) list -> t
  val clock_low : t -> bool
  val data_low : t -> bool
  val step : t -> clock:int -> data:int -> t
  val log : t -> string list
  val measured : t -> Measured.t
  val violations : t -> string list
end

val protocol : Protocol.t
