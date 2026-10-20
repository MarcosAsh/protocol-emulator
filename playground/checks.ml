open! Core
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

let check ?period ?period_floor ~single_capture_edge ~config source : Report.t =
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
    let rows =
      Analyser.analyse
        ?period
        ?period_floor
        ~single_capture_edge
        ~config:(Asm.Program.configure program config)
        program.instructions
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
    (match
       Timed_program.check ?period ?period_floor ~single_capture_edge ~config source
     with
     | Error { faults = _; verdict = None; error } ->
       { (refused "analyser" error) with listing = report.listing; rows = report.rows }
     | Error { faults = _; verdict = Some verdict; error } ->
       { report with
         verdict = "refused by the kernel"
       ; detail =
           Analyser.Verdict.to_string verdict
           ^ ", but the kernel rejects the analyser's rows\n"
           ^ Error.to_string_hum error
       }
     | Ok timed ->
       { report with
         verdict = "accepted"
       ; detail =
           Analyser.Verdict.to_string (Timed_program.verdict timed)
           ^ "\nkernel: accepted, so no deadline is missed by the step lemma"
       })
;;

module Pio_report = struct
  type t =
    { verdict : string
    ; report : string
    }
end

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

let cycle_ns ~clock_hz = 1e9 /. Float.of_int clock_hz

let step_listing (t : Wavedrom.t) =
  let cycle_ns = cycle_ns ~clock_hz:t.clock_hz in
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
      "%2d  %-26s %-20s %-10s %6d cycles %10.1f ns"
      i
      s.name
      outputs
      (Sexp.to_string (Tables.Kind.sexp_of_t s.kind))
      s.cycles
      (Float.of_int s.cycles *. cycle_ns))
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

let run_diagram ~source ~frames ~clock_hz : Diagram_report.t =
  let at = Wavedrom.clock_name clock_hz in
  let empty =
    { Diagram_report.verdict = ""
    ; detail = ""
    ; steps = ""
    ; words = ""
    ; lanes = []
    ; levels = [||]
    }
  in
  match Wavedrom.of_string ~clock_hz source with
  | Error e ->
    { empty with
      verdict = "refused"
    ; detail = [%string "at %{at}: %{Error.to_string_hum e}"]
    }
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
                sprintf "edge %s: %d cycles, %.1f ns, holds at %s" l.edge l.cycles l.ns at)
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
