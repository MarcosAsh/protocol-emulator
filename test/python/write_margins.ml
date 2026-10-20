open! Core
open Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* Margins.all as JSON for demo/margins.py: each sweep's rows, and each point's firmware,
   verdicts, sweep limit set and model run, or why the kernel refused it. *)

let string s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter s ~f:(function
    | '"' -> Buffer.add_string b "\\\""
    | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | c when Char.to_int c < 0x20 ->
      Buffer.add_string b (sprintf "\\u%04x" (Char.to_int c))
    | c -> Buffer.add_char b c);
  Buffer.add_char b '"';
  Buffer.contents b
;;

let list f items = "[" ^ String.concat ~sep:", " (List.map items ~f) ^ "]"

let obj fields =
  "{"
  ^ String.concat ~sep:", " (List.map fields ~f:(fun (k, v) -> string k ^ ": " ^ v))
  ^ "}"
;;

let int = Int.to_string
let float = sprintf "%.3f"
let bool = Bool.to_string
let option f = Option.value_map ~default:"null" ~f

let row (row : Datasheet.t) =
  let side, ns =
    match row.limit with
    | At_least ns -> ">=", ns
    | At_most ns -> "<=", ns
  in
  let margin =
    match row.margin with
    | Cycle -> "a cycle"
    | Ns { ns; why } -> sprintf "%g ns, %s" ns why
  in
  obj
    [ "parameter", string row.parameter
    ; "side", string side
    ; "ns", float ns
    ; "margin", string margin
    ; ( "sheet"
      , string [%string "%{row.sheet.part}, %{row.sheet.document} %{row.sheet.page}"] )
    ]
;;

let verdict (v : Margins.Verdict.t) =
  obj [ "row", row v.row; "value", option int v.value; "ok", bool v.ok ]
;;

let config (bench : Bench.t) =
  Engine.Config.map2
    Engine.Config.port_names
    (Engine.Config.of_program_config (Timed_program.config (Bench.timed bench)))
    ~f:(fun name value -> name, int (Bits.to_unsigned_int value))
  |> Engine.Config.to_list
  |> obj
;;

let point (p : Margins.Point.t) =
  obj
    [ "cycles", int p.cycles
    ; "ns", float (Margins.Point.ns p)
    ; "what", string p.bench.what
    ; "label", string (Margins.Point.label p)
    ; "in_spec", bool p.in_spec
    ; "verdicts", list verdict p.verdicts
    ; "sweep_limits", list row p.sweep_limits
    ; "designed", option int p.designed
    ; "sweep_ok", bool p.sweep_ok
    ; ( "measured"
      , obj
          (List.map
             (Margins.Measured.to_alist p.measured)
             ~f:(fun (name, (least, most)) -> name, list int [ least; most ])) )
    ; "config", config p.bench
    ; "words", list int (Timed_program.words (Bench.timed p.bench))
    ; "load", option int p.bench.load
    ; "model_words", list int p.words
    ; "source", string p.bench.source
    ]
;;

let sweep (s : Margins.Sweep.t) =
  obj
    [ "part", string s.part
    ; "parameter", string s.parameter
    ; "what", string s.what
    ; "observable", string s.observable
    ; "nominal", int s.nominal
    ; "rows", list row s.rows
    ; ( "points"
      , list
          (function
            | First p -> point p
            | Second why -> obj [ "refused", string why ])
          s.points )
    ]
;;

let () =
  print_endline
    (obj
       [ "clock_hz", int Bench.clock_hz
       ; ( "sweeps"
         , "[\n" ^ String.concat ~sep:",\n" (List.map (Margins.all ()) ~f:sweep) ^ "\n]" )
       ])
;;
