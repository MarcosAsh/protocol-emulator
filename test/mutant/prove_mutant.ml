open! Core
open Hardcaml_verify
open Protocol_emulator_test

(* [Basic_gates] with each and and each not made once, across both graphs: what the mutant
   shares with the original is then the same gates, and SAT sees only the cone the
   mutation reaches. *)
module Gates = struct
  let ands = Hashtbl.create (module String)
  let nots = Hashtbl.create (module String)
  let key g = Basic_gates.Uid.to_string (Basic_gates.uid g)

  let not_ g =
    if Basic_gates.is_vdd g || Basic_gates.is_gnd g
    then Basic_gates.( ~: ) g
    else Hashtbl.find_or_add nots (key g) ~default:(fun () -> Basic_gates.( ~: ) g)
  ;;

  let and_ a b =
    let a, b = if String.( <= ) (key a) (key b) then a, b else b, a in
    Hashtbl.find_or_add
      ands
      (key a ^ " " ^ key b)
      ~default:(fun () -> Basic_gates.( &: ) a b)
  ;;
end

(* ASCII AIGER as src/aig.ml writes it: the ands in order, a bit [name[i]], or [name] when
   one wide *)
module Aiger = struct
  type t =
    { inputs : (int * string) list
    ; outputs : (string * int) list
    ; ands : (int * int * int) list
    }

  let read file =
    let lines = In_channel.read_lines file |> Array.of_list in
    let ints line = String.split line ~on:' ' |> List.map ~f:Int.of_string in
    let i, o, a =
      match String.split lines.(0) ~on:' ' with
      | [ "aag"; _; i; "0"; o; a ] -> Int.of_string i, Int.of_string o, Int.of_string a
      | _ -> raise_s [%message "not an aag with no latches" file]
    in
    let symbol line =
      match String.lsplit2 line ~on:' ' with
      | Some (_, name) -> name
      | None -> raise_s [%message "no symbol" line]
    in
    let at k = lines.(k) in
    { inputs =
        List.init i ~f:(fun k ->
          List.hd_exn (ints (at (1 + k))), symbol (at (1 + i + o + a + k)))
    ; outputs =
        List.init o ~f:(fun k ->
          symbol (at (1 + (2 * i) + o + a + k)), List.hd_exn (ints (at (1 + i + k))))
    ; ands =
        List.init a ~f:(fun k ->
          match ints (at (1 + i + o + k)) with
          | [ l; x; y ] -> l, x, y
          | _ -> raise_s [%message "not an and" (at (1 + i + o + k))])
    }
  ;;
end

let port bit =
  match String.rsplit2 bit ~on:'[' with
  | Some (name, index) -> name, Int.of_string (String.chop_suffix_exn index ~suffix:"]")
  | None -> bit, 0
;;

let widths bits =
  List.map bits ~f:port
  |> List.fold ~init:String.Map.empty ~f:(fun widths (name, index) ->
    Map.update widths name ~f:(fun w -> Int.max (index + 1) (Option.value w ~default:0)))
;;

(* each port's bits msb first, and the gates of each output port; the inputs are made once
   for both graphs, and a port of another width in one of them is refused *)
let inputs = Hashtbl.create (module String)

let build (aiger : Aiger.t) =
  Map.iteri
    (widths (List.map aiger.inputs ~f:snd))
    ~f:(fun ~key ~data ->
      match Hashtbl.find inputs key with
      | Some bits when List.length bits <> data ->
        raise_s
          [%message
            "the input differs in width" key (List.length bits : int) (data : int)]
      | Some _ -> ()
      | None -> Hashtbl.set inputs ~key ~data:(Comb_gates.input key data));
  let nodes = Hashtbl.create (module Int) in
  let literal l =
    let g = if l / 2 = 0 then Basic_gates.gnd else Hashtbl.find_exn nodes (l / 2) in
    if l % 2 = 1 then Gates.not_ g else g
  in
  List.iter aiger.inputs ~f:(fun (l, bit) ->
    let name, index = port bit in
    let bits = Hashtbl.find_exn inputs name in
    Hashtbl.set
      nodes
      ~key:(l / 2)
      ~data:(List.nth_exn bits (List.length bits - 1 - index)));
  List.iter aiger.ands ~f:(fun (l, a, b) ->
    Hashtbl.set nodes ~key:(l / 2) ~data:(Gates.and_ (literal a) (literal b)));
  let outputs = List.map aiger.outputs ~f:(fun (bit, l) -> port bit, literal l) in
  Map.mapi
    (widths (List.map aiger.outputs ~f:fst))
    ~f:(fun ~key ~data ->
      List.init data ~f:(fun k ->
        List.Assoc.find_exn outputs (key, data - 1 - k) ~equal:[%equal: string * int]))
;;

(* [assume] over the inputs: (and f ..), (or f ..), (not f), (implies f g), or a compare
   ([=] [<>] [<] [<=] [>] [>=], unsigned) of two ports, slices [(select port hi lo)] or
   numbers, a number taking the other side's width *)
let rec formula (sexp : Sexp.t) =
  let open Comb_gates in
  let all ~f = function
    | [] -> raise_s [%message "no operands" (sexp : Sexp.t)]
    | args -> List.map args ~f:formula |> reduce ~f
  in
  let value = function
    | Sexp.Atom a when Char.is_digit a.[0] -> `Number (Int.of_string a)
    | Sexp.Atom name -> `Bits (Hashtbl.find_exn inputs name)
    | List [ Atom "select"; Atom name; Atom hi; Atom lo ] ->
      `Bits
        (select
           (Hashtbl.find_exn inputs name)
           ~high:(Int.of_string hi)
           ~low:(Int.of_string lo))
    | v -> raise_s [%message "not a value" (v : Sexp.t)]
  in
  let compare op a b =
    let bits n ~like = of_unsigned_int ~width:(width like) n in
    match value a, value b with
    | `Bits a, `Bits b -> op a b
    | `Bits a, `Number n -> op a (bits n ~like:a)
    | `Number n, `Bits b -> op (bits n ~like:b) b
    | `Number _, `Number _ -> raise_s [%message "two numbers" (sexp : Sexp.t)]
  in
  match sexp with
  | List (Atom "and" :: args) -> all args ~f:( &: )
  | List (Atom "or" :: args) -> all args ~f:( |: )
  | List [ Atom "not"; f ] -> ~:(formula f)
  | List [ Atom "implies"; f; g ] -> ~:(formula f) |: formula g
  | List [ Atom "="; a; b ] -> compare ( ==: ) a b
  | List [ Atom "<>"; a; b ] -> compare ( <>: ) a b
  | List [ Atom "<"; a; b ] -> compare ( <: ) a b
  | List [ Atom "<="; a; b ] -> compare ( <=: ) a b
  | List [ Atom ">"; a; b ] -> compare ( >: ) a b
  | List [ Atom ">="; a; b ] -> compare ( >=: ) a b
  | _ -> raise_s [%message "not a formula" (sexp : Sexp.t)]
;;

(* a line each, for test/mutate.py's report *)
let print_line sexp = print_endline (Sexp.to_string sexp)

let answer name claim ~show =
  match
    Solver.solve ~solver:Checked_unsat.solver (Comb_gates.cnf Comb_gates.(~:claim))
  with
  | Ok Unsat ->
    print_line [%message "QED" name];
    true
  | Ok (Sat model) ->
    let model =
      List.filter_map model ~f:(fun (m : Cnf.Model_with_vectors.input) ->
        Option.some_if
          (List.is_empty show || List.mem show m.name ~equal:String.equal)
          (m.name, m.value))
    in
    print_line [%message "counterexample" name (model : (string * string) list)];
    false
  | Error error -> raise_s [%message "solver failed" name (error : Error.t)]
;;

let command =
  Command.basic
    ~summary:"Compare a mutant's check of a row with the original's, every UNSAT checked"
    ~readme:(fun () ->
      "Both are aag files as bin/generate.exe check-gates writes them. Proves the \
       mutant's decision equals the original's or, failing that, that it accepts only \
       what the original accepts: every -equal output the same, and each -accept group, \
       the and of the outputs it names or prefixes, implying the original's. -assume \
       states where; a counterexample names inputs under it. Exits 3 on neither.")
    [%map_open.Command
      let original = flag "-original" (required string) ~doc:"FILE the original's aag"
      and mutant = flag "-mutant" (required string) ~doc:"FILE the mutant's aag"
      and equal = flag "-equal" (listed string) ~doc:"PORT an output that must match"
      and accept =
        flag "-accept" (listed string) ~doc:"NAME the outputs whose and accepts"
      and assume = flag "-assume" (optional sexp) ~doc:"FORMULA where the claims are made"
      and show = flag "-show" (listed string) ~doc:"INPUT print only these of a model" in
      fun () ->
        let original = build (Aiger.read original) in
        let mutant = build (Aiger.read mutant) in
        if not (List.equal String.equal (Map.keys original) (Map.keys mutant))
        then raise_s [%message "the outputs differ" (Map.keys mutant : string list)];
        let group circuit name =
          Map.filter_keys circuit ~f:(String.is_prefix ~prefix:name)
          |> Map.data
          |> Comb_gates.reduce ~f:Comb_gates.( &: )
        in
        let where claim =
          Option.value_map assume ~default:claim ~f:(fun f ->
            Comb_gates.(~:(formula f) |: claim))
        in
        let same =
          List.map equal ~f:(fun name ->
            Comb_gates.(Map.find_exn mutant name ==: Map.find_exn original name))
          |> List.fold ~init:Comb_gates.vdd ~f:Comb_gates.( &: )
        in
        let claims ~f =
          List.map accept ~f:(fun name -> f (group mutant name) (group original name))
          |> List.fold ~init:same ~f:Comb_gates.( &: )
          |> where
        in
        let equivalent =
          answer
            "the mutant's check equals the original's"
            ~show
            (claims ~f:Comb_gates.( ==: ))
        in
        let stricter =
          equivalent
          || answer
               "the mutant's check accepts only what the original's accepts"
               ~show
               (claims ~f:(fun m o -> Comb_gates.(~:m |: o)))
        in
        if not stricter then exit 3]
;;

let () = Command_unix.run command
