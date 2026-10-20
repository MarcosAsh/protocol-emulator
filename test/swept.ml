open! Core
open Protocol_emulator

let wire = Isa.num_pins

type t =
  { name : string
  ; watch : string
  ; on_wire : Program_config.t -> Program_config.t
  ; period : int option
  ; bursts : int list list
  }

let line (c : Program_config.t) = { c with out_base = wire; set_base = wire }
let bytes text = String.to_list text |> List.map ~f:(fun c -> [ Char.to_int c ])
