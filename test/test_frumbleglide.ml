open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Frumbleglide.firmware));
  [%expect {| |}]
;;

(* The line, level by level with the cycles each lasted, for one host word: what to hold
   against the spec's timing diagram. TODO a model of the far end, fed the pins every
   cycle, that reads back what the host sent. *)
let%expect_test "the line for one host word" =
  let machine =
    Machine.create
      ~config:(Timed_program.config Frumbleglide.firmware)
      ~program:(Timed_program.words Frumbleglide.firmware)
    |> ok_exn
  in
  let machine = Machine.write_tx machine 0x55 |> ok_exn in
  let levels =
    List.folding_map (List.range 0 400) ~init:machine ~f:(fun machine _ ->
      let machine = Machine.step machine ~inputs:0 in
      machine, (machine.pin_out lsr Frumbleglide.pin) land 1 = 1)
  in
  let runs =
    List.group levels ~break:Bool.( <> )
    |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
  in
  print_s [%message (runs : (bool * int) list)];
  [%expect {| |}]
;;
