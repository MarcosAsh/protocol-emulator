(** Reads a Verilog module through Yosys and hardcaml_of_verilog into a circuit for
    [Frame_compiler]. A cell with no hardcaml_of_verilog model, or outside the subset
    (memories, latches), is refused. Ports not given are found by name and width: the one
    1-bit output is the pin, the input named like rst, reset or clear the reset (active
    low if ending n or l), the other 1-bit input valid, the wide one data. *)

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
