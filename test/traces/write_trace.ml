open! Core
open Protocol_emulator_test

(* a trace kept current from its scenario, as dune.inc lists one for each *)
let rules ~exe name =
  [%string
    {|
(rule
 (with-stdout-to
  %{name}.trace.gen
  (run %{exe} %{name})))

(rule
 (alias runtest)
 (action
  (diff %{name}.trace %{name}.trace.gen)))
|}]
;;

let dune ~flag ~exe scenarios =
  printf "; Written by write_trace.exe %s, a pair of rules a scenario.\n" flag;
  List.iter scenarios ~f:(fun (s : Pin_trace.Scenario.t) ->
    print_string (rules ~exe s.name))
;;

let () =
  match Sys.get_argv () with
  | [| _; "-dune" |] -> dune ~flag:"-dune" ~exe:"./write_trace.exe" Pin_scenarios.all
  | [| _; "-dune-decoded" |] ->
    dune ~flag:"-dune-decoded" ~exe:"../write_trace.exe" Library.decoded
  | args ->
    let name = args.(1) in
    (match
       List.find (Pin_scenarios.all @ Library.decoded) ~f:(fun s ->
         String.equal s.name name)
     with
     | None -> raise_s [%message "no such scenario" (name : string)]
     | Some scenario ->
       let lines, (_ : int list list) = Pin_trace.run scenario in
       print_string (Pin_trace.to_string scenario lines))
;;
