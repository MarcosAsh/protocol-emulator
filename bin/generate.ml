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

let generate_top_rtl ~memory =
  let module C = Circuit.With_interface (Top.I) (Top.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit = C.create_exn ~name:"protocol_emulator" (Top.hierarchical ~memory scope) in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  print_endline (Rtl.full_hierarchy rtl_circuits |> Rope.to_string)
;;

let top_rtl_command =
  Command.basic
    ~summary:"Verilog for the tiny tapeout top"
    [%map_open.Command
      let sram = flag "-sram" no_arg ~doc:" use the IHP SRAM macro for program memory" in
      fun () -> generate_top_rtl ~memory:(if sram then Ihp_sram else Flops)]
;;

let assemble_command =
  Command.basic
    ~summary:"Assemble a source file and print the words in hex"
    [%map_open.Command
      let file = anon ("FILE" %: string) in
      fun () ->
        In_channel.read_all file
        |> Asm.assemble
        |> Or_error.bind ~f:Asm.Program.words
        |> ok_exn
        |> List.iter ~f:(printf "%04x\n")]
;;

let () =
  Command_unix.run
    (Command.group
       ~summary:""
       [ "engine", engine_rtl_command
       ; "top", top_rtl_command
       ; "assemble", assemble_command
       ])
;;
