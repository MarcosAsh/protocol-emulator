open! Core
open! Hardcaml
open! Protocol_emulator

let generate_engine_rtl () =
  let module C = Circuit.With_interface (Engine.I) (Engine.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit = C.create_exn ~name:"engine_top" (Engine.hierarchical scope) in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  print_endline (Rtl.full_hierarchy rtl_circuits |> Rope.to_string)
;;

let engine_rtl_command =
  Command.basic
    ~summary:"Verilog for the core with a flop program memory"
    [%map_open.Command
      let () = return () in
      fun () -> generate_engine_rtl ()]
;;

let () = Command_unix.run (Command.group ~summary:"" [ "engine", engine_rtl_command ])
