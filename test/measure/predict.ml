open! Core
open Protocol_emulator_test

(* Prints a bench copy's run at its clock, with every edge its datasheet limits bound.
   demo/margins.py holds a bench capture against it. *)
let () =
  match Sys.get_argv () with
  | [| _; name |] ->
    Library.find_bench_exn name
    |> Measured_limits.Prediction.of_bench Library.limits
    |> Measured_limits.Prediction.to_string
    |> print_endline
  | _ ->
    eprintf "usage: predict.exe FIRMWARE\n";
    exit 2
;;
