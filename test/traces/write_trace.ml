open! Core
open Protocol_emulator_test

(* a trace kept current from its scenario, as dune.inc lists one for each *)
let rules name =
  [%string
    {|
(rule
 (with-stdout-to
  %{name}.trace.gen
  (run ./write_trace.exe %{name})))

(rule
 (alias runtest)
 (action
  (diff %{name}.trace %{name}.trace.gen)))
|}]
;;

let () =
  match Sys.get_argv () with
  | [| _; "-dune" |] ->
    print_string "; Written by write_trace.exe -dune, a pair of rules a scenario.\n";
    List.iter Pin_scenarios.all ~f:(fun s -> print_string (rules s.name))
  | args ->
    let name = args.(1) in
    (match
       List.find (Pin_scenarios.all @ Sigrok_scenarios.all) ~f:(fun s ->
         String.equal s.name name)
     with
     | None -> raise_s [%message "no such scenario" (name : string)]
     | Some scenario ->
       let lines, (_ : int list list) = Pin_trace.run scenario in
       print_string (Pin_trace.to_string scenario lines))
;;
