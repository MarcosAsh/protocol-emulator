(** Reads a Verilog module through Yosys ([read_verilog], [chparam], [hierarchy], [proc],
    [flatten]) and hardcaml_of_verilog into a circuit for [Frame_compiler]. A cell
    hardcaml_of_verilog has no model for, or that is outside the subset (memories,
    latches), is refused with its line before conversion.

    Ports not given are found by name and width: the pin is the one 1-bit output, the
    reset the input named like rst, reset or clear (active low when it ends in n or l),
    valid the one other 1-bit input that is not the clock, data the one wider input. *)

open! Core
open! Hardcaml
open Protocol_emulator

module Names : sig
  type t =
    { pin : string option
    ; valid : string option
    ; data : string option
    ; reset : string option
    ; active_low : bool option
    ; tied : (string * int) list (** Inputs held at a constant. *)
    }

  val none : t
end

type t =
  { files : string list
  ; top : string
  ; parameters : (string * string) list
  ; sim : Bit_sim.t
  ; ports : Frame_compiler.Ports.t
  ; clock : string
  ; others : string list (** Inputs left unknown, and outputs not modelled. *)
  ; register_name : Signal.t -> string option
  (** A register's net name as Yosys gives it after the same passes. *)
  }

val read
  :  files:string list
  -> top:string
  -> parameters:(string * string) list
  -> Names.t
  -> t Or_error.t
