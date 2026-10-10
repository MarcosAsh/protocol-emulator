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
        ; ( "pioExamples"
          , Js.Unsafe.inject
              (Js.array
                 (Array.of_list_map Pio_example.all ~f:(fun (name, source, spec) ->
                    Js.array [| Js.string name; Js.string source; Js.string spec |]))) )
       |])
;;
