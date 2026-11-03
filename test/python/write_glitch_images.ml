open! Core
open! Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* The glitch map as JSON lines for demo/glitch_map.py: the receiver, then each image with
   the pulse the rows place and what the rows say the receiver pushes, each with what the
   host certifies it with. *)

let ints items = "[" ^ String.concat ~sep:", " (List.map items ~f:Int.to_string) ^ "]"

let config c =
  Engine.Config.map2
    Engine.Config.port_names
    (Engine.Config.of_program_config c)
    ~f:(fun name value -> sprintf "\"%s\": %d" name (Bits.to_unsigned_int value))
  |> Engine.Config.to_list
  |> String.concat ~sep:", "
  |> sprintf "{%s}"
;;

let at (i : Interval.t) = ints (List.filter_opt [ i.lo; i.hi ])

(* what the host certifies the firmware with, under what it was analysed under *)
let check timed =
  let assumptions = System_lockstep.Assumptions.of_timed timed in
  sprintf
    "{\"certificate\": %s, \"loaded\": %s, \"floor\": %b, \"single_edge\": %b}"
    (ints
       (System_lockstep.Assumptions.certificate
          assumptions
          ~config:(Timed_program.config timed)
          (Timed_program.words timed)))
    (Option.value_map
       (System_lockstep.Assumptions.loaded assumptions)
       ~default:"null"
       ~f:Int.to_string)
    (Option.is_some assumptions.period_floor)
    assumptions.single_capture_edge
;;

let () =
  let receiver = Glitch_map.receiver in
  printf
    "{\"receiver\": %s, \"config\": %s, \"check\": %s, \"period\": %d}\n"
    (ints (Timed_program.words receiver))
    (config (Timed_program.config receiver))
    (check receiver)
    Glitch_map.period;
  List.iter Glitch_map.pulses ~f:(fun k ->
    let image = Glitch_map.image k in
    let { Glitch_map.Outcome.words; framing_error; refused } = Glitch_map.predict k in
    printf
      "{\"k\": %d, \"pulse\": %s, \"words\": %s, \"config\": %s, \"check\": %s, \
       \"predict\": %s, \"framing_error\": %b, \"refused\": %b}\n"
      k
      (at image.pulse)
      (ints (Timed_program.words image.timed))
      (config (Timed_program.config image.timed))
      (check image.timed)
      (ints words)
      framing_error
      refused)
;;
