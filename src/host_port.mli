(** The host's view of the core over SPI. A frame is a command byte, write bit then a
    seven bit register number, followed by 16-bit words high byte first. Several words in
    one frame repeat the access, which streams the fifos and the program window.

    Registers: 0 control (bit 0 start, bit 1 clear irq, bit 2 stop, bit 3 flush both
    fifos, bit 4 resume, bit 5 single step; the program and the config fields can only be
    written and the fifos only flushed while the core is halted, so a flush takes a write
    of its own after the stop), 1 status, 2 pc, 3 and 4 now, 5 and 6 capture, 7 tx fifo, 8
    rx fifo (a read pops), 9 program address, 10 program word (a write increments the
    address), 11 select, 12 data address, 13 data word (a write increments the address,
    only while halted), 16 onwards the config fields in order, which can only be written
    and read as zero, and for a debugger 0x40 x, 0x41 y, 0x42 p, 0x43 and 0x44 t, 0x45
    isr, 0x46 osr, 0x47 the isr count and the osr count shifted up by 8.

    With more than one engine, select names the engine that every other register but the
    program and data addresses reaches: control, status, pc, now, capture, both fifos, the
    program and data windows and the config fields, which each engine has for itself. It
    resets to 0, and a number past the last engine reaches none and reads as zero. Status
    bit 15 says some other engine has its irq up. With one engine there is no select and
    the bit stays low. *)

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
    ; x : 'a
    ; y : 'a
    ; p : 'a
    ; t : 'a
    ; isr : 'a
    ; osr : 'a
    ; isr_count : 'a
    ; osr_count : 'a
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
  val select : int
  val data_addr : int
  val data : int
  val config : int
  val x : int
  val y : int
  val p : int
  val t_lo : int
  val t_hi : int
  val isr : int
  val osr : int
  val counts : int
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
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { miso : 'a
      ; engines : 'a Engine.Host.t list
      }
    [@@deriving hardcaml]
  end

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
