(** A TI TLC5620 quad DAC's controller, after TI's SLAS081E (November 2001): CLK at 800
    kHz shifting an 11-bit word MSB first on its fall, LOAD pulsed low after the eleventh,
    LDAC held high so a later pulse updates all four outputs. *)

open! Core
open Protocol_emulator

(** CLK is OUT0, then LOAD, LDAC and DATA on the pins after it. *)
val clk : int

val load : int
val ldac : int
val data : int
val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

(** The host word for DAC [dac] (0 to 3, A to D) at [code], with the 2x range if [range]. *)
val command : dac:int -> range:bool -> int -> int

(** The host word that pulses LDAC and sends no clocks. *)
val update : int

module Dac : sig
  type t

  val create : unit -> t
  val step : t -> clk:bool -> data:bool -> load:bool -> ldac:bool -> t

  (** Each DAC's output in units of 1/256 of the reference, after the last LDAC pulse. *)
  val outputs : t -> int list

  val violations : t -> string list
end

val words : int list
val bench : Bench.t
val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
