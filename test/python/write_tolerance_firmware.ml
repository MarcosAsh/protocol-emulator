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
  print_string "    ],\n"
;;

(* the status word's fault bits *)
let status_bits (fault : Machine.Fault.t) =
  List.fold
    [ fault.underflow, 0x4
    ; fault.overflow, 0x8
    ; fault.missed_deadline, 0x10
    ; fault.decode, 0x20
    ; fault.assumption, 0x4000
    ]
    ~init:0
    ~f:(fun bits (set, bit) -> if set then bits lor bit else bits)
;;

let receiver_at ~half =
  Timed_program.of_source_exn
    ~period:half
    ~single_capture_edge:true
    ~config:Bench.receiver_config
    Bench.receiver_source
;;

(* One certificate for every step, under the floor of their periods' whole cycles. The
   rows carry a fraction, which the chip's walk also accepts for steps that have none. *)
let sender_under ~floor ms =
  let config = { Bench.sender_config with period_fraction = 1 } in
  let timed = Timed_program.of_source_exn ~period_floor:floor ~config Bench.sender in
  let assumptions = System_lockstep.Assumptions.of_timed timed in
  let words = Timed_program.words timed in
  let certificate =
    System_lockstep.Assumptions.certificate
      assumptions
      ~config:(Timed_program.config timed)
      words
    |> Array.of_list
  in
  List.iter ms ~f:(fun m ->
    match
      Load_check.walk
        ~loaded:floor
        ~floor:true
        ~config:{ (Timed_program.config timed) with period_fraction = m % Tolerance.unit }
        ~words
        ~memory:(fun at -> if at < Array.length certificate then certificate.(at) else 0)
        ~base:0
        ()
    with
    | Ok (_ : Kernel.Table.t) -> ()
    | Error rejection ->
      raise_s
        [%message
          "BUG: the sender's certificate refused"
            (m : int)
            (rejection : Load_check.Rejection.t)]);
  timed
;;

(* test/test_tolerance_bench.py's shortened bench: its half period, and its fastest step
   at a tenth below the nominal rate *)
let short_half = 26
let short_bytes = [ 0x00; 0x55; 0xA5; 0x7F ]
let short_fastest = 2 * short_half * Tolerance.unit * 9 / 10

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
     # 48 MHz. LEAST and MOST are the bounds the receiver's certificate gives. STEPS\n\
     # pairs each m with what the model predicts, and FAULTS are the steps it predicts\n\
     # fault the receiver, with FAULT its status bits. Both firmwares pass the kernel at\n\
     # every step, and the sender's one certificate, under the floor of the steps' \
     periods,\n\
     # the chip's walk.\n";
  let ms = List.map steps ~f:fst in
  let floor =
    List.fold ms ~init:Int.max_value ~f:(fun least m -> Int.min least (whole m))
  in
  let sender = sender_under ~floor ms in
  entry "SENDER" sender;
  Certificate_entry.print_timed sender;
  print_string "}\n";
  let receiver = receiver_at ~half:Bench.half in
  entry "RECEIVER" receiver;
  Certificate_entry.print_timed receiver;
  print_string "}\n";
  printf "\nHALF = %d\nUNIT = %d\n" Bench.half Tolerance.unit;
  printf "LEAST = %d\nMOST = %d\n" bounds.least bounds.most;
  printf
    "BYTES = [%s]\n"
    (String.concat ~sep:", " (List.map Bench.bytes ~f:Int.to_string));
  print_string "\nSTEPS = [\n";
  List.iter steps ~f:(fun (m, ok) ->
    printf "    (%d, %s),\n" m (if ok then "True" else "False"));
  print_string "]\n";
  let faults = Bench.faults () in
  printf "\nFAULTS = [%s]\n" (String.concat ~sep:", " (List.map faults ~f:Int.to_string));
  let fault =
    List.map faults ~f:(fun m -> status_bits (Tolerance.fault Bench.receiver ~m ~phase:0))
    |> List.dedup_and_sort ~compare
  in
  (match fault with
   | [ fault ] -> printf "FAULT = 0x%X\n" fault
   | _ -> raise_s [%message "BUG: the steps fault differently" (fault : int list)]);
  let short =
    Tolerance.Receiver.uart_rx_host_rate ~bytes:short_bytes ~half:short_half ()
  in
  let short_fast_end = (Tolerance.bounds short).least - 1 in
  print_string
    "\n\
     # test/test_tolerance_bench.py's, at a half period of SHORT_HALF with SHORT_BYTES: \
     the\n\
     # certificates, the sender's under the floor of a step a tenth fast, and the fault \
     one\n\
     # step past the fast bound.\n";
  printf
    "SHORT_HALF = %d\nSHORT_BYTES = [%s]\nSHORT_SENDER = {\n"
    short_half
    (String.concat ~sep:", " (List.map short_bytes ~f:(sprintf "0x%02X")));
  Certificate_entry.print_timed
    (sender_under
       ~floor:(whole short_fastest)
       [ short_fastest; 2 * short_half * Tolerance.unit ]);
  print_string "}\nSHORT_RECEIVER = {\n";
  Certificate_entry.print_timed (receiver_at ~half:short_half);
  printf
    "}\nSHORT_FAULT = 0x%X\n"
    (status_bits (Tolerance.fault short ~m:short_fast_end ~phase:0))
;;
