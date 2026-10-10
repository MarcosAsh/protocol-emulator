open! Core
open Protocol_emulator
open Protocol_emulator_test

(* The kernel's verdict on each CAN firmware the bench loads, with the words it loads, and
   its refusal one cycle under each assumption, so the line it drew is printed too. *)

let print_check what result =
  match (result : (Timed_program.t, Timed_program.Refusal.t) Result.t) with
  | Ok timed ->
    printf
      "%s: accepted, %s\n"
      what
      (Analyser.Verdict.to_string (Timed_program.verdict timed))
  | Error { faults; _ } ->
    print_s [%message (what ^ ": refused") (faults : Timed_program.Fault.t list)]
;;

let () =
  List.iter [ "can"; "can_sender"; "can_receiver" ] ~f:(fun name ->
    let bench = Library.find_bench_exn name in
    let timed = Bench.timed bench in
    printf "\n%s: %s\n" name bench.what;
    printf
      "words: %s\n"
      (String.concat ~sep:" " (List.map (Timed_program.words timed) ~f:(sprintf "%04X")));
    let config = bench.config in
    match bench.assumption with
    | Floor floor ->
      print_check
        (sprintf "every period from %d" floor)
        (Timed_program.check ~period_floor:floor ~config bench.source);
      print_check
        (sprintf "every period from %d" (floor - 1))
        (Timed_program.check ~period_floor:(floor - 1) ~config bench.source)
    | Receiver period ->
      print_check
        (sprintf "period %d, one edge before the capture" period)
        (Timed_program.check ~period ~single_capture_edge:true ~config bench.source);
      let shortest = Can_node.Receiver.shortest_period in
      List.iter
        [ shortest; shortest - 1 ]
        ~f:(fun period ->
          print_check
            (sprintf "period %d, sampled at %d" period (3 * period / 4))
            (Can_node.Receiver.check ~period ~sample:(3 * period / 4)))
    | Nothing | Period _ -> raise_s [%message "BUG: no CAN firmware is checked so" name])
;;
