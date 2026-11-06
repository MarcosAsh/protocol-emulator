(** The host's SPI view of the core. A frame is a command byte (write bit, 7-bit register)
    followed by 16-bit words, high byte first. Extra words repeat the access.

    {v
     0      control: bit 0 start, 1 clear irq, 2 stop, 3 flush, 4 check,
            5 start every engine at once
     1      status
     2      pc
     3-4    now
     5-6    capture
     7      tx
     8      rx (reading pops)
     9      program address
     10     program word (writing increments the address)
     11     select
     12     data address
     13     data word (writing increments the address)
     16-    config fields, write-only, read as zero. 43 and 44 are reserved and
            read zero, so autopull_data and manchester stay at 45-46 for
            existing hosts.

     Load_checker
     64     certificate base
     65     loaded period
     66     flags: bit 0 loaded, 1 single edge, 2 loaded period is a floor
     67     check status: bit 0 busy, 1 accepted, 2 certified, 3 refused
     68     pc it refused at
     69     why it refused

     Line_code
     70     table state
     71     table word (writing increments the state)

     Frame_rx, whatever the select
     72     control: bit 0 arm, 1 50 MHz clock (USB: re-arm at each packet's
            end), 6-2 pad, 7 Usb_frame_rx instead (D- on the next pad),
            8 and up the engine it belongs to, the only one that sees its
            status pins
     73     data address a frame lands at
     74     status: bits 9-0 words, 10 finished, 11 FCS good (USB: CRC-16),
            12 half last word, 13 word dropped, 14 in a frame, 15 armed
     75     USB flags: bit 0 CRC-5 good, 1 CRC-16 good, 2 stuffing error,
            3 whole bytes

     Edge_stamps, whatever the select
     76     mask of pins 0-15
     77     pins 16-19 in bits 3-0, and in bit 4 the engine whose clock times
            them (writing 76 or 77 empties the queue)
     78-79  head's time (79: bits 7-0 its top, 10-8 queue level, 15 lost)
     80-81  pads it saw (reading 81 pops)
    v}

    Program, data, config, table, check and flush only take effect while halted, so a
    flush needs its own write after the stop, and a start only works once the engine is
    certified. Control bit 5 starts every engine on the same cycle, whatever the select,
    and only when all are halted and certified.

    Select picks the engine for every register except the two addresses. It resets to 0
    and keeps only its low [ceil_log2 engines] bits, so with two engines 2 means engine 0.
    A value past the last engine (3 with three engines) reaches none and reads zero.
    Status bit 15 flags another engine's irq, and bit 14 [Engine.Fault.assumption]. With
    one engine there is no select and bit 15 stays low. *)

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
