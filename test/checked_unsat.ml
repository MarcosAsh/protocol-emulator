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
  let verdict =
    Exn.protect
      ~f:(fun () -> In_channel.read_all out)
      ~finally:(fun () -> Stdlib.Sys.remove out)
  in
  match ran with
  | Ok () when String.equal verdict "s VERIFIED UNSAT\n" -> Ok ()
  | Ok () | Error _ -> error_s [%message "cake_lpr rejects the proof" verdict]
;;

let words line = String.split line ~on:' ' |> List.filter ~f:(Fn.non String.is_empty)
let holding literal = if literal > 0 then '1' else '0'

(* The value the model gives each variable, ['-'] where it gives none, from every word
   after the answer, as hardcaml_verify's model reader takes them. A variable set twice,
   of which that reader keeps the last, is refused. *)
let read_model model ~variables =
  let values = Bytes.make (variables + 1) '-' in
  let set literal =
    let variable = abs literal in
    if not (Char.equal (Bytes.get values variable) '-')
    then raise_s [%message "the model sets a variable twice" (variable : int)];
    Bytes.set values variable (holding literal)
  in
  List.iter model ~f:(fun line ->
    List.iter (words line) ~f:(fun word ->
      if not (String.equal word "v")
      then (
        match Int.of_string word with
        | 0 -> ()
        | literal -> set literal)));
  values
;;

let check_model ~dimacs ~result =
  Or_error.try_with (fun () ->
    In_channel.with_file dimacs ~f:(fun dimacs ->
      let variables =
        match words (In_channel.input_line_exn dimacs) with
        | [ "p"; "cnf"; variables; _ ] -> Int.of_string variables
        | header -> raise_s [%message "not a DIMACS header" (header : string list)]
      in
      let values =
        match In_channel.read_lines result with
        | "s SATISFIABLE" :: model -> read_model model ~variables
        | answer -> raise_s [%message "no model" ~answer:(List.hd answer : string option)]
      in
      let holds literal = Char.equal (Bytes.get values (abs literal)) (holding literal) in
      (* a clause runs to its 0, across lines or several to a line *)
      let unfinished =
        In_channel.fold_lines dimacs ~init:[] ~f:(fun clause line ->
          List.fold (words line) ~init:clause ~f:(fun clause word ->
            match Int.of_string word with
            | 0 ->
              let clause = List.rev clause in
              if not (List.exists clause ~f:holds)
              then raise_s [%message "the model falsifies a clause" (clause : int list)];
              []
            | literal -> literal :: clause))
      in
      if not (List.is_empty unfinished)
      then raise_s [%message "a clause has no 0" ~clause:(List.rev unfinished : int list)]))
;;

(* [lines] with the first literal that [literal] finds in a line negated. *)
let negate_first lines ~literal =
  let first, (head, value, rest) =
    List.find_mapi_exn lines ~f:(fun i line ->
      Option.map (literal line) ~f:(fun l -> i, l))
  in
  List.mapi lines ~f:(fun i line ->
    if i = first
    then String.concat ~sep:" " (head :: Int.to_string (-value) :: rest)
    else line)
;;

let negate_first_lemma =
  negate_first ~literal:(fun line ->
    match String.split line ~on:' ' with
    | id :: literal :: rest when not (List.mem [ "d"; "0" ] literal ~equal:String.equal)
      -> Some (id, Int.of_string literal, rest)
    | _ -> None)
;;

let negate_first_value =
  negate_first ~literal:(fun line ->
    match String.split line ~on:' ' with
    | "v" :: literal :: rest when not (String.equal literal "0") ->
      Some ("v", Int.of_string literal, rest)
    | _ -> None)
;;

let solve ~bad_proof ~bad_model ~dimacs_in ~result_out () =
  let proof = Stdlib.Filename.temp_file "cadical" "lrat" in
  Exn.protect
    ~finally:(fun () -> Stdlib.Sys.remove proof)
    ~f:(fun () ->
      let%bind.Or_error () =
        cadical ~binary:(not bad_proof) ~dimacs:dimacs_in ~proof ~result:result_out ()
      in
      (* SAT needs its model to hold and any other answer the proof, so none reads
         unchecked *)
      match In_channel.read_lines result_out with
      | "s SATISFIABLE" :: _ as model ->
        if bad_model then Out_channel.write_lines result_out (negate_first_value model);
        check_model ~dimacs:dimacs_in ~result:result_out
      | _ when bad_proof ->
        Out_channel.write_lines proof (negate_first_lemma (In_channel.read_lines proof));
        check ~dimacs:dimacs_in ~proof
      | _ ->
        (* cadical still answers UNSAT when a full disk cuts its proof short *)
        let proof_bytes = In_channel.with_file proof ~f:In_channel.length in
        check ~dimacs:dimacs_in ~proof
        |> Or_error.tag_s ~tag:[%message (proof : string) (proof_bytes : int64)])
;;

let solver = solve ~bad_proof:false ~bad_model:false
let solver_with_a_bad_proof = solve ~bad_proof:true ~bad_model:false
let solver_with_a_bad_model = solve ~bad_proof:false ~bad_model:true

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
