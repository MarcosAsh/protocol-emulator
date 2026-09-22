open! Core
open Protocol_emulator
open Protocol_emulator_test

(* The 10BASE-T firmware's words for the board's Python, checked as the command line
   checks them, under the link interval the board uses. *)
let () =
  let program = Asm.assemble Ethernet.firmware |> ok_exn in
  let (_ : Analyser.Verdict.t) =
    Analyser.check ~period:Ethernet.link_tenth ~config:Ethernet.config program |> ok_exn
  in
  let words = Asm.Program.words program |> ok_exn in
  print_string
    "# Written by test/python/write_ethernet_firmware.ml; `dune promote` after a change.\n\
     # The 10BASE-T firmware of test/ethernet.ml, for python/ethernet.py.\n\n\
     WORDS = [\n";
  List.chunks_of words ~length:8
  |> List.iter ~f:(fun chunk ->
    printf "    %s,\n" (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))));
  print_string "]\n"
;;
