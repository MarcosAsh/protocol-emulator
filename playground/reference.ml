open! Core
open Protocol_emulator
open Protocol_emulator_test
open Playground_checks

(* As JSON on stdout, for agree.js: each library firmware with what it is checked under
   and the flags that tell generate.exe the same, and each diagram given at each clock
   with its report from a native build. *)

let json_string s =
  String.concat_map s ~f:(function
    | '"' -> "\\\""
    | '\\' -> "\\\\"
    | '\n' -> "\\n"
    | c when Char.to_int c < 0x20 -> sprintf "\\u%04x" (Char.to_int c)
    | c -> String.of_char c)
  |> sprintf "\"%s\""
;;

let json_object fields =
  List.map fields ~f:(fun (name, value) -> json_string name ^ ": " ^ value)
  |> String.concat ~sep:", "
  |> sprintf "{ %s }"
;;

let json_array values = "[\n  " ^ String.concat values ~sep:"\n, " ^ "\n]"
let json_int = Option.value_map ~default:"null" ~f:Int.to_string

(* generate.exe takes these from the source, and refuses them as flags *)
let from_source = [ "side_set_count"; "wrap_bottom"; "wrap_top" ]

(* [-config] for the fields that differ from the default *)
let config_flags config =
  let fields sexp =
    match (sexp : Sexp.t) with
    | List pairs ->
      List.map pairs ~f:(function
        | List [ Atom field; value ] -> field, value
        | pair -> raise_s [%message "BUG: not a field" (pair : Sexp.t)])
    | Atom _ -> raise_s [%message "BUG: config is not a record" (sexp : Sexp.t)]
  in
  let default = fields (Program_config.sexp_of_t Program_config.default) in
  fields (Program_config.sexp_of_t config)
  |> List.filter ~f:(fun (field, value) ->
    (not (List.mem from_source field ~equal:String.equal))
    && not
         ([%equal: Sexp.t option]
            (List.Assoc.find default field ~equal:String.equal)
            (Some value)))
  |> List.map ~f:(fun (field, value) -> field ^ "=" ^ Sexp.to_string value)
  |> function
  | [] -> []
  | fields -> [ "-config"; String.concat ~sep:"," fields ]
;;

let firmware
  ~kind
  ~name
  ?period
  ?period_floor
  ~single_capture_edge
  ~(config : Program_config.t)
  source
  =
  let flags =
    Option.value_map period ~default:[] ~f:(fun p -> [ "-period"; Int.to_string p ])
    @ Option.value_map period_floor ~default:[] ~f:(fun p ->
      [ "-period-floor"; Int.to_string p ])
    @ (if single_capture_edge then [ "-single-capture-edge" ] else [])
    @ config_flags config
  in
  json_object
    [ "name", json_string [%string "%{kind}-%{name}"]
    ; "source", json_string source
    ; "config", json_string (Sexp.to_string (Program_config.sexp_of_t config))
    ; "period", json_int period
    ; "periodFloor", json_int period_floor
    ; "singleCaptureEdge", Bool.to_string single_capture_edge
    ; "flags", json_array (List.map flags ~f:json_string)
    ]
;;

(* a floor is checked alone, as [Timed_program.check] does *)
let certified kind (c : Certified.t) =
  firmware
    ~kind
    ~name:c.name
    ?period:(if Option.is_some c.period_floor then None else c.period)
    ?period_floor:c.period_floor
    ~single_capture_edge:c.single_capture_edge
    ~config:c.config
    c.source
;;

let bench kind (b : Bench.t) =
  let period, period_floor, single_capture_edge =
    match b.assumption with
    | Nothing -> None, None, false
    | Floor floor -> None, Some floor, false
    | Period period -> Some period, None, false
    | Receiver period -> Some period, None, true
  in
  firmware
    ~kind
    ~name:b.name
    ?period
    ?period_floor
    ~single_capture_edge
    ~config:b.config
    b.source
;;

(* the page's report, a field a line, as agree.js writes the page's *)
let diagram_report (r : Checks.Diagram_report.t) ~clock_hz =
  String.concat
    [ "verdict: " ^ r.verdict ^ "\n"
    ; "detail:\n" ^ r.detail ^ "\n"
    ; "steps:\n" ^ r.steps ^ "\n"
    ; "words: " ^ r.words ^ "\n"
    ; "lanes: " ^ String.concat ~sep:" " r.lanes ^ "\n"
    ; "levels: "
      ^ (Array.to_list r.levels |> List.map ~f:Int.to_string |> String.concat ~sep:",")
      ^ "\n"
    ; sprintf "cycle ns: %.6f\n" (Checks.cycle_ns ~clock_hz)
    ]
;;

let diagram file ~clock_hz =
  let name = Filename.basename file |> Filename.chop_extension in
  let source = In_channel.read_all file in
  let frames =
    List.find_map Diagram_example.all ~f:(fun (example, _, frames) ->
      Option.some_if (String.equal example name) frames)
    |> Option.value ~default:""
  in
  json_object
    [ "name", json_string name
    ; "clockHz", Int.to_string clock_hz
    ; "source", json_string source
    ; "frames", json_string frames
    ; ( "native"
      , json_string
          (diagram_report (Checks.run_diagram ~source ~frames ~clock_hz) ~clock_hz) )
    ]
;;

let () =
  let diagrams = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let firmware =
    List.concat_map Library.protocols ~f:(fun p ->
      List.map p.certified ~f:(certified "certified")
      @ List.map p.time_triggered ~f:(certified "time_triggered")
      @ List.map p.bench ~f:(bench "bench")
      @ List.map p.loaded_from_hex ~f:(bench "hex"))
    @ [ certified "certified" Library.stamped ]
  in
  json_object
    [ "firmware", json_array firmware
    ; ( "diagrams"
      , json_array
          (List.concat_map diagrams ~f:(fun file ->
             List.map [ 48_000_000; 50_000_000 ] ~f:(fun clock_hz ->
               diagram file ~clock_hz))) )
    ]
  |> print_endline
;;
