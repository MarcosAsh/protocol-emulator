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
      let memory = memory
      and timer_bits =
        flag
          "-timer-bits"
          (optional int)
          ~doc:
            "N the core alone, its timer N bits wide, so a bounded proof reaches the wrap"
      in
      fun () ->
        match timer_bits with
        | None ->
          let module C = Circuit.With_interface (Solo.I) (Solo.O) in
          print_rtl ~name:"engine_top" (fun ~name scope ->
            C.create_exn ~name (Solo.hierarchical ~memory scope))
        | Some timer_bits ->
          let module Narrow =
            Engine.Make (struct
              let timer_bits = timer_bits
            end)
          in
          let module C = Circuit.With_interface (Engine.I) (Narrow.O) in
          print_rtl ~name:"engine_top" (fun ~name scope ->
            C.create_exn ~name (Narrow.hierarchical ~memory scope))]
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

let provenance_command =
  Command.basic
    ~summary:"The src line each Verilog name of the tiny tapeout top came from, as JSON"
    ~readme:(fun () ->
      "Takes the same flags as top and gives the names it prints. A name with no src \
       line is null.")
    [%map_open.Command
      let memory = memory
      and engines = engines in
      fun () ->
        let module C = Circuit.With_interface (Top.I) (Top.O) in
        Provenance.traced (fun () ->
          let scope = Scope.create ~auto_label_hierarchical_ports:true () in
          let circuit =
            C.create_exn
              ~name:"protocol_emulator"
              (Top.hierarchical ~memory ~engines scope)
          in
          Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ])
        |> Provenance.of_rtl
        |> Provenance.to_json
        |> print_string]
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
      let timer_bits =
        flag
          "-timer-bits"
          (optional_with_default Isa.timer_bits int)
          ~doc:"N for a core whose timer is N bits wide, as engine -timer-bits"
      in
      fun () ->
        let module Kernel =
          Kernel.Make_timer (struct
            let timer_bits = timer_bits
          end)
        in
        let module C = Circuit.With_interface (Kernel.I) (Kernel.O) in
        print_rtl ~name:"kernel_step_top" (fun ~name scope ->
          C.create_exn ~name (Kernel.hierarchical scope))]
;;

(* The same wiring as [Kernel.hierarchical] and [Kernel.Accepts.hierarchical], over gates. *)
let kernel_gates_command =
  Command.basic
    ~summary:
      "The kernel's step, or its check of a row, as the gates its SAT proofs build, \
       which formal/kernel_equiv proves equal to the Verilog"
    [%map_open.Command
      let accepts =
        flag "-accepts" no_arg ~doc:" the kernel's check of a row, as kernel-accepts"
      in
      fun () ->
        let module A = Aig.Make () in
        let module K = Kernel.Make (A) in
        let outputs =
          if accepts
          then
            let module Accepts = Kernel.Accepts in
            let module Row = Kernel.Row.Make_comb (A) in
            let i =
              Accepts.I.map2 Accepts.I.port_names Accepts.I.port_widths ~f:A.input
            in
            let row = Row.unpack ~rev:true i.row in
            let next_pc, target_pc =
              K.successors
                ~wrap_top:i.wrap_top
                ~wrap_bottom:i.wrap_bottom
                ~pc:i.pc
                ~word:i.word
            in
            { Accepts.O.next_pc
            ; target_pc
            ; accepts =
                K.accepts
                  ~side_set_count:i.side_set_count
                  ~fraction:i.fraction
                  ~loaded:i.loaded
                  ~capture:i.capture
                  ~spacing:i.spacing
                  ~word:i.word
                  ~row
                  ~next:(Row.unpack ~rev:true i.next)
                  ~target:(Row.unpack ~rev:true i.target)
            ; within =
                K.within
                  row
                  ~spacing:i.spacing
                  ~phase:i.phase
                  ~offset:i.offset
                  ~period:i.period
                  ~x:i.x
                  ~y:i.y
                  ~arm:i.arm
                  ~arm_known:i.arm_known
                  ~captured:i.captured
                  ~awaiting:i.awaiting
                  ~a:i.a
                  ~b:i.b
                |> Kernel.Holds.to_list
                |> A.reduce ~f:A.( &: )
            ; starts_open = K.starts_open row ~spacing:i.spacing
            }
            |> Accepts.O.zip Accepts.O.port_names
            |> Accepts.O.to_list
          else (
            let i = Kernel.I.map2 Kernel.I.port_names Kernel.I.port_widths ~f:A.input in
            K.step
              ~side_set_count:i.side_set_count
              ~fraction:i.fraction
              ~loaded:i.loaded
              ~capture:i.capture
              ~spacing:i.spacing
              ~word:i.word
              ~phase:i.phase
              ~period:i.period
              ~x:i.x
              ~y:i.y
              ~arm:i.arm
              ~arm_known:i.arm_known
              ~captured:i.captured
              ~awaiting:i.awaiting
              ~a:i.a
              ~b:i.b
              ~data_a:i.data_a
              ~data_b:i.data_b
            |> Kernel.O.zip Kernel.O.port_names
            |> Kernel.O.to_list)
        in
        print_string (A.to_aiger outputs)]
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

(* [FIELD=VALUE] over the record's sexp, so every field goes by its own name *)
let config_field =
  Command.Arg_type.create (fun text ->
    match String.lsplit2 text ~on:'=' with
    | Some (field, value) -> field, Sexp.of_string value
    | None -> raise_s [%message "expected FIELD=VALUE" (text : string)])
;;

let set_fields config fields =
  match Program_config.sexp_of_t config with
  | Atom _ as sexp -> raise_s [%message "BUG: config is not a record" (sexp : Sexp.t)]
  | List pairs ->
    let field_of = function
      | Sexp.List [ Atom field; _ ] -> Some field
      | _ -> None
    in
    List.iter fields ~f:(fun (field, _) ->
      if not (List.mem (List.filter_map pairs ~f:field_of) field ~equal:String.equal)
      then raise_s [%message "no such field of the configuration" (field : string)]);
    List
      (List.map pairs ~f:(fun pair ->
         match field_of pair with
         | None -> pair
         | Some field ->
           List.Assoc.find fields field ~equal:String.equal
           |> Option.value_map ~default:pair ~f:(fun value ->
             Sexp.List [ Atom field; value ])))
    |> Program_config.t_of_sexp
;;

(* The capture pin and autopull belong to the configuration, which the host loads and a
   source file does not carry. *)
let program_config =
  [%map_open.Command
    let fields =
      flag
        "-config"
        (optional_with_default [] (Arg_type.comma_separated config_field))
        ~doc:"FIELD=VALUE,... any field of the configuration, over the other flags"
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
    in
    set_fields
      { Program_config.default with
        capture_pin
      ; capture_rising = not capture_falling
      ; autopull = Option.is_some autopull_data
      ; autopull_data = Option.is_some autopull_data
      ; pull_threshold =
          Option.value autopull_data ~default:Program_config.default.pull_threshold
      }
      fields]
;;

(* The assumptions are the analyser's, under its names. Gives the analyser's rows under
   them, checked unless [-no-timing-check], the verdicts going to [verdicts]. *)
let timing_check =
  [%map_open.Command
    let period =
      flag
        "-period"
        (optional int)
        ~doc:"N cycles every run-time load of p is assumed to carry"
    and period_floor =
      flag
        "-period-floor"
        (optional int)
        ~doc:"N the least cycles every run-time load of p is assumed to carry"
    and single_capture_edge =
      flag
        "-single-capture-edge"
        no_arg
        ~doc:" assume the capture pin makes one edge from capture_arm to the wait for it"
    and no_timing_check =
      flag "-no-timing-check" no_arg ~doc:" assemble firmware that may miss a deadline"
    in
    fun ?(verdicts = Out_channel.stderr) ~config ~source (program : Asm.Program.t) ->
      if no_timing_check
      then
        Ok
          (Analyser.analyse
             ?period
             ?period_floor
             ~single_capture_edge
             ~config:(Asm.Program.configure program config)
             program.instructions)
      else (
        let print_verdict verdict =
          fprintf verdicts "%s\n" (Analyser.Verdict.to_string verdict)
        in
        match
          Timed_program.check ?period ?period_floor ~single_capture_edge ~config source
        with
        | Ok timed ->
          print_verdict (Timed_program.verdict timed);
          fprintf
            verdicts
            "kernel: accepted, so no deadline is missed by the step lemma\n";
          Ok (Timed_program.rows timed)
        | Error { faults = _; verdict; error } ->
          Option.iter verdict ~f:print_verdict;
          Error error)]
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
      and config = program_config
      and timing_check = timing_check
      and listing =
        flag
          "-listing"
          no_arg
          ~doc:" print each word with its address and the instruction"
      and print_rows =
        flag
          "-rows"
          no_arg
          ~doc:" print the analyser's rows, each edge's phase to the deadline, not words"
      in
      fun () ->
        let assembled =
          let open Or_error.Let_syntax in
          let source = In_channel.read_all file in
          let%bind program = Asm.assemble source in
          let%bind rows = timing_check ~config ~source program in
          let%map words = Asm.Program.words program in
          program, words, rows
        in
        match assembled with
        | Ok (program, _, rows) when print_rows ->
          print_endline (Analyser.to_string ~side_set_count:program.side_set_count rows)
        | Ok (program, words, _) ->
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

let run_command =
  Command.basic
    ~summary:"Run a source file on the model of the core and print its pins"
    ~readme:(fun () ->
      "Checks the firmware as assemble does, then runs it anyway. Inputs are low until \
       set, and the host writes the tx words as the fifo has room. Exits 1 if the \
       firmware was refused or the model set a fault.")
    [%map_open.Command
      let file = anon ("FILE" %: string)
      and config = program_config
      and timing_check = timing_check
      and cycles =
        flag
          "-cycles"
          (optional_with_default
             1000
             (Arg_type.map int ~f:(fun cycles ->
                if cycles <= 0 then raise_s [%message "not positive" (cycles : int)];
                cycles)))
          ~doc:"N steps of the model (default 1000)"
      and tx =
        flag
          "-tx"
          (listed (Arg_type.comma_separated (Arg_type.create Machine_trace.Tx.of_string)))
          ~doc:"WORD[@CYCLE],... words the host writes into the tx fifo, in order"
      and inputs =
        flag
          "-input"
          (listed
             (Arg_type.comma_separated (Arg_type.create Machine_trace.Input.of_string)))
          ~doc:"PIN=LEVEL[@CYCLE],... an input pin's level from that cycle on"
      and data =
        flag
          "-data"
          (optional_with_default [] (Arg_type.comma_separated int))
          ~doc:"WORD,... the data memory from address 0"
      and vcd = flag "-vcd" (optional string) ~doc:"FILE write the pins there as a VCD" in
      fun () ->
        let source = In_channel.read_all file in
        let machine =
          let open Or_error.Let_syntax in
          let%bind program = Asm.assemble source in
          let checked =
            timing_check ~verdicts:Out_channel.stdout ~config ~source program
          in
          let%bind words = Asm.Program.words program in
          let%bind machine =
            Machine.create ~config:(Asm.Program.configure program config) ~program:words
          in
          let%map machine = Machine.load_data machine data in
          checked, machine
        in
        match machine with
        | Error e ->
          eprintf "%s: %s\n" file (Error.to_string_hum e);
          exit 1
        | Ok (checked, machine) ->
          Result.iter_error checked ~f:(fun e ->
            printf "%s: %s\n" file (Error.to_string_hum e));
          let trace =
            Machine_trace.run
              machine
              ~cycles
              ~tx:(List.concat tx)
              ~inputs:(List.concat inputs)
          in
          printf "\n%s" (Machine_trace.to_string trace);
          Option.iter vcd ~f:(fun vcd ->
            Out_channel.write_all vcd ~data:(Machine_trace.to_vcd trace));
          if Result.is_error checked || Machine_trace.faulted trace then exit 1]
;;

let self_check_command =
  Command.basic
    ~summary:"Print the rows a checker checks a firmware's frames against, in hex"
    ~readme:(fun () ->
      "The frame runs from the pin write at -first to the one at -last; the words go \
       into the data memory from -base, for the engine that runs Self_check.checker with \
       the same base.")
    [%map_open.Command
      let file = anon ("FILE" %: string)
      and period =
        flag
          "-period"
          (optional int)
          ~doc:"N cycles every run-time load of p is assumed to carry"
      and first = flag "-first" (required int) ~doc:"PC the frame's first pin write"
      and last = flag "-last" (required int) ~doc:"PC the frame's last pin write"
      and base =
        flag
          "-base"
          (optional_with_default 0 int)
          ~doc:"ADDRESS where the rows go in the data memory (default 0)"
      in
      fun () ->
        let rows =
          let open Or_error.Let_syntax in
          let%bind program = In_channel.read_all file |> Asm.assemble in
          let%bind edges =
            Self_check.edges ?period ~config:Program_config.default program ~first ~last
          in
          Self_check.rows ~base edges
        in
        match rows with
        | Ok rows -> List.iter rows ~f:(printf "%04x\n")
        | Error e ->
          eprintf "%s: %s\n" file (Error.to_string_hum e);
          exit 1]
;;

(* What the host loads beside the words, and the window it may check the verdicts against,
   one [name value] per line for the cocotb test to read. *)
let predicate_settings (firmware : Predicate.Firmware.t) =
  (* every field, named as the host's config registers are, so none falls back *)
  let { Program_config.side_set_count
      ; side_set_base
      ; side_set_pindirs
      ; in_base
      ; in_count
      ; out_base
      ; out_count
      ; set_base
      ; set_count
      ; jmp_pin
      ; capture_pin
      ; capture_rising
      ; in_shift
      ; out_shift
      ; autopush
      ; push_threshold
      ; autopull
      ; pull_threshold
      ; crc_width
      ; crc_poly
      ; crc_init
      ; crc_reflect
      ; stuff_threshold
      ; stuff_level
      ; wrap_bottom
      ; wrap_top
      ; period_fraction
      ; autopull_data
      ; manchester
      }
    =
    firmware.config
  in
  let right : Program_config.Shift_direction.t -> bool = function
    | Right -> true
    | Left -> false
  in
  let config =
    List.map
      [ "side_set_pindirs", side_set_pindirs
      ; "capture_rising", capture_rising
      ; "in_shift_right", right in_shift
      ; "out_shift_right", right out_shift
      ; "autopush", autopush
      ; "autopull", autopull
      ; "crc_reflect", crc_reflect
      ; "stuff_level", stuff_level
      ; "autopull_data", autopull_data
      ; "manchester", manchester
      ]
      ~f:(fun (name, flag) -> name, Bool.to_int flag)
    @ [ "side_set_count", side_set_count
      ; "side_set_base", side_set_base
      ; "in_base", in_base
      ; "in_count", in_count
      ; "out_base", out_base
      ; "out_count", out_count
      ; "set_base", set_base
      ; "set_count", set_count
      ; "jmp_pin", jmp_pin
      ; "capture_pin", capture_pin
      ; "push_threshold", push_threshold
      ; "pull_threshold", pull_threshold
      ; "crc_width", crc_width
      ; "crc_poly", crc_poly
      ; "crc_init", crc_init
      ; "stuff_threshold", stuff_threshold
      ; "wrap_bottom", wrap_bottom
      ; "wrap_top", wrap_top
      ; "period_fraction", period_fraction
      ]
  in
  let { Predicate.Certificate.latency; jitter; sampling; _ } = firmware.certificate in
  let sampling =
    match sampling with
    | Waits _ -> []
    | Polls { min_run; unseen_before_verdict } ->
      [ "min_run", min_run; "unseen_before_verdict", unseen_before_verdict ]
  in
  config
  @ [ "latency", latency; "jitter", jitter ]
  @ sampling
  @ Option.value_map firmware.budget_from_host ~default:[] ~f:(fun budget ->
    [ "budget_from_host", budget ])
  |> List.map ~f:(fun (name, value) -> [%string "%{name} %{value#Int}"])
  |> String.concat_lines
;;

let predicate_command =
  Command.basic
    ~summary:"Compile a predicate over pin events to firmware and print its source"
    ~readme:(fun () ->
      "As in \"pin 0 falls while pin 1 is high\" or \"pin 2 stops moving\". The \
       certificate goes to stderr, with the config and host budget it depends on. A \
       latency the code cannot meet is refused with the cycles it is short by.")
    [%map_open.Command
      let text = anon ("PREDICATE" %: string)
      and latency =
        flag "-latency" (required int) ~doc:"N cycles from the event to the verdict"
      and verdict_pin =
        flag "-verdict-pin" (optional int) ~doc:"N the pin that pulses (default OUT0)"
      and settings =
        flag
          "-settings"
          (optional string)
          ~doc:"FILE write the config, host budget and window there, one per line"
      in
      fun () ->
        match
          Or_error.bind
            (Predicate.of_string text)
            ~f:(Predicate.compile ?verdict_pin ~latency)
        with
        | Ok firmware ->
          print_string firmware.source;
          Option.iter settings ~f:(fun file ->
            Out_channel.write_all file ~data:(predicate_settings firmware));
          eprint_s
            [%message
              ""
                ~certificate:(firmware.certificate : Predicate.Certificate.t)
                ~budget_from_host:(firmware.budget_from_host : int option)
                ~config:(firmware.config : Program_config.t)]
        | Error e ->
          eprintf "%s\n" (Error.to_string_hum e);
          exit 1]
;;

let () =
  Command_unix.run
    (Command.group
       ~summary:""
       [ "engine", engine_rtl_command
       ; "engines", engines_rtl_command
       ; "top", top_rtl_command
       ; "provenance", provenance_command
       ; "memory", memory_rtl_command
       ; "kernel", kernel_rtl_command
       ; "kernel-gates", kernel_gates_command
       ; "osr", osr_rtl_command
       ; "kernel-accepts", kernel_accepts_rtl_command
       ; "assemble", assemble_command
       ; "run", run_command
       ; "self-check", self_check_command
       ; "predicate", predicate_command
       ])
;;
