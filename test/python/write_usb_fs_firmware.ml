open! Core
open Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* The full speed device for the board's Python: the program, its configuration, the line
   table and the certificate the chip checks it against, with the places the program reads
   in the data memory, so the Python never assembles. *)
let () =
  let program = Asm.assemble Usb_fs.device |> ok_exn in
  let config = Asm.Program.configure program Usb_fs.config in
  let (_ : Analyser.Verdict.t) = Analyser.check ~config program |> ok_exn in
  let words = Asm.Program.words program |> ok_exn in
  let certificate =
    Load_check.of_program ~config words |> ok_exn |> Load_check.to_words
  in
  let fields =
    Engine.Config.map2
      Engine.Config.port_names
      (Engine.Config.of_program_config config)
      ~f:(fun name value -> name, Bits.to_unsigned_int value)
    |> Engine.Config.to_list
  in
  let hex words = List.map words ~f:(sprintf "0x%04x") |> String.concat ~sep:", " in
  let block name words =
    printf "\n%s = [\n" name;
    List.iter (List.chunks_of words ~length:10) ~f:(fun line ->
      printf "    %s,\n" (hex line));
    print_endline "]"
  in
  print_endline
    "# Written by test/python/write_usb_fs_firmware.ml; `dune promote` after a change.";
  print_endline
    "# Usb_fs.device, the full speed device, and where it reads the data memory.";
  printf "\nDP_PIN = %d\n" Usb_fs.dp_pin;
  printf "RX_BASE = %d\n" Usb_fs.rx_base;
  printf "NAK_RECORD = %d\n" Usb_fs.nak_record;
  printf "ACK_RECORD = %d\n" Usb_fs.ack_record;
  printf "FIRST_RECORD = %d\n" Usb_fs.first_record;
  printf "TURNAROUND = %d\n" Usb_fs.turnaround;
  print_endline "\nCONFIG = {";
  List.iter fields ~f:(fun (name, value) -> printf "    \"%s\": %d,\n" name value);
  print_endline "}";
  block "LINE_TABLE" (Line_code.words Usb_fs.line_table);
  block "WORDS" words;
  block "CERTIFICATE" certificate
;;
