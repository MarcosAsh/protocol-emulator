open! Core
open Protocol_emulator_test

(* A bench copy's datasheet limits measured on a capture's edges, as demo/edges.py writes
   them, from stdin. Exits 1 if one fails. Every level on the line counts, the far end's
   too, so the capture should be of the copy's own run, its [Bench.stimulus]: a host's
   inhibit or the idle between bursts reads as a long low or high. *)
let () =
  match Sys.get_argv () with
  | [| _; name |] ->
    let bench = Library.find_bench_exn name in
    let capture =
      Measured_limits.Capture.of_string (In_channel.input_all In_channel.stdin)
    in
    let measured = Measured_limits.measure Library.limits bench capture in
    if List.is_empty measured then raise_s [%message "no datasheet limits name" name];
    print_endline (Measured_limits.to_string capture measured);
    if List.exists measured ~f:(fun t -> Measured_limits.Verdict.equal t.verdict Fail)
    then exit 1
  | _ ->
    eprintf "usage: python3 demo/edges.py CAPTURE PIN=Dn... | measure.exe FIRMWARE\n";
    exit 2
;;
