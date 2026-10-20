open! Core
open Hardcaml
open Protocol_emulator
open Protocol_emulator_test

let entry name timed =
  let fields =
    Engine.Config.map2
      Engine.Config.port_names
      (Engine.Config.of_program_config (Timed_program.config timed))
      ~f:(fun name value -> name, Bits.to_unsigned_int value)
    |> Engine.Config.to_list
  in
  printf "\n%s = {\n    \"config\": {\n" (String.uppercase name);
  List.iter fields ~f:(fun (field, value) -> printf "        \"%s\": %d,\n" field value);
  print_string "    },\n    \"words\": [\n";
  List.chunks_of (Timed_program.words timed) ~length:8
  |> List.iter ~f:(fun chunk ->
    printf
      "        %s,\n"
      (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))));
  print_string "    ],\n}\n"
;;

let words list = String.concat ~sep:", " (List.map list ~f:(sprintf "0x%X"))

(* Each case as the model runs it, so the board is held to what both engines push there. *)
let case (c : Both_roles.Case.t) =
  let outcome =
    Both_roles.model
      ~pads:c.pads
      ~cycles:c.cycles
      ~controller:{ timed = c.controller; words = c.controller_words }
      ~target:{ timed = c.target; words = c.target_words }
      ()
  in
  if List.exists outcome.faults ~f:(Fn.non (Machine.Fault.equal Machine.Fault.none))
  then raise_s [%message "BUG: a case faults" c.name];
  printf
    "    {\n\
    \        \"name\": %S,\n\
    \        \"controller\": %s,\n\
    \        \"target\": %s,\n\
    \        \"controller_words\": [%s],\n\
    \        \"target_words\": [%s],\n\
    \        \"controller_pushes\": [%s],\n\
    \        \"target_pushes\": [%s],\n\
    \        \"irq\": [%s],\n\
    \    },\n"
    c.name
    (String.uppercase c.controller_name)
    (String.uppercase c.target_name)
    (words c.controller_words)
    (words c.target_words)
    (words outcome.controller)
    (words outcome.target)
    (String.concat
       ~sep:", "
       (List.map outcome.irq ~f:(fun irq -> if irq then "True" else "False")))
;;

let () =
  print_string
    "# Written by test/python/write_both_roles_firmware.ml; `dune promote` after a change.\n\
     # Both roles on one chip (test/both_roles.ml) as words and the configuration each\n\
     # runs under, at the bench's 48 MHz, every firmware passed by the kernel, and the\n\
     # loads of the standard settings python/bench_firmware.py holds.\n";
  List.iter Both_roles.Case.firmware ~f:(fun (name, timed) -> entry name timed);
  print_string
    "\n# the period each standard setting's host sends first, in cycles\nLOADS = {\n";
  List.iter Library.bench ~f:(fun (bench : Bench.t) ->
    match bench.load with
    | Some load
      when String.is_prefix bench.name ~prefix:"uart_tx_"
           || List.mem [ "i2c_standard"; "i2c_fast" ] bench.name ~equal:String.equal ->
      printf "    %S: %d,\n" bench.name load
    | _ -> ());
  print_string "}\n\nCASES = [\n";
  List.iter Both_roles.Case.all ~f:case;
  print_string "]\n"
;;
