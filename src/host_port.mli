(** The host's SPI view of the core. A frame is a command byte (write bit, 7-bit register)
    then 16-bit words high byte first; more words repeat the access.

    Registers: 0 control (bit 0 start, 1 clear irq, 2 stop, 3 flush), 1 status, 2 pc, 3-4
    now, 5-6 capture, 7 tx, 8 rx (read pops), 9 program address, 10 program word, 11
    select, 12 data address, 13 data word (writes to 10 and 13 increment the address), 16
    on the config fields, write-only and reading zero. Control bits 4-5 do nothing.
    Program, data, config and flush take effect only while halted, so a flush needs its
    own write after the stop. 43, 44 and 64-71 are reserved and read zero, but 43 arms a
    journal if the chip has one; config skips 43-44 to keep [autopull_data] and
    [manchester] at 45-46 for existing hosts.

    Select picks the engine for every register but the two addresses; it resets to 0 and
    past the last engine reaches none and reads zero. Status bit 15 flags another engine's
    irq. With one engine there is no select and bit 15 stays low. *)

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

  (** Reserved but with a journal: 1 arms it, 0 disarms it. *)
  val journal : int

  (** Each [Engine.Config] field's register, skipping the reserved ones. *)
  val configs : int list

  (** Read zero, take no write. *)
  val reserved : int list
end

module type Config = sig
  val engines : int
  val journal : bool
end

module Make (_ : Config) : sig
  module I : sig
    type 'a t =
      { clocking : 'a Clocking.t
      ; sck : 'a
      ; mosi : 'a
      ; cs_n : 'a
      ; status : 'a Status.t list
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { miso : 'a
      ; engines : 'a Engine.Host.t list
      ; journal : 'a Journal.Arm.t list (** Writes to [Reg.journal], with a journal. *)
      }
    [@@deriving hardcaml]
  end

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
