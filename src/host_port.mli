(** The host's view of the core over SPI. A frame is a command byte, write bit then a
    seven bit register number, followed by 16-bit words high byte first. Several words in
    one frame repeat the access, which streams the fifos and the program window.

    Registers: 0 control (bit 0 start, bit 1 clear irq, bit 2 stop; the program can only
    be written while the core is halted), 1 status, 2 pc, 3 and 4 now, 5 and 6 capture, 7
    tx fifo, 8 rx fifo (a read pops), 9 program address, 10 program word (a write
    increments the address), 16 onwards the config fields in order. *)

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
    }
  [@@deriving hardcaml]
end

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; sck : 'a
    ; mosi : 'a
    ; cs_n : 'a
    ; status : 'a Status.t
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { miso : 'a
    ; start : 'a
    ; clear_irq : 'a
    ; stop : 'a
    ; program_write : 'a Engine.Program_write.t
    ; tx : 'a With_valid.t
    ; rx_pop : 'a
    ; config : 'a Engine.Config.t
    }
  [@@deriving hardcaml]
end

(** The frame state machine, named for waveforms: [C] awaiting the command byte, then the
    high and low byte of each word. *)
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
  val config : int
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
