open! Core
open Hardcaml_verify

let temp_file = Stdlib.Filename.temp_file "checked_unsat"

(* [query]'s DIMACS file as [Solver.solve] writes it, cadical's answer, whether cake_lpr
   accepts cadical's proof, and whether it does once [corrupt] rewrites the proof's text. *)
let solve_and_check ?corrupt query =
  let dimacs = temp_file "dimacs" in
  let proof = temp_file "lrat" in
  let result = temp_file "result" in
  Out_channel.with_file dimacs ~f:(Dimacs.write_problem (Comb_gates.cnf query));
  Checked_unsat.cadical ~binary:false ~dimacs ~proof ~result () |> ok_exn;
  let answer = In_channel.read_lines result |> List.hd_exn in
  let checked = Checked_unsat.check ~dimacs ~proof in
  print_s [%message answer (checked : unit Or_error.t)];
  Option.iter corrupt ~f:(fun corrupt ->
    Out_channel.write_lines proof (corrupt (In_channel.read_lines proof));
    let corrupted = Checked_unsat.check ~dimacs ~proof in
    print_s [%message (corrupted : unit Or_error.t)]);
  List.iter [ dimacs; proof; result ] ~f:Stdlib.Sys.remove
;;

let a = Comb_gates.input "a" 8
let b = Comb_gates.input "b" 8

(* The first lemma with its first literal negated, which its hints no longer derive. *)
let negate_first_lemma lines =
  let lemma line =
    match String.split line ~on:' ' with
    | id :: literal :: rest when not (List.mem [ "d"; "0" ] literal ~equal:String.equal)
      -> Some (id, Int.of_string literal, rest)
    | _ -> None
  in
  let first, (id, literal, rest) =
    List.find_mapi_exn lines ~f:(fun i line -> Option.map (lemma line) ~f:(fun l -> i, l))
  in
  List.mapi lines ~f:(fun i line ->
    if i = first
    then String.concat ~sep:" " (id :: Int.to_string (-literal) :: rest)
    else line)
;;

let%expect_test "cake_lpr accepts cadical's proof, and not with one line corrupted" =
  solve_and_check ~corrupt:negate_first_lemma Comb_gates.(a +: b <>: b +: a);
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
