open! Core
open Protocol_emulator
open Protocol_emulator_test
open Playground_checks

(* Prints JSON for agree.js. Each library firmware comes with its check settings and the
   matching generate.exe flags. Each diagram comes at each clock with a native report. *)

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

(* generate.exe reads these from the source and refuses them as flags *)
let from_source = [ "side_set_count"; "wrap_bottom"; "wrap_top" ]

(* [-config] flag for the fields that differ from the default *)
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

(* The page's ints have 32 bits, too few for a CRC-32's polynomial and init (ethernet), so
   agree.js leaves that firmware out. *)
let fits_the_page (config : Program_config.t) =
  let fits n = n <= Int32.(to_int_exn max_value) in
  fits config.crc_poly && fits config.crc_init
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

(* a floor is checked on its own, like [Timed_program.check] does *)
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

(* the native report, one field per line, in the format agree.js uses for the page *)
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
      let certified_on_page kind (c : Certified.t) =
        Option.some_if (fits_the_page c.config) (certified kind c)
      in
      let bench_on_page kind (b : Bench.t) =
        Option.some_if (fits_the_page b.config) (bench kind b)
      in
      List.filter_map p.certified ~f:(certified_on_page "certified")
      @ List.filter_map p.time_triggered ~f:(certified_on_page "time_triggered")
      @ List.filter_map p.bench ~f:(bench_on_page "bench")
      @ List.filter_map p.loaded_from_hex ~f:(bench_on_page "hex"))
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
