open! Core
open Js_of_ocaml
open Protocol_emulator

module Report = struct
  type t =
    { verdict : string
    ; detail : string
    ; listing : string
    ; rows : string
    }
end

let listing (program : Asm.Program.t) words =
  List.mapi
    (List.zip_exn words program.instructions)
    ~f:(fun address (word, instruction) ->
      sprintf
        "%3d  %04x  %s"
        address
        word
        (Asm.to_string ~side_set_count:program.side_set_count instruction))
  |> String.concat ~sep:"\n"
;;

(* [generate.exe assemble -listing] and [-rows], with its flags that the page offers,
   stage by stage, so the page names whichever of the assembler, analyser and kernel
   refuses. *)
let check ?period ~single_capture_edge ~capture_pin ~capture_falling source : Report.t =
  let refused stage e =
    { Report.verdict = "refused by the " ^ stage
    ; detail = Error.to_string_hum e
    ; listing = ""
    ; rows = ""
    }
  in
  match Asm.assemble source with
  | Error e -> refused "assembler" e
  | Ok program ->
    let unconfigured =
      { Program_config.default with capture_pin; capture_rising = not capture_falling }
    in
    let config = Asm.Program.configure program unconfigured in
    let rows =
      Analyser.analyse ?period ~single_capture_edge ~config program.instructions
    in
    let report =
      { Report.verdict = ""
      ; detail = ""
      ; listing =
          Asm.Program.words program
          |> Or_error.ok
          |> Option.value_map ~default:"" ~f:(listing program)
      ; rows = Analyser.to_string ~side_set_count:program.side_set_count rows
      }
    in
    (match Analyser.check ?period ~single_capture_edge ~config:unconfigured program with
     | Error e ->
       { (refused "analyser" e) with listing = report.listing; rows = report.rows }
     | Ok verdict ->
       let analysed = Analyser.Verdict.to_string verdict in
       (match
          let open Or_error.Let_syntax in
          let%bind words = Asm.Program.words program in
          Kernel.check
            ?period
            ~single_capture_edge
            ~config
            ~words
            (Kernel.Table.of_analyser rows)
        with
        | Error e ->
          { report with
            verdict = "refused by the kernel"
          ; detail =
              analysed
              ^ ", but the kernel rejects the analyser's rows\n"
              ^ Error.to_string_hum e
          }
        | Ok () ->
          { report with
            verdict = "accepted"
          ; detail =
              analysed ^ "\nkernel: accepted, so no deadline is missed by the step lemma"
          }))
;;

module Pio_report = struct
  type t =
    { verdict : string
    ; report : string
    }
end

(* [pio_check] on [source] with [spec]'s flags, one a line: "passed" where it exits 0,
   "failed" on any FAIL or ERROR, refused where it gives a usage error. *)
let check_pio ~source ~spec : Pio_report.t =
  match
    let open Or_error.Let_syntax in
    let%bind spec = Pio.Spec.of_string spec in
    let%bind programs = Pio.Pioasm.parse source >>= Pio.Spec.select spec in
    let%bind configure = Pio.Spec.configure spec in
    List.map programs ~f:(fun program ->
      let%map config = configure program in
      Pio.Timing.analyse config program)
    |> Or_error.all
  with
  | Error e -> { verdict = "refused"; report = Error.to_string_hum e }
  | Ok reports ->
    { verdict =
        (if List.for_all reports ~f:Pio.Timing.Report.passed then "passed" else "failed")
    ; report = List.map reports ~f:Pio.Timing.Report.to_string |> String.concat
    }
;;

module Diagram_report = struct
  type t =
    { verdict : string
    ; detail : string
    ; steps : string
    ; words : string
    ; lanes : string list
    ; levels : int array
    }
end

let cycle_ns = 20

let step_listing (t : Wavedrom.t) =
  List.mapi t.steps ~f:(fun i (s : Wavedrom.Step.t) ->
    let outputs =
      List.map2_exn t.outputs s.outputs ~f:(fun lane level ->
        let level =
          match (level : Wavedrom.Level.t) with
          | Low -> "0"
          | High -> "1"
          | Bit -> "bit"
        in
        lane ^ "=" ^ level)
      |> String.concat ~sep:" "
    in
    sprintf
      "%2d  %-26s %-20s %-10s %6d cycles %8d ns"
      i
      s.name
      outputs
      (Sexp.to_string (Tables.Kind.sexp_of_t s.kind))
      s.cycles
      (s.cycles * cycle_ns))
  |> String.concat ~sep:"\n"
;;

(* each line of [frames] a frame's bits, 0 and 1, blanks ignored *)
let frame_bits frames =
  String.split_lines frames
  |> List.map ~f:(String.filter ~f:(Fn.non Char.is_whitespace))
  |> List.filter ~f:(Fn.non String.is_empty)
  |> List.map ~f:(fun line ->
    String.to_list line
    |> List.map ~f:(function
      | '0' -> Ok false
      | '1' -> Ok true
      | c -> Or_error.error_s [%message "a frame is 0s and 1s" (c : char)])
    |> Or_error.all)
  |> Or_error.all
;;

(* The diagram compiled, then the model of the core running it on [frames]. *)
let run_diagram ~source ~frames : Diagram_report.t =
  let empty =
    { Diagram_report.verdict = ""
    ; detail = ""
    ; steps = ""
    ; words = ""
    ; lanes = []
    ; levels = [||]
    }
  in
  match Wavedrom.of_string source with
  | Error e -> { empty with verdict = "refused"; detail = Error.to_string_hum e }
  | Ok t ->
    let lanes = if t.starts_on_edge then Option.to_list t.input else t.outputs in
    let report = { empty with steps = step_listing t; lanes } in
    (match
       let open Or_error.Let_syntax in
       let%bind frames = frame_bits frames in
       let%bind words =
         if t.starts_on_edge
         then Ok []
         else List.map frames ~f:(Wavedrom.host_words t) |> Or_error.all >>| List.concat
       in
       (* a receiver's frames are the peer's, on the line the diagram draws *)
       let%bind line = if t.starts_on_edge then Wavedrom.line t frames else Ok [||] in
       let%bind interpreter =
         Tables.check t.table.wiring
         |> Result.map_error ~f:(fun (r : Timed_program.Refusal.t) -> r.error)
       in
       let longest =
         List.sum (module Int) t.steps ~f:(fun s -> s.cycles + Tables.Kind.added s.kind)
       in
       let cycles =
         Int.min 400_000 (Array.length line + (longest * (List.length words + 2)))
       in
       let inputs c =
         if Array.is_empty line
         then 0
         else Bool.to_int line.(Int.min c (Array.length line - 1))
       in
       let%map levels, read, fault =
         Wavedrom.simulate t ~host_words:words ~inputs ~cycles
       in
       let levels =
         if Array.is_empty line then levels else Array.map line ~f:Bool.to_int
       in
       interpreter, words, levels, read, fault
     with
     | Error e ->
       { report with verdict = "taken, but not run"; detail = Error.to_string_hum e }
     | Ok (interpreter, words, levels, read, fault) ->
       let last_edge =
         Array.foldi levels ~init:0 ~f:(fun c last l ->
           if c > 0 && l <> levels.(c - 1) then c else last)
       in
       { report with
         verdict = "taken"
       ; detail =
           String.concat
             ~sep:"\n"
             ([ (if t.starts_on_edge
                 then
                   sprintf
                     "%d steps, %d bits read a frame, each frame from an edge on %s"
                     (List.length t.steps)
                     t.read
                     (Option.value t.input ~default:"")
                 else
                   sprintf
                     "%d steps, %d host bits a %s, words of %s bits"
                     (List.length t.steps)
                     t.bits
                     (if t.while_host then "pass" else "frame")
                     (List.map t.words ~f:Int.to_string |> String.concat ~sep:" and "))
              ; "interpreter: "
                ^ Analyser.Verdict.to_string (Timed_program.verdict interpreter)
                ^ ", certified once with the data memory free"
              ; "faults: " ^ Sexp.to_string (Machine.Fault.sexp_of_t fault)
              ]
              @ List.map t.limits ~f:(fun (l : Wavedrom.Limit.t) ->
                sprintf "edge %s: %d ns, holds" l.edge l.ns)
              @
              if t.read > 0
              then
                [ (if t.starts_on_edge
                   then "read from the frames on the line: "
                   else "read (inputs held low): ")
                  ^ (List.map read ~f:(fun w ->
                       Wavedrom.read_bits t w
                       |> List.map ~f:(fun b -> if b then '1' else '0')
                       |> String.of_list)
                     |> String.concat ~sep:" ")
                ]
              else [])
       ; words = List.map words ~f:(sprintf "0x%04x") |> String.concat ~sep:" "
       ; levels =
           Array.sub levels ~pos:0 ~len:(Int.min (Array.length levels) (last_edge + 200))
       })
;;

let () =
  let check source period single_capture_edge capture_pin capture_falling =
    let report =
      check
        ?period:(Js.Opt.to_option period)
        ~single_capture_edge:(Js.to_bool single_capture_edge)
        ~capture_pin
        ~capture_falling:(Js.to_bool capture_falling)
        (Js.to_string source)
    in
    Js.Unsafe.obj
      [| "verdict", Js.Unsafe.inject (Js.string report.verdict)
       ; "detail", Js.Unsafe.inject (Js.string report.detail)
       ; "listing", Js.Unsafe.inject (Js.string report.listing)
       ; "rows", Js.Unsafe.inject (Js.string report.rows)
      |]
  in
  let check_pio source spec =
    let report = check_pio ~source:(Js.to_string source) ~spec:(Js.to_string spec) in
    Js.Unsafe.obj
      [| "verdict", Js.Unsafe.inject (Js.string report.verdict)
       ; "report", Js.Unsafe.inject (Js.string report.report)
      |]
  in
  let run_diagram source frames =
    let report =
      run_diagram ~source:(Js.to_string source) ~frames:(Js.to_string frames)
    in
    Js.Unsafe.obj
      [| "verdict", Js.Unsafe.inject (Js.string report.verdict)
       ; "detail", Js.Unsafe.inject (Js.string report.detail)
       ; "steps", Js.Unsafe.inject (Js.string report.steps)
       ; "words", Js.Unsafe.inject (Js.string report.words)
       ; ( "lanes"
         , Js.Unsafe.inject (Js.array (Array.of_list_map report.lanes ~f:Js.string)) )
       ; "levels", Js.Unsafe.inject (Js.array report.levels)
       ; "cycleNs", Js.Unsafe.inject cycle_ns
      |]
  in
  let mutate source percent =
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
      Diagram_mutation.run diagram ~percent
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
  Js.export
    "protocolEmulator"
    (Js.Unsafe.obj
       [| "check", Js.Unsafe.inject (Js.wrap_callback check)
        ; ( "examples"
          , Js.Unsafe.inject
              (Js.array
                 (Array.of_list_map Example.all ~f:(fun (name, source) ->
                    Js.array [| Js.string name; Js.string source |]))) )
        ; "checkPio", Js.Unsafe.inject (Js.wrap_callback check_pio)
        ; "runDiagram", Js.Unsafe.inject (Js.wrap_callback run_diagram)
        ; "mutateDiagram", Js.Unsafe.inject (Js.wrap_callback mutate)
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
