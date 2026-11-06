(** What a host does over SPI before starting an engine: with every engine halted, it
    writes the selected engine's certificate to the data memory, sets the check's
    registers and waits for the verdict. *)

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
