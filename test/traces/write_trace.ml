open! Core
open Protocol_emulator_test

let () =
  let name = (Sys.get_argv ()).(1) in
  match List.find Pin_scenarios.all ~f:(fun s -> String.equal s.name name) with
  | None -> raise_s [%message "no such scenario" (name : string)]
  | Some scenario ->
    let lines, (_ : int list list) = Pin_trace.run scenario in
    print_string (Pin_trace.to_string scenario lines)
;;
