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

module Sim_report = struct
  type t =
    { error : string
    ; lanes : string list
    ; levels : int array
    ; edges : int array
    ; releases : int array
    ; waits : (int * string * string) list
    ; summary : string
    }
end

let fault_names { Machine.Fault.underflow; overflow; missed_deadline; decode } =
  List.filter_map
    [ "underflow", underflow
    ; "overflow", overflow
    ; "missed_deadline", missed_deadline
    ; "decode", decode
    ]
    ~f:(fun (name, set) -> Option.some_if set name)
;;

(* [now - t] on entry, as the signed 24-bit number the deadline wait compares *)
let phase ~now ~t =
  let modulus = 1 lsl Isa.timer_bits in
  let d = (now - t) land (modulus - 1) in
  if d >= modulus / 2 then d - modulus else d
;;

let comma_list text parse =
  String.split text ~on:','
  |> List.map ~f:String.strip
  |> List.filter ~f:(Fn.non String.is_empty)
  |> List.map ~f:parse
;;

(* the host writes in order, stopping at the first word not yet due or with no room *)
let rec write_tx machine (tx : Machine_trace.Tx.t list) ~cycle =
  match tx with
  | word :: rest when word.cycle <= cycle ->
    (match Machine.write_tx machine word.word with
     | Ok machine -> write_tx machine rest ~cycle
     | Error _ -> machine, tx)
  | _ -> machine, tx
;;

let rec drain_rx machine =
  match Machine.read_rx machine with
  | None -> machine
  | Some (_, machine) -> drain_rx machine
;;

(* The model run as the host would drive it: [tx] words written as room allows, [inputs]
   held from their cycle, the rx fifo emptied each cycle. Each instruction that makes a
   pin edge is checked against the analyser's window for it, at the first issue of each
   visit, and each deadline wait's releases are recorded. *)
let simulate ?period ?period_floor ~single_capture_edge ~config ~tx ~inputs ~cycles source
  : Sim_report.t
  =
  let failed e =
    { Sim_report.error = Error.to_string_hum e
    ; lanes = []
    ; levels = [||]
    ; edges = [||]
    ; releases = [||]
    ; waits = []
    ; summary = ""
    }
  in
  match
    let open Or_error.Let_syntax in
    let%bind program = Asm.assemble source in
    let%bind words = Asm.Program.words program in
    let config = Asm.Program.configure program config in
    let%bind machine = Machine.create ~config ~program:words in
    let%bind tx =
      Or_error.try_with (fun () -> comma_list tx Machine_trace.Tx.of_string)
    in
    let%map inputs =
      Or_error.try_with (fun () -> comma_list inputs Machine_trace.Input.of_string)
    in
    let rows =
      Analyser.analyse
        ?period
        ?period_floor
        ~single_capture_edge
        ~config
        program.instructions
      |> Array.of_list
    in
    program, machine, tx, inputs, rows
  with
  | Error e -> failed e
  | Ok (program, machine, tx, inputs, rows) ->
    let cycles = Int.max 1 (Int.min cycles 20_000) in
    let input_at cycle =
      List.filter inputs ~f:(fun (input : Machine_trace.Input.t) -> input.cycle <= cycle)
      |> List.stable_sort ~compare:(fun (a : Machine_trace.Input.t) b ->
        Int.compare a.cycle b.cycle)
      |> List.fold ~init:0 ~f:(fun level (input : Machine_trace.Input.t) ->
        if input.level
        then level lor (1 lsl input.pin)
        else level land lnot (1 lsl input.pin))
    in
    let is_deadline_wait pc =
      match List.nth program.instructions pc with
      | Some (Op { op = Wait (Deadline _); _ }) -> true
      | _ -> false
    in
    let levels = Array.create ~len:cycles 0 in
    let machine, _, _, edges, releases, faults =
      List.fold
        (List.range 0 cycles)
        ~init:(machine, tx, None, [], [], [])
        ~f:(fun (machine, tx, last, edges, releases, faults) cycle ->
          let machine, tx = write_tx machine tx ~cycle in
          let inputs = input_at cycle in
          let issues = (not machine.halted) && machine.stall = 0 in
          let pc = machine.pc in
          let next = Machine.step machine ~inputs in
          levels.(cycle) <- Machine.pins next ~inputs;
          let first_issue = issues && not (Option.equal Int.equal last (Some pc)) in
          let edges =
            match
              if first_issue && pc < Array.length rows then Some rows.(pc) else None
            with
            | Some { phase = window; pin_event = Some (Edge _); _ } ->
              let here = phase ~now:machine.now ~t:machine.t in
              let band =
                match window with
                | { Interval.lo = Some lo; hi = Some hi } ->
                  [ cycle - here + lo; cycle - here + hi ]
                | _ -> [ -1; -1 ]
              in
              ((cycle :: pc :: band) @ [ Bool.to_int (Interval.contains window here) ])
              :: edges
            | _ -> edges
          in
          let releases =
            if issues && is_deadline_wait pc && next.pc <> pc
            then [ cycle; pc ] :: releases
            else releases
          in
          let faults =
            if Machine.Fault.equal next.fault Machine.Fault.none
               || not (Machine.Fault.equal machine.fault Machine.Fault.none)
            then faults
            else
              sprintf
                "%s at cycle %d, pc %d"
                (fault_names next.fault |> String.concat ~sep:" ")
                cycle
                pc
              :: faults
          in
          let last = if issues then Some pc else last in
          drain_rx next, tx, last, edges, releases, faults)
    in
    ignore (machine : Machine.t);
    let edges = List.rev edges in
    let outside = List.count edges ~f:(fun e -> List.last_exn e = 0) in
    let driven = List.map inputs ~f:(fun (input : Machine_trace.Input.t) -> input.pin) in
    let lanes =
      List.filter (List.range 0 Isa.pin_space) ~f:(fun pin ->
        List.mem driven pin ~equal:Int.equal
        || Array.exists levels ~f:(fun l -> (l lsr pin) land 1 = 1))
      |> fun lanes -> if List.is_empty lanes then [ Isa.first_output_pin ] else lanes
    in
    let masks =
      Array.map levels ~f:(fun l ->
        List.foldi lanes ~init:0 ~f:(fun i m pin -> m lor (((l lsr pin) land 1) lsl i)))
    in
    { error = ""
    ; lanes = List.map lanes ~f:Machine_trace.pin_name
    ; levels = masks
    ; edges = Array.of_list (List.concat edges)
    ; releases = Array.of_list (List.concat (List.rev releases))
    ; waits =
        List.filter_map (Array.to_list rows) ~f:(fun r ->
          Option.map r.slack ~f:(fun slack ->
            ( r.pc
            , Asm.to_string ~side_set_count:program.side_set_count r.instruction
            , Interval.to_string slack )))
    ; summary =
        String.concat
          ~sep:"\n"
          ([ sprintf
               "%d cycles run, %d edges checked against the analyser's windows, %d \
                outside"
               cycles
               (List.length edges)
               outside
           ]
           @
           match List.rev faults with
           | [] -> [ "faults: none" ]
           | faults -> List.map faults ~f:(fun f -> "fault: " ^ f))
    }
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
