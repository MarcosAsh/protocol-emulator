(** What a host does over SPI before it starts an engine: writes the certificate for the
    selected engine's program to the data memory, while every engine is halted, sets the
    check's registers and waits for its verdict. *)

open! Core
open Protocol_emulator

(** Raises if the chip refuses the program. *)
val certify
  :  Spi_master.t
  -> watch:(int -> unit) @ local
  -> assumptions:System_lockstep.Assumptions.t
  -> config:Program_config.t
  -> int list
  -> unit
