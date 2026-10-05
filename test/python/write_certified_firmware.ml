open! Core
open Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* The DShot600, SENT and CEC firmware for the board's Python and the cocotb tests, each
   checked under its [Certified] entry's assumptions, as the command line does. *)
let () =
  print_string
    "# Written by test/python/write_certified_firmware.ml; `dune promote` after a change.\n\
     # Firmware of test/certified.ml as words and the configuration it runs under.\n";
  List.iter [ "dshot600"; "sent"; "cec" ] ~f:(fun name ->
    let { Certified.source; config; period; period_floor; single_capture_edge; _ } =
      Certified.find_exn name
    in
    let program = Asm.assemble source |> ok_exn in
    let config = Asm.Program.configure program config in
    let (_ : Analyser.Verdict.t) =
      Analyser.check ?period ~single_capture_edge ~config program |> ok_exn
    in
    let words = Asm.Program.words program |> ok_exn in
    (* the kernel's load, the floor where there is one, as the chip checks under *)
    let loaded = Option.first_some period_floor period in
    let certificate =
      Load_check.of_program
        ?period:(if Option.is_some period_floor then None else period)
        ?period_floor
        ~single_capture_edge
        ~config
        words
      |> ok_exn
      |> Load_check.to_words
    in
    let fields =
      Engine.Config.map2
        Engine.Config.port_names
        (Engine.Config.of_program_config config)
        ~f:(fun name value -> name, Bits.to_unsigned_int value)
      |> Engine.Config.to_list
    in
    printf "\n%s = {\n    \"config\": {\n" (String.uppercase name);
    List.iter fields ~f:(fun (field, value) -> printf "        \"%s\": %d,\n" field value);
    print_string "    },\n    \"words\": [\n";
    List.chunks_of words ~length:8
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
      "    ],\n    \"loaded\": %s,\n    \"single_edge\": %d,\n}\n"
      (Option.value_map loaded ~default:"None" ~f:Int.to_string)
      (Bool.to_int single_capture_edge))
;;
