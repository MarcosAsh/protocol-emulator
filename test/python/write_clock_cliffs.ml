open! Core
open Protocol_emulator
open Protocol_emulator_test

let py_int = Option.value_map ~default:"None" ~f:Int.to_string
let py_str = Option.value_map ~default:"None" ~f:(sprintf "%S")

(* the image and load a prediction is of *)
let words_md5 (bench : Bench.t) =
  Timed_program.words (Bench.timed bench) @ Option.to_list bench.load
  |> List.map ~f:(sprintf "%04X")
  |> String.concat
  |> Md5.digest_string
  |> Md5.to_hex
;;

let () =
  print_string
    "# Written by test/python/write_clock_cliffs.ml; `dune promote` after a change, then\n\
     # reseal: sha256sum python/clock_cliffs.py > test/clock_cliffs.sha256.\n\
     # The clocks each bench firmware stays certified at, image and load unchanged\n\
     # (test/clock_window.ml). The certificate is in cycles; only the ns move. LIMITS has\n\
     # each datasheet limit's cliff: a least holds up to highest_hz, a most from\n\
     # lowest_hz, exact to the hertz. A kernel bound may sit below the widths a run\n\
     # shows, so a wire can pass past its cliff; a run bound is the run's own width.\n\
     # WINDOWS is each firmware's intersection, the limit that fails a hertz past each\n\
     # end. words_md5 is md5 of the image's words, then its load if any, each as %04X.\n";
  let benches =
    List.filter (Library.bench @ [ Uart.log ]) ~f:(fun (bench : Bench.t) ->
      List.exists Library.limits ~f:(fun l -> String.equal l.firmware bench.name))
  in
  print_string "\nLIMITS = [\n";
  List.iter benches ~f:(fun bench ->
    List.iter (Datasheet.cliffs Library.limits bench) ~f:(fun (limit, bound, cliff) ->
      let lowest, highest =
        match cliff with
        | Never -> raise_s [%message "BUG: a limit that holds at no clock"]
        | Always -> None, None
        | Up_to hz -> None, Some hz
        | From hz -> Some hz, None
      in
      printf
        "    {\"firmware\": %S, \"limit\": %S, \"bound\": %S, \"cycles\": %s, \
         \"lowest_hz\": %s, \"highest_hz\": %s},\n"
        bench.name
        (Clock_window.limit_name limit)
        (match limit.bound with
         | Kernel _ -> "kernel"
         | Run _ -> "run")
        (py_int bound)
        (py_int lowest)
        (py_int highest)));
  print_string "]\n\nWINDOWS = [\n";
  let images =
    List.map benches ~f:(fun (bench : Bench.t) -> bench.name, words_md5 bench)
  in
  List.iter
    (Clock_window.all () @ Clock_window.diagrams ~dir:"../diagrams")
    ~f:(fun (t : Clock_window.t) ->
      let hz (e : Clock_window.End.t option) = py_int (Option.map e ~f:(fun e -> e.hz))
      and limit (e : Clock_window.End.t option) =
        py_str (Option.map e ~f:(fun e -> e.limit))
      in
      printf
        "    {\"firmware\": %S, \"words_md5\": %s, \"shipped_hz\": %d,\n\
        \     \"lowest_hz\": %s, \"lowest_limit\": %s,\n\
        \     \"highest_hz\": %s, \"highest_limit\": %s},\n"
        t.firmware
        (py_str (List.Assoc.find images t.firmware ~equal:String.equal))
        t.shipped_hz
        (hz t.lowest)
        (limit t.lowest)
        (hz t.highest)
        (limit t.highest));
  print_string "]\n"
;;
