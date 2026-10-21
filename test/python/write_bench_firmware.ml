open! Core
open Hardcaml
open Protocol_emulator
open Protocol_emulator_test

let () =
  print_string
    "# Written by test/python/write_bench_firmware.ml; `dune promote` after a change.\n\
     # The outside chip acts' firmware (BRINGUP.md) as words and the configuration it runs\n\
     # under, at the bench's 48 MHz but for 10BASE-T's 40.\n";
  (* the keyboard's log is not written here, but held to its limits all the same *)
  Datasheet.check_exn Library.limits ~exempt:Library.exempt Uart.log;
  List.iter Library.bench ~f:(fun (bench : Bench.t) ->
    Datasheet.check_exn Library.limits ~exempt:Library.exempt bench;
    let timed = Bench.timed bench in
    (* the premises the chip's checker takes with the certificate *)
    let loaded, floor, single_edge =
      match bench.assumption with
      | Nothing -> None, false, false
      | Floor period -> Some period, true, false
      | Period period -> Some period, false, false
      | Receiver period -> Some period, false, true
    in
    let certificate =
      Load_check.of_table
        ~config:(Timed_program.config timed)
        ~words:(Timed_program.words timed)
        (Kernel.Table.of_analyser (Timed_program.rows timed))
      |> ok_exn
      |> Load_check.to_words
    in
    let fields =
      Engine.Config.map2
        Engine.Config.port_names
        (Engine.Config.of_program_config (Timed_program.config timed))
        ~f:(fun name value -> name, Bits.to_unsigned_int value)
      |> Engine.Config.to_list
    in
    printf "\n# %s\n%s = {\n    \"config\": {\n" bench.what (String.uppercase bench.name);
    List.iter fields ~f:(fun (field, value) -> printf "        \"%s\": %d,\n" field value);
    print_string "    },\n    \"words\": [\n";
    List.chunks_of (Timed_program.words timed) ~length:8
    |> List.iter ~f:(fun chunk ->
      printf
        "        %s,\n"
        (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))));
    print_string "    ],\n    \"certificate\": [\n";
    List.chunks_of certificate ~length:8
    |> List.iter ~f:(fun chunk ->
      printf
        "        %s,\n"
        (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))));
    printf
      "    ],\n    \"loaded\": %s,\n    \"floor\": %d,\n    \"single_edge\": %d,\n}\n"
      (Option.value_map loaded ~default:"None" ~f:Int.to_string)
      (Bool.to_int floor)
      (Bool.to_int single_edge))
;;
