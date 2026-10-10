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
     # Both roles on one chip (test/both_roles.ml) and the standard settings\n\
     # (test/rates.ml) as words and the configuration each runs under, at the bench's\n\
     # 48 MHz. Every firmware here passed the kernel and every rate its sheet's limits.\n";
  List.iter Both_roles.Case.firmware ~f:(fun (name, timed) -> entry name timed);
  List.iter Rates.all ~f:(fun t ->
    if not (List.for_all (Rates.check t) ~f:(fun (_, v) -> v.ok))
    then raise_s [%message "BUG: a rate fails its limits" t.bench.name]);
  List.iter [ "i2c_standard"; "i2c_fast"; "uart_tx_115200" ] ~f:(fun name ->
    let t = List.find_exn Rates.all ~f:(fun t -> String.equal t.bench.name name) in
    entry
      (if String.is_prefix name ~prefix:"uart" then "uart_tx" else name)
      (Bench.timed t.bench));
  print_string "\n# the period each rate's host sends first, in cycles\nLOADS = {\n";
  List.iter Rates.all ~f:(fun t ->
    Option.iter t.bench.load ~f:(fun load -> printf "    %S: %d,\n" t.bench.name load));
  print_string "}\n\nCASES = [\n";
  List.iter Both_roles.Case.all ~f:case;
  print_string "]\n"
;;
