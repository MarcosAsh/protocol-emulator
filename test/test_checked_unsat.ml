open! Core
open Hardcaml_verify

let temp_file = Stdlib.Filename.temp_file "checked_unsat"

(* [query]'s DIMACS file as [Solver.solve] writes it, cadical's answer, whether cake_lpr
   accepts cadical's proof, or with [model] whether [check_model] accepts its model, and
   whether it does once [corrupt] rewrites that file's text. *)
let solve_and_check ?corrupt ?(model = false) query =
  let dimacs = temp_file "dimacs" in
  let proof = temp_file "lrat" in
  let result = temp_file "result" in
  Out_channel.with_file dimacs ~f:(Dimacs.write_problem (Comb_gates.cnf query));
  Checked_unsat.cadical ~binary:false ~dimacs ~proof ~result () |> ok_exn;
  let answer = In_channel.read_lines result |> List.hd_exn in
  let checked, file =
    if model
    then (fun () -> Checked_unsat.check_model ~dimacs ~result), result
    else (fun () -> Checked_unsat.check ~dimacs ~proof), proof
  in
  print_s [%message answer ~checked:(checked () : unit Or_error.t)];
  Option.iter corrupt ~f:(fun corrupt ->
    Out_channel.write_lines file (corrupt (In_channel.read_lines file));
    print_s [%message "" ~corrupted:(checked () : unit Or_error.t)]);
  List.iter [ dimacs; proof; result ] ~f:Stdlib.Sys.remove
;;

let a = Comb_gates.input "a" 8
let b = Comb_gates.input "b" 8

let%expect_test "cake_lpr accepts cadical's proof, and not with one line corrupted" =
  solve_and_check ~corrupt:Checked_unsat.negate_first_lemma Comb_gates.(a +: b <>: b +: a);
  [%expect
    {|
    ("s UNSATISFIABLE" (checked (Ok ())))
    (corrupted
     (Error
      ("cake_lpr rejects the proof"
       "c Checking failed at line: 1. Reason: clause index has no reduction sequence: 5\n")))
    |}]
;;

(* A satisfiable query has no proof: cadical writes only the lemmas it learnt, which never
   reach the empty clause. *)
let%expect_test "a satisfiable query yields no proof" =
  solve_and_check Comb_gates.(a +: b ==: a);
  [%expect
    {|
    ("s SATISFIABLE"
     (checked
      (Error
       ("cake_lpr rejects the proof"
        "c empty clause not derived at end of proof\n"))))
    |}]
;;

let%expect_test "cadical's model makes every clause true, and not with a bit flipped" =
  solve_and_check
    ~model:true
    ~corrupt:Checked_unsat.negate_first_value
    Comb_gates.(a +: b ==: a);
  [%expect
    {|
    ("s SATISFIABLE" (checked (Ok ())))
    (corrupted (Error ("the model falsifies a clause" (clause (-21 -1 22)))))
    |}]
;;

let%expect_test "an unsatisfiable query yields no model" =
  solve_and_check ~model:true Comb_gates.(a +: b <>: b +: a);
  [%expect
    {|
    ("s UNSATISFIABLE"
     (checked (Error ("no model" (answer ("s UNSATISFIABLE"))))))
    |}]
;;

(* [check_model] of a DIMACS file and a model written by hand. *)
let check_by_hand ~dimacs ~model =
  let dimacs_file = temp_file "dimacs" in
  let result = temp_file "result" in
  Out_channel.write_lines dimacs_file dimacs;
  Out_channel.write_lines result ("s SATISFIABLE" :: model);
  let checked = Checked_unsat.check_model ~dimacs:dimacs_file ~result in
  print_s [%message "" (dimacs : string list) (checked : unit Or_error.t)];
  List.iter [ dimacs_file; result ] ~f:Stdlib.Sys.remove
;;

let%expect_test "a clause runs to its 0, not to the end of its line" =
  let model = [ "v 1 -2 0" ] in
  check_by_hand ~dimacs:[ "p cnf 2 2"; "1 0 2 0" ] ~model;
  check_by_hand ~dimacs:[ "p cnf 2 2"; "1 0 -2"; "2 0" ] ~model;
  check_by_hand ~dimacs:[ "p cnf 2 1"; "-1 -2" ] ~model;
  check_by_hand ~dimacs:[ "p cnf 2 1"; "1 c 0" ] ~model;
  [%expect
    {|
    ((dimacs ("p cnf 2 2" "1 0 2 0"))
     (checked (Error ("the model falsifies a clause" (clause (2))))))
    ((dimacs ("p cnf 2 2" "1 0 -2" "2 0")) (checked (Ok ())))
    ((dimacs ("p cnf 2 1" "-1 -2"))
     (checked (Error ("a clause has no 0" (clause (-1 -2))))))
    ((dimacs ("p cnf 2 1" "1 c 0"))
     (checked (Error (Failure "Int.of_string: \"c\""))))
    |}]
;;
