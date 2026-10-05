open! Core
open Protocol_emulator
open Protocol_emulator_test

(* The 10BASE-T firmware for the board's Python, checked at the board's link interval when
   it compiled. *)
let () =
  let words = Timed_program.words Ethernet.firmware in
  let certificate =
    Load_check.of_table
      ~config:(Timed_program.config Ethernet.firmware)
      ~words
      (Kernel.Table.of_analyser (Timed_program.rows Ethernet.firmware))
    |> ok_exn
    |> Load_check.to_words
  in
  print_string
    "# Written by test/python/write_ethernet_firmware.ml; `dune promote` after a change.\n\
     # The 10BASE-T firmware of test/ethernet.ml, for python/ethernet.py.\n\n\
     WORDS = [\n";
  List.chunks_of words ~length:8
  |> List.iter ~f:(fun chunk ->
    printf "    %s,\n" (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))));
  print_string "]\n\n# what the chip checks it against at load, the link interval loaded\nCERTIFICATE = [\n";
  List.chunks_of certificate ~length:8
  |> List.iter ~f:(fun chunk ->
    printf "    %s,\n" (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))));
  printf "]\n\nLOADED = %d\n" Ethernet.link_tenth
;;
