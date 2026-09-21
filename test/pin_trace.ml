open! Core
open! Hardcaml
open Protocol_emulator
module Reg = Host_port.Reg

module Line = struct
  type t =
    { ui_in : int
    ; uio_in : int
    ; uo_out : int
    ; uio_out : int
    ; uio_oe : int
    }
  [@@deriving sexp_of, equal]
end

module Peer = struct
  type t =
    { inputs : unit -> int
    ; step : pin_out:int -> pin_dir:int -> unit
    }

  let idle levels =
    { inputs = (fun () -> levels); step = (fun ~pin_out:_ ~pin_dir:_ -> ()) }
  ;;
end

module Step = struct
  type t =
    | Write of int * int list
    | Read of int * int
    | Run of int
    | Drive of
        { pin : int
        ; levels : int list
        }
end

module Scenario = struct
  type t =
    { name : string
    ; peer : unit -> Peer.t
    ; script : Step.t list
    }

  let load ~config ~program =
    let config = Engine.Config.of_program_config config in
    (Engine.Config.to_list (Engine.Config.map config ~f:Bits.to_unsigned_int)
     |> List.mapi ~f:(fun n v -> Step.Write (Reg.config + n, [ v ])))
    @ [ Write (Reg.program_addr, [ 0 ]); Write (Reg.program, program) ]
  ;;

  let start = Step.Write (Reg.control, [ 1 ])
end
