open! Core
open Protocol_emulator

let assemble source = Asm.assemble source |> ok_exn |> Asm.Program.words |> ok_exn

(* Every pin wait releases a fixed number of cycles after its edge, so stamp differences
   are edge differences. *)
let edge_logger ~pin =
  [%string
    {|
    jmp pin, high
low:
    wait 1 pin %{pin#Int}
    mov x, now
    in x, 16
high:
    wait 0 pin %{pin#Int}
    mov x, now
    in x, 16
    jmp low
|}]
;;

let edge_logger_config ~pin =
  { Program_config.default with jmp_pin = pin; autopush = true; push_threshold = 16 }
;;
