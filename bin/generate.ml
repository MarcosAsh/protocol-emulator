open! Core
open! Hardcaml
open! Protocol_emulator

let print_rtl ~name create_circuit =
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit = create_circuit ~name scope in
  let rtl = Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ] in
  print_endline (Rtl.full_hierarchy rtl |> Rope.to_string)
;;

let memory =
  [%map_open.Command
    let sram = flag "-sram" no_arg ~doc:" use the IHP SRAM macro for program memory" in
    if sram then Engine.Memory.Ihp_sram else Flops]
;;

let engines =
  Command.Param.(
    flag "-engines" (optional_with_default 1 int) ~doc:"N cores, each with its own memory")
;;

let engine_rtl_command =
  Command.basic
    ~summary:"Verilog for the core"
    [%map_open.Command
      let memory = memory in
      fun () ->
        let module C = Circuit.With_interface (Engine.I) (Engine.O) in
        print_rtl ~name:"engine_top" (fun ~name scope ->
          C.create_exn ~name (Engine.hierarchical ~memory scope))]
;;

let top_rtl_command =
  Command.basic
    ~summary:"Verilog for the tiny tapeout top"
    [%map_open.Command
      let memory = memory
      and engines = engines in
      fun () ->
        let module C = Circuit.With_interface (Top.I) (Top.O) in
        print_rtl ~name:"protocol_emulator" (fun ~name scope ->
          C.create_exn ~name (Top.hierarchical ~memory ~engines scope))]
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
