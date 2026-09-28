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
    flag
      "-engines"
      (optional_with_default 1 int)
      ~doc:"N cores, each with its own program memory")
;;

let engine_rtl_command =
  Command.basic
    ~summary:"Verilog for the core"
    [%map_open.Command
      let memory = memory in
      fun () ->
        let module C = Circuit.With_interface (Solo.I) (Solo.O) in
        print_rtl ~name:"engine_top" (fun ~name scope ->
          C.create_exn ~name (Solo.hierarchical ~memory scope))]
;;

let engines_rtl_command =
  Command.basic
    ~summary:"Verilog for the cores and the pins between them, with no host port"
    [%map_open.Command
      let memory = memory
      and engines = engines in
      fun () ->
        let module Engines =
          Engines.Make (struct
            let engines = engines
          end)
        in
        let module C = Circuit.With_interface (Engines.I) (Engines.O) in
        print_rtl ~name:"engines_top" (fun ~name scope ->
          C.create_exn ~name (Engines.hierarchical ~memory scope))]
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

let memory_rtl_command =
  Command.basic
    ~summary:
      "Verilog for one program memory, which formal/sram_equiv proves the same either way"
    [%map_open.Command
      let memory = memory in
      fun () ->
        let module C = Circuit.With_interface (Program_memory.I) (Program_memory.O) in
        print_rtl ~name:"memory_top" (fun ~name scope ->
          C.create_exn
            ~name
            (match memory with
             | Flops -> Program_memory.hierarchical scope
             | Ihp_sram -> Sram_macro.hierarchical scope))]
;;

let kernel_rtl_command =
  Command.basic
    ~summary:
      "Verilog for the kernel's step, which formal/phase_step.sv proves the core keeps"
    [%map_open.Command
      let () = return () in
      fun () ->
        let module C = Circuit.With_interface (Kernel.I) (Kernel.O) in
        print_rtl ~name:"kernel_step_top" (fun ~name scope ->
          C.create_exn ~name (Kernel.hierarchical scope))]
;;

let osr_rtl_command =
  Command.basic
    ~summary:
      "Verilog for the osr kernel's step, which formal/data_step.sv proves the core keeps"
    [%map_open.Command
      let () = return () in
      fun () ->
        let module C = Circuit.With_interface (Osr_kernel.I) (Osr_kernel.O) in
        print_rtl ~name:"osr_step_top" (fun ~name scope ->
          C.create_exn ~name (Osr_kernel.hierarchical scope))]
;;

let kernel_accepts_rtl_command =
  Command.basic
    ~summary:
      "Verilog for the kernel's check of a row, which formal/phase_step.sv with TABLE \
       proves keeps every deadline"
    [%map_open.Command
      let () = return () in
      fun () ->
        let module C = Circuit.With_interface (Kernel.Accepts.I) (Kernel.Accepts.O) in
        print_rtl ~name:"kernel_accepts_top" (fun ~name scope ->
          C.create_exn ~name (Kernel.Accepts.hierarchical scope))]
;;

(* The assumptions are the analyser's, under its names. The capture pin and autopull
   belong to the configuration, which the host loads and a source file does not carry. *)
let timing_check =
  [%map_open.Command
    let period =
      flag
        "-period"
        (optional int)
        ~doc:"N cycles every run-time load of p is assumed to carry"
    and single_capture_edge =
      flag
        "-single-capture-edge"
        no_arg
        ~doc:" assume the capture pin makes one edge from capture_arm to the wait for it"
    and capture_pin =
      flag
        "-capture-pin"
        (optional_with_default Program_config.default.capture_pin int)
        ~doc:"N the capture pin that assumption is about"
    and capture_falling =
      flag "-capture-falling" no_arg ~doc:" the capture is of a falling edge"
    and autopull_data =
      flag
        "-autopull-data"
        (optional int)
        ~doc:"N every out autopulls from the data memory once N bits are shifted out"
    and no_timing_check =
      flag "-no-timing-check" no_arg ~doc:" assemble firmware that may miss a deadline"
    in
    fun program ->
      if no_timing_check
      then Ok ()
      else (
        let config =
          { Program_config.default with
            capture_pin
          ; capture_rising = not capture_falling
          ; autopull = Option.is_some autopull_data
          ; autopull_data = Option.is_some autopull_data
          ; pull_threshold =
              Option.value autopull_data ~default:Program_config.default.pull_threshold
          }
        in
        let open Or_error.Let_syntax in
        let%bind verdict = Analyser.check ?period ~single_capture_edge ~config program in
        eprintf "%s\n" (Analyser.Verdict.to_string verdict);
        let%bind words = Asm.Program.words program in
        (* The analyser is not trusted: the kernel, which is proved, checks its rows and
           has the last word. It covers less than the analyser, so it can refuse firmware
           the analyser passes. *)
        let config = Asm.Program.configure program config in
        let rows =
          Analyser.analyse ?period ~single_capture_edge ~config program.instructions
        in
        let%map () =
          Kernel.check
            ?period
            ~single_capture_edge
            ~config
            ~words
            (Kernel.Table.of_analyser rows)
        in
        eprintf "kernel: accepted, so no deadline is missed by the step lemma\n")]
;;

let assemble_command =
  Command.basic
    ~summary:"Assemble a source file and print the words in hex"
    ~readme:(fun () ->
      "Firmware that can reach a deadline wait late is refused, with the waits at fault. \
       Firmware the analyser passes is assembled only if the kernel accepts the \
       analyser's rows for it; otherwise it is refused with each pc and the conjuncts \
       that fail there. -no-timing-check turns off both.")
    [%map_open.Command
      let file = anon ("FILE" %: string)
      and timing_check = timing_check
      and listing =
        flag
          "-listing"
          no_arg
          ~doc:" print each word with its address and the instruction"
      in
      fun () ->
        let assembled =
          let open Or_error.Let_syntax in
          let%bind program = In_channel.read_all file |> Asm.assemble in
          let%bind () = timing_check program in
          let%map words = Asm.Program.words program in
          program, words
        in
        match assembled with
        | Ok (program, words) ->
          List.iteri
            (List.zip_exn words program.instructions)
            ~f:(fun address (word, instruction) ->
              if listing
              then
                printf
                  "%3d  %04x  %s\n"
                  address
                  word
                  (Asm.to_string ~side_set_count:program.side_set_count instruction)
              else printf "%04x\n" word)
        | Error e ->
          eprintf "%s: %s\n" file (Error.to_string_hum e);
          exit 1]
;;

let () =
  Command_unix.run
    (Command.group
       ~summary:""
       [ "engine", engine_rtl_command
       ; "engines", engines_rtl_command
       ; "top", top_rtl_command
       ; "memory", memory_rtl_command
       ; "kernel", kernel_rtl_command
       ; "osr", osr_rtl_command
       ; "kernel-accepts", kernel_accepts_rtl_command
       ; "assemble", assemble_command
       ])
;;
