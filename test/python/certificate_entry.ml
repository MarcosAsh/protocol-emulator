open! Core
open Protocol_emulator
open Protocol_emulator_test

let print (assumptions : System_lockstep.Assumptions.t) ~config words =
  let certificate = System_lockstep.Assumptions.certificate assumptions ~config words in
  print_string "    \"certificate\": [\n";
  List.chunks_of certificate ~length:8
  |> List.iter ~f:(fun chunk ->
    printf
      "        %s,\n"
      (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))));
  printf
    "    ],\n    \"loaded\": %s,\n    \"floor\": %d,\n    \"single_edge\": %d,\n"
    (Option.value_map
       (System_lockstep.Assumptions.loaded assumptions)
       ~default:"None"
       ~f:Int.to_string)
    (Bool.to_int (Option.is_some assumptions.period_floor))
    (Bool.to_int assumptions.single_capture_edge)
;;

let print_timed timed =
  print
    (System_lockstep.Assumptions.of_timed timed)
    ~config:(Timed_program.config timed)
    (Timed_program.words timed)
;;
