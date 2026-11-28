(** Compiles a Hardcaml state machine into firmware for one engine, folding the netlist
    per state. Refused, with the state and assignment at fault: anything but one
    [Always.State_machine] over plain regs, a tick counting to a constant ([p]), one 1-bit
    output OUT0, a right-shifting load register ([osr]) and a counter ([x]), or a state
    that neither runs wholly on the tick nor waits for an input bit. *)

open! Core
open! Hardcaml

module Firmware : sig
  type t =
    { source : string
    ; program : Asm.Program.t
    ; config : Program_config.t
    ; period : int
    ; period_from_host : bool
    (** A period too long for [set p] is the host's first word, before any data. *)
    }
end

val compile : Circuit.t -> Firmware.t Or_error.t
