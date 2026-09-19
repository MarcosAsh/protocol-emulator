open! Core
open! Hardcaml
open! Protocol_emulator

let generate_engine_rtl ~memory =
  let module C = Circuit.With_interface (Engine.I) (Engine.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit = C.create_exn ~name:"engine_top" (Engine.hierarchical ~memory scope) in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  print_endline (Rtl.full_hierarchy rtl_circuits |> Rope.to_string)
;;

let engine_rtl_command =
  Command.basic
    ~summary:"Verilog for the core"
    [%map_open.Command
      let sram = flag "-sram" no_arg ~doc:" use the IHP SRAM macro for program memory" in
      fun () -> generate_engine_rtl ~memory:(if sram then Ihp_sram else Flops)]
;;

let () = Command_unix.run (Command.group ~summary:"" [ "engine", engine_rtl_command ])
