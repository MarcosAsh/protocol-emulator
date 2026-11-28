(** The host's SPI view of the core: a command byte (write bit, 7-bit register), then
    16-bit words, high byte first, extra words repeating the access. The registers are in
    docs/info.md. Program, data, config, table, check and flush only take effect while
    halted, and a start only once the engine is certified. Select keeps
    [ceil_log2 engines] bits, so a value past the last engine reaches none and reads zero. *)

open! Core
open! Hardcaml

module Status : sig
  type 'a t =
    { pc : 'a
    ; now : 'a
    ; capture : 'a
    ; halted : 'a
    ; irq : 'a
    ; fault : 'a Engine.Fault.t
    ; tx_level : 'a
    ; rx_level : 'a
    ; rx_head : 'a
    ; certified : 'a (** [Engines.Check]'s, for this engine. *)
    ; refused : 'a
    }
  [@@deriving hardcaml]
end

(** Frame states, named for waveforms: [C] awaits the command byte. *)
module State : sig
  type t

  val names : string list
end

module Reg : sig
  val control : int
  val status : int
  val pc : int
  val now_lo : int
  val now_hi : int
  val capture_lo : int
  val capture_hi : int
  val tx : int
  val rx : int
  val program_addr : int
  val program : int
  val select : int
  val data_addr : int
  val data : int
  val config : int
  val check_base : int
  val check_loaded : int
  val check_flags : int
  val check_status : int
  val reject_pc : int
  val reject_reason : int
  val line_addr : int
  val line : int
  val frame_control : int
  val frame_base : int
  val frame_status : int
  val stamp_mask : int
  val stamp_control : int
  val stamp_time_lo : int
  val stamp_time_hi : int
  val stamp_pins_lo : int
  val stamp_pins_hi : int

  (** Each [Engine.Config] field's register, skipping the reserved ones. *)
  val configs : int list

  (** Read zero, take no write. *)
  val reserved : int list
end

module type Config = sig
  val engines : int
end

module Make (_ : Config) : sig
  module I : sig
    type 'a t =
      { clocking : 'a Clocking.t
      ; sck : 'a
      ; mosi : 'a
      ; cs_n : 'a
      ; status : 'a Status.t list
      ; check : 'a Load_checker.Verdict.t list (** Each engine's. *)
      ; frame : 'a Frame_rx.Status.t
      ; usb : 'a Usb_frame_rx.Status.t
      ; stamps : 'a Edge_stamps.O.t
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { miso : 'a
      ; engines : 'a Engine.Host.t list
      ; check_setup : 'a Load_checker.Setup.t
      ; start_all : 'a
      ; frame : 'a Frame_rx.Control.t
      ; frame_pin : 'a (** The pad [Frame_rx] decodes. *)
      ; frame_usb : 'a (** [Usb_frame_rx] takes the frames, D+ on [frame_pin]. *)
      ; frame_owner : 'a (** [Engines.I.frame_owner]. *)
      ; stamps : 'a Edge_stamps.Control.t
      }
    [@@deriving hardcaml]
  end

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
