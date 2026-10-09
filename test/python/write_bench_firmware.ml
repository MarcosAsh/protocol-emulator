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
  Datasheet.check_exn Bench.uart_log;
  List.iter Bench.all ~f:(fun bench ->
    Datasheet.check_exn bench;
    let timed = Bench.timed bench in
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
    print_string "    ],\n}\n")
;;
