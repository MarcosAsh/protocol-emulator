open! Core
open Playground_checks

(* each example's report as table_agree.js prints the page's *)
let () =
  List.iter Table_example.all ~f:(fun (name, _, table) ->
    List.iter [ 48_000_000; 50_000_000 ] ~f:(fun clock_hz ->
      printf
        "== %s at %d Hz\n%s"
        name
        clock_hz
        (Timing_table.to_string (Timing_table.run ~clock_hz table))))
;;
