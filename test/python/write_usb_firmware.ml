open! Core
open Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* The USB device firmware for the board's Python: the words for address 0, where the
   words that depend on the address sit, and those words for every address, so the Python
   never has to assemble anything or know how the constants are built. *)
let bit_period = 32
let addresses = 128

let () =
  let program address =
    Firmware.assemble (Firmware.usb_device ~address ~half_period:(bit_period / 2))
    |> Array.of_list
  in
  let programs = Array.init addresses ~f:program in
  let base = programs.(0) in
  let patch_at =
    List.filter
      (List.range 0 (Array.length base))
      ~f:(fun i -> Array.exists programs ~f:(fun p -> p.(i) <> base.(i)))
  in
  let config =
    Engine.Config.map2
      Engine.Config.port_names
      (Engine.Config.of_program_config Firmware.usb_device_config)
      ~f:(fun name value -> name, Bits.to_unsigned_int value)
    |> Engine.Config.to_list
  in
  let hex words = List.map words ~f:(sprintf "0x%04x") |> String.concat ~sep:", " in
  let lines words = List.chunks_of words ~length:10 |> List.map ~f:hex in
  print_endline
    "# Written by test/python/write_usb_firmware.ml; `dune promote` after a change.";
  print_endline
    "# Firmware.usb_device for every address, as the words that differ from address 0.";
  printf "\nBIT_PERIOD = %d\n\nCONFIG = {\n" bit_period;
  List.iter config ~f:(fun (name, value) -> printf "    \"%s\": %d,\n" name value);
  print_endline "}\n\nWORDS = [";
  List.iter (lines (Array.to_list base)) ~f:(printf "    %s,\n");
  printf
    "]\n\nPATCH_AT = [%s]\n\nPATCHES = [\n"
    (List.map patch_at ~f:Int.to_string |> String.concat ~sep:", ");
  Array.iter programs ~f:(fun p ->
    printf "    [%s],\n" (hex (List.map patch_at ~f:(fun i -> p.(i)))));
  print_endline "]\n\n";
  print_endline "def words(address):";
  print_endline "    \"\"\"The program for a device at this address.\"\"\"";
  print_endline "    program = list(WORDS)";
  print_endline "    for at, word in zip(PATCH_AT, PATCHES[address]):";
  print_endline "        program[at] = word";
  print_endline "    return program"
;;
