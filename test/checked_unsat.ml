open! Core
open Hardcaml_verify

let run ~exit_codes command =
  let exit_code = Stdlib.Sys.command command in
  if List.mem exit_codes exit_code ~equal:Int.equal
  then Ok ()
  else error_s [%message "exited" command (exit_code : int)]
;;

let cadical ?(binary = true) ~dimacs ~proof ~result () =
  run
    ~exit_codes:[ 10; 20 ]
    (String.concat
       ~sep:" "
       [ "cadical -q --unsat --lrat=true"
       ; "--binary=" ^ Bool.to_string binary
       ; Filename.quote dimacs
       ; Filename.quote proof
       ; ">" ^ Filename.quote result
       ])
;;

let check ~dimacs ~proof =
  let out = Stdlib.Filename.temp_file "cake_lpr" "out" in
  let ran =
    run
      ~exit_codes:[ 0 ]
      (String.concat
         ~sep:" "
         [ "cake_lpr"; Filename.quote dimacs; Filename.quote proof; ">" ^ out; "2>&1" ])
  in
  let verdict = In_channel.read_all out in
  Stdlib.Sys.remove out;
  match ran with
  | Ok () when String.equal verdict "s VERIFIED UNSAT\n" -> Ok ()
  | Ok () | Error _ -> error_s [%message "cake_lpr rejects the proof" verdict]
;;

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

let solve ~bad_proof ~dimacs_in ~result_out () =
  let proof = Stdlib.Filename.temp_file "cadical" "lrat" in
  let checked =
    let%bind.Or_error () =
      cadical ~binary:(not bad_proof) ~dimacs:dimacs_in ~proof ~result:result_out ()
    in
    (* any answer but SAT needs the proof, so none reads as UNSAT unchecked *)
    match In_channel.read_lines result_out with
    | "s SATISFIABLE" :: _ -> Ok ()
    | _ ->
      if bad_proof
      then
        Out_channel.write_lines proof (negate_first_lemma (In_channel.read_lines proof));
      check ~dimacs:dimacs_in ~proof
  in
  Stdlib.Sys.remove proof;
  checked
;;

let solver = solve ~bad_proof:false
let solver_with_a_bad_proof = solve ~bad_proof:true

let prove ?show name ~cases ~claim =
  let covered = Comb_gates.reduce ~f:Comb_gates.( |: ) cases in
  let queries =
    Comb_gates.(~:covered) :: List.map cases ~f:(fun case -> Comb_gates.(case &: ~:claim))
  in
  let failure =
    List.find_map queries ~f:(fun query ->
      match Solver.solve ~solver (Comb_gates.cnf query) with
      | Ok Unsat -> None
      | Ok (Sat model) -> Some (Ok model)
      | Error e -> Some (Error e))
  in
  match failure with
  | None -> print_s [%message "QED" name]
  | Some (Ok model) ->
    let shown name =
      Option.for_all show ~f:(fun names -> List.mem names name ~equal:String.equal)
    in
    let model =
      List.filter_map model ~f:(fun (m : Cnf.Model_with_vectors.input) ->
        Option.some_if (shown m.name) (m.name, m.value))
    in
    print_s [%message "counterexample" name (model : (string * string) list)]
  | Some (Error e) -> print_s [%message "solver failed" name (e : Error.t)]
;;
