open! Core
open Js_of_ocaml
open Protocol_emulator
open Playground_checks

let () =
  let report (report : Checks.Report.t) =
    Js.Unsafe.obj
      [| "verdict", Js.Unsafe.inject (Js.string report.verdict)
       ; "detail", Js.Unsafe.inject (Js.string report.detail)
       ; "listing", Js.Unsafe.inject (Js.string report.listing)
       ; "rows", Js.Unsafe.inject (Js.string report.rows)
      |]
  in
  let check source period single_capture_edge capture_pin capture_falling =
    Checks.check
      ?period:(Js.Opt.to_option period)
      ~single_capture_edge:(Js.to_bool single_capture_edge)
      ~config:
        { Program_config.default with
          capture_pin
        ; capture_rising = not (Js.to_bool capture_falling)
        }
      (Js.to_string source)
    |> report
  in
  (* under a whole configuration, a sexp, as the library's firmware is checked *)
  let check_configured source config period period_floor single_capture_edge =
    Checks.check
      ?period:(Js.Opt.to_option period)
      ?period_floor:(Js.Opt.to_option period_floor)
      ~single_capture_edge:(Js.to_bool single_capture_edge)
      ~config:(Js.to_string config |> Sexp.of_string |> Program_config.t_of_sexp)
      (Js.to_string source)
    |> report
  in
  let check_pio source spec =
    let report =
      Checks.check_pio ~source:(Js.to_string source) ~spec:(Js.to_string spec)
    in
    Js.Unsafe.obj
      [| "verdict", Js.Unsafe.inject (Js.string report.verdict)
       ; "report", Js.Unsafe.inject (Js.string report.report)
      |]
  in
  let run_diagram source frames clock_hz =
    let report =
      Checks.run_diagram
        ~source:(Js.to_string source)
        ~frames:(Js.to_string frames)
        ~clock_hz
    in
    Js.Unsafe.obj
      [| "verdict", Js.Unsafe.inject (Js.string report.verdict)
       ; "detail", Js.Unsafe.inject (Js.string report.detail)
       ; "steps", Js.Unsafe.inject (Js.string report.steps)
       ; "words", Js.Unsafe.inject (Js.string report.words)
       ; ( "lanes"
         , Js.Unsafe.inject (Js.array (Array.of_list_map report.lanes ~f:Js.string)) )
       ; "levels", Js.Unsafe.inject (Js.array report.levels)
       ; "cycleNs", Js.Unsafe.inject (Checks.cycle_ns ~clock_hz)
      |]
  in
  let mutate source percent clock_hz =
    let verdicts v =
      ( Js.string (Diagram_mutation.Verdict.to_string v)
      , Js.bool
          (match (v : Diagram_mutation.Verdict.t) with
           | Accepted _ -> true
           | Refused _ -> false) )
    in
    match
      let open Or_error.Let_syntax in
      let%bind diagram = Wavejson.parse (Js.to_string source) in
      Diagram_mutation.run ~clock_hz diagram ~percent
    with
    | Error e ->
      Js.Unsafe.obj [| "error", Js.Unsafe.inject (Js.string (Error.to_string_hum e)) |]
    | Ok r ->
      let original, original_ok = verdicts r.original in
      let mutant, mutant_ok = verdicts r.mutant in
      Js.Unsafe.obj
        [| "original", Js.Unsafe.inject original
         ; "originalOk", Js.Unsafe.inject original_ok
         ; "mutant", Js.Unsafe.inject mutant
         ; "mutantOk", Js.Unsafe.inject mutant_ok
         ; ( "cycles"
           , Js.Unsafe.inject
               (Js.string (List.map r.cycles ~f:Int.to_string |> String.concat ~sep:" "))
           )
        |]
  in
  (* a lab job file through the worker's own check: the files its result folder starts
     with, check.json first among them *)
  let lab_check text =
    let files =
      match
        Or_error.bind (Remote_lab.Job.of_string (Js.to_string text)) ~f:Remote_lab.check
      with
      | Error e -> Remote_lab.malformed e
      | Ok t -> Remote_lab.files t
    in
    Js.array
      (Array.of_list_map files ~f:(fun (name, contents) ->
         Js.array [| Js.string name; Js.string contents |]))
  in
  Js.export
    "protocolEmulator"
    (Js.Unsafe.obj
       [| "check", Js.Unsafe.inject (Js.wrap_callback check)
        ; "checkConfigured", Js.Unsafe.inject (Js.wrap_callback check_configured)
        ; ( "examples"
          , Js.Unsafe.inject
              (Js.array
                 (Array.of_list_map Example.all ~f:(fun (name, source) ->
                    Js.array [| Js.string name; Js.string source |]))) )
        ; "checkPio", Js.Unsafe.inject (Js.wrap_callback check_pio)
        ; "runDiagram", Js.Unsafe.inject (Js.wrap_callback run_diagram)
        ; "mutateDiagram", Js.Unsafe.inject (Js.wrap_callback mutate)
        ; "labCheck", Js.Unsafe.inject (Js.wrap_callback lab_check)
        ; ( "diagramExamples"
          , Js.Unsafe.inject
              (Js.array
                 (Array.of_list_map Diagram_example.all ~f:(fun (name, source, frames) ->
                    Js.array [| Js.string name; Js.string source; Js.string frames |]))) )
        ; ( "pioExamples"
          , Js.Unsafe.inject
              (Js.array
                 (Array.of_list_map Pio_example.all ~f:(fun (name, source, spec) ->
                    Js.array [| Js.string name; Js.string source; Js.string spec |]))) )
       |])
;;
