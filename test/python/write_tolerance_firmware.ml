open! Core
open Hardcaml
open Protocol_emulator
open Protocol_emulator_test
module Bench = Tolerance.Bench

let entry name timed =
  let fields =
    Engine.Config.map2
      Engine.Config.port_names
      (Engine.Config.of_program_config (Timed_program.config timed))
      ~f:(fun name value -> name, Bits.to_unsigned_int value)
    |> Engine.Config.to_list
  in
  printf "\n%s = {\n    \"config\": {\n" name;
  List.iter fields ~f:(fun (field, value) -> printf "        \"%s\": %d,\n" field value);
  print_string "    },\n    \"words\": [\n";
  List.chunks_of (Timed_program.words timed) ~length:8
  |> List.iter ~f:(fun chunk ->
    printf
      "        %s,\n"
      (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))));
  print_string "    ],\n}\n"
;;

let () =
  let bounds = Tolerance.bounds Bench.receiver in
  let steps = Bench.steps () in
  let whole m = m / Tolerance.unit in
  (* the sender passes the kernel at every load and fraction the steps take *)
  List.iter steps ~f:(fun (m, _) ->
    let (_ : Timed_program.t) =
      Timed_program.of_source_exn
        ~period:(whole m)
        ~config:{ Bench.sender_config with period_fraction = m % Tolerance.unit }
        Bench.sender
    in
    ());
  print_string
    "# Written by test/python/write_tolerance_firmware.ml; `dune promote` after a change.\n\
     # The tolerance sweep (test/tolerance.ml): engine 1 sends BYTES back to back from one\n\
     # anchor at m 2^-16 cycles a bit, the whole cycles as its first host word and the \
     rest\n\
     # as its period fraction, to engine 0's uart_rx_host_rate on a wire, at 9600 baud \
     from\n\
     # 48 MHz. LEAST and MOST are the bounds the receiver's certificate gives, which\n\
     # formal/tolerance.sby proves on the RTL at short half periods; STEPS pairs each m\n\
     # with what the model predicts. Both firmwares pass the kernel at every step.\n";
  entry
    "SENDER"
    (Timed_program.of_source_exn
       ~period:(2 * Bench.half)
       ~config:Bench.sender_config
       Bench.sender);
  entry
    "RECEIVER"
    (Timed_program.of_source_exn
       ~period:Bench.half
       ~single_capture_edge:true
       ~config:Bench.receiver_config
       Bench.receiver_source);
  printf "\nHALF = %d\nUNIT = %d\n" Bench.half Tolerance.unit;
  printf "LEAST = %d\nMOST = %d\n" bounds.least bounds.most;
  printf
    "BYTES = [%s]\n"
    (String.concat ~sep:", " (List.map Bench.bytes ~f:Int.to_string));
  print_string "\nSTEPS = [\n";
  List.iter steps ~f:(fun (m, ok) ->
    printf "    (%d, %s),\n" m (if ok then "True" else "False"));
  print_string "]\n"
;;
