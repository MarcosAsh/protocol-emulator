(** The host's SPI view of the core. A frame is a command byte (write bit, 7-bit register)
    then 16-bit words high byte first; more words repeat the access.

    Registers: 0 control (bit 0 start, 1 clear irq, 2 stop, 3 flush, 4 check), 1 status, 2
    pc, 3-4 now, 5-6 capture, 7 tx, 8 rx (read pops), 9 program address, 10 program word,
    11 select, 12 data address, 13 data word (writes to 10 and 13 increment the address),
    16 on the config fields, write-only and reading zero; for [Load_checker], 64 the
    certificate's base, 65 the loaded period, 66 its flags (bit 0 loaded, 1 single edge),
    67 the check's status (bit 0 busy, 1 accepted, 2 certified, 3 refused), 68 the pc and
    69 the reason it refused. Control bit 5 does nothing. Program, data, config, check and
    flush take effect only while halted, so a flush needs its own write after the stop,
    and a start only once the engine is certified. 43, 44, 70 and 71 are reserved and read
    zero; config skips 43-44 to keep [autopull_data] and [manchester] at 45-46 for
    existing hosts.

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
      ; check : 'a Load_checker.Verdict.t
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { miso : 'a
      ; engines : 'a Engine.Host.t list
      ; check_setup : 'a Load_checker.Setup.t
      }
    [@@deriving hardcaml]
  end

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
