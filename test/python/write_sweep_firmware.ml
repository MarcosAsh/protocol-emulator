open! Core
open Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* Act 2's sweep: every library firmware engine 1 can stamp, its watched output moved to
   wire 20 and its other outputs beside it, with a stimulus and, for every edge from its
   frame's first, the cycle the model of both engines gives and the interval the kernel's
   rows allow along the model's path. Each is checked at the period it runs at, as the
   command line does. *)

let wire = Swept.wire

(* The most cycles the host may take from one poll to the next: 150 us at 48 MHz, about
   twice the Pico's drain. A burst of more edges than engine 1's fifo holds must take
   twice this over every [fifo_depth + 1] of them. *)
let poll = 7200

(* act 2's logger, which echoes the wire on OUT0 for the analyser *)
let logger_config = { Program_config.default with jmp_pin = wire; autopush = true }
let logger_words = In_channel.read_all "../edge_logger_echo.asm" |> Firmware.assemble

module Edge = struct
  type t =
    { at : int (** The cycle it shows, by engine 0's clock. *)
    ; pc : int
    ; t : int (** The deadline when it issued. *)
    ; first : bool (** The first of a frame. *)
    ; stamp : int
    }
end

let timer_mask = (1 lsl Isa.timer_bits) - 1

let signed d =
  let d = d land timer_mask in
  if d >= 1 lsl (Isa.timer_bits - 1) then d - (1 lsl Isa.timer_bits) else d
;;

let level (m : Machine.t) = (m.pin_out lsr wire) land 1

(* A burst is over once engine 0 has its words and the wire has not moved for as long as a
   stamp can tell apart. *)
let quiet = 1 lsl 16

(* The model of both engines from the logger's start, as the sweep runs them: the setup's
   edges, then each burst's, a burst pushed once the one before is quiet, each with the
   cycle it began. A frame starts at a burst's first edge and at the first after an
   anchor, a write of [t] from the clock or the capture: between frames the host's timing
   decides. *)
let simulate ~config ~words ~preamble ~bursts =
  let instructions =
    Array.of_list words
    |> Array.map ~f:(fun w ->
      Isa.of_word ~side_set_count:config.Program_config.side_set_count w |> ok_exn)
  in
  let anchors pc =
    pc < Array.length instructions
    &&
    match instructions.(pc) with
    | Op { op = Mov { dest = T; _ }; _ } | Op { op = Out { dest = T; _ }; _ } -> true
    | _ -> false
  in
  (* the host starts the logger first, so it is waiting by engine 0's first edge *)
  let logger =
    Fn.apply_n_times
      ~n:16
      (fun m -> Machine.step m ~inputs:0)
      (Machine.create ~config:logger_config ~program:logger_words |> ok_exn)
  in
  let engine =
    List.fold
      preamble
      ~init:(Machine.create ~config ~program:words |> ok_exn)
      ~f:(fun m w -> Machine.write_tx m w |> ok_exn)
  in
  let system = ref (System.create [ engine; logger ]) in
  let stamps = Queue.create () in
  let edges = Queue.create () in
  let first = ref true in
  let since_edge = ref 0 in
  let step () =
    let before = List.hd_exn !system.engines in
    let next = System.step !system ~pads:0 in
    let after = List.hd_exn next.engines in
    let issued = before.stall = 0 && not before.halted in
    Int.incr since_edge;
    if level before <> level after
    then (
      if not issued then raise_s [%message "BUG: an edge with no issue" (before.pc : int)];
      Queue.enqueue edges (before.pc, after.now, before.t, !first);
      first := false;
      since_edge := 0);
    if issued && anchors before.pc then first := true;
    (* the host takes every stamp *)
    let rec drain (m : Machine.t) =
      match Machine.read_rx m with
      | Some (stamp, m) ->
        Queue.enqueue stamps stamp;
        drain m
      | None -> m
    in
    system := System.update next 1 ~f:drain
  in
  let run_until_quiet () =
    since_edge := 0;
    let steps = ref 0 in
    while
      !since_edge < quiet || not (List.is_empty (List.hd_exn !system.engines).tx_fifo)
    do
      Int.incr steps;
      if !steps > 100 * quiet then raise_s [%message "never quiet"];
      step ()
    done
  in
  let now () = (List.hd_exn !system.engines).now in
  let setup =
    let start = now () in
    run_until_quiet ();
    start, Queue.length edges
  in
  let pushed =
    List.map bursts ~f:(fun burst ->
      let start = now () in
      let before = Queue.length edges in
      system
      := System.update !system 0 ~f:(fun m ->
           List.fold burst ~init:m ~f:(fun m w -> Machine.write_tx m w |> ok_exn));
      first := true;
      run_until_quiet ();
      start, Queue.length edges - before)
  in
  List.iteri !system.engines ~f:(fun engine (m : Machine.t) ->
    if not (Machine.Fault.equal m.fault Machine.Fault.none)
    then raise_s [%message "faulted" (engine : int) (m.fault : Machine.Fault.t)]);
  let edges = Queue.to_list edges in
  let stamps = Queue.to_list stamps in
  if List.length stamps <> List.length edges
  then
    raise_s
      [%message
        "the logger missed edges"
          ~edges:(List.length edges : int)
          ~stamps:(List.length stamps : int)];
  let edges =
    List.map2_exn edges stamps ~f:(fun (pc, at, t, first) stamp ->
      { Edge.at; pc; t; first; stamp })
  in
  (* the logger stamps each edge as many cycles after it shows *)
  (match
     List.map edges ~f:(fun e -> (e.stamp - e.at) land 0xffff)
     |> List.dedup_and_sort ~compare:Int.compare
   with
   | [] | [ _ ] -> ()
   | latencies ->
     raise_s [%message "the logger cannot follow the wire" (latencies : int list)]);
  let rec split edges = function
    | [] -> []
    | (start, n) :: rest ->
      let #(burst, edges) = List.split_n edges n in
      (start, burst) :: split edges rest
  in
  split edges (setup :: pushed)
;;

(* Where the kernel's rows put an edge on the wire from the deadline it issued at. *)
let edge_at ~(config : Program_config.t) ~rows (e : Edge.t) =
  let side =
    List.init config.side_set_count ~f:(fun j ->
      (config.side_set_base + j) % Isa.pin_space)
    |> List.exists ~f:(Int.equal wire)
  in
  match side, Map.find rows e.pc with
  | true, Some { Analyser.Row.side_event = Some { at; changes = true }; _ } -> at
  | false, Some { Analyser.Row.pin_event = Some (Edge at); _ } -> at
  | _ -> raise_s [%message "BUG: the rows place no edge here" (e.pc : int)]
;;

(* Each edge's cycles from its frame's first: the model's, and the least and most the rows
   allow along the model's path, [None] where they bound nothing. *)
let frames ~config ~rows edges =
  let rec group = function
    | [] -> []
    | (e : Edge.t) :: rest ->
      let frame, rest = List.split_while rest ~f:(fun (e : Edge.t) -> not e.first) in
      (e :: frame) :: group rest
  in
  group edges
  |> List.map ~f:(fun frame ->
    let start = List.hd_exn frame in
    let from = edge_at ~config ~rows start in
    List.map frame ~f:(fun e ->
      let at = edge_at ~config ~rows e in
      let dt = signed (e.t - start.t) in
      let predicted = signed (e.at - start.at) in
      let lo = Option.map2 at.lo from.hi ~f:(fun lo hi -> dt + lo - hi) in
      let hi = Option.map2 at.hi from.lo ~f:(fun hi lo -> dt + hi - lo) in
      if not (Interval.contains { lo; hi } predicted)
      then
        raise_s [%message "BUG: the model leaves the rows" (e.pc : int) (predicted : int)];
      predicted, lo, hi))
;;

(* The host polls at most [poll] cycles apart, so nine edges must take twice that unless
   the fifo holds them all; a stamp is 16 bits, so a gap must fit. *)
let check_burst name (burst : Edge.t list) =
  let at = Array.of_list_map burst ~f:(fun e -> e.at) in
  let depth = Machine.fifo_depth in
  Array.iteri at ~f:(fun k a ->
    if k > 0 && signed (a - at.(k - 1)) >= 1 lsl 16
    then raise_s [%message "a gap past a stamp" name (k : int)];
    if k + depth < Array.length at && signed (at.(k + depth) - a) < 2 * poll
    then raise_s [%message "too fast for the host" name (k : int)])
;;

let fields config =
  Engine.Config.map2
    Engine.Config.port_names
    (Engine.Config.of_program_config config)
    ~f:(fun name value -> name, Bits.to_unsigned_int value)
  |> Engine.Config.to_list
;;

(* items, a comma after each, wrapped at 88 columns *)
let print_items indent items =
  let flush line = if not (String.is_empty line) then printf "%s%s\n" indent line in
  List.fold items ~init:"" ~f:(fun line item ->
    let item = item ^ "," in
    if String.is_empty line
    then item
    else if String.length indent + String.length line + 1 + String.length item > 88
    then (
      flush line;
      item)
    else line ^ " " ^ item)
  |> flush
;;

let hex = List.map ~f:(sprintf "0x%04X")
let inline items = "[" ^ String.concat ~sep:", " items ^ "]"

(* the fields where [config] is not [Program_config.default], as a dict *)
let print_changes indent config =
  let changes =
    List.filter_map
      (List.zip_exn (fields Program_config.default) (fields config))
      ~f:(fun ((_, default), (field, value)) ->
        Option.some_if (value <> default) (sprintf "\"%s\": %d" field value))
  in
  let line = String.concat ~sep:", " changes in
  if String.length indent + String.length line + 12 <= 88
  then printf "%s\"config\": {%s},\n" indent line
  else (
    printf "%s\"config\": {\n" indent;
    print_items (indent ^ "    ") changes;
    printf "%s},\n" indent)
;;

let edge (predicted, lo, hi) =
  match lo, hi with
  | Some lo, Some hi when lo = predicted && hi = predicted -> Int.to_string predicted
  | _ ->
    let bound = Option.value_map ~default:"None" ~f:Int.to_string in
    sprintf "(%d, %s, %s)" predicted (bound lo) (bound hi)
;;

let print_swept { Swept.name; watch; on_wire; period; bursts } =
  let (c : Certified.t) = Library.find_certified_exn name in
  let timed =
    Timed_program.of_source_exn
      ?period
      ~single_capture_edge:c.single_capture_edge
      ~config:(on_wire c.config)
      c.source
  in
  let config = Timed_program.config timed in
  let rows =
    Timed_program.rows timed
    |> List.map ~f:(fun (r : Analyser.Row.t) -> r.pc, r)
    |> Int.Map.of_alist_exn
  in
  (* the pins the run writes go low first, as the model starts them *)
  let park =
    Firmware.assemble
      (if config.side_set_count = 0
       then "    mov pins, null\n    halt"
       else
         sprintf
           "    .side_set %d\n    mov pins, null side 0\n    halt side 0"
           config.side_set_count)
  in
  let preamble = Option.to_list period in
  let (setup_start, setup), runs =
    match simulate ~config ~words:(Timed_program.words timed) ~preamble ~bursts with
    | setup :: runs -> setup, runs
    | [] -> raise_s [%message "BUG: no setup"]
  in
  check_burst name setup;
  List.iter runs ~f:(fun (_, edges) -> check_burst name edges);
  (* from a push to its last edge, which bounds how long the host waits *)
  let cycles start edges =
    List.last edges
    |> Option.value_map ~default:0 ~f:(fun (e : Edge.t) -> signed (e.at - start))
  in
  printf "    {\n        \"name\": \"%s\",\n        \"watch\": \"%s\",\n" name watch;
  print_changes "        " config;
  print_string "        \"words\": [\n";
  print_items "            " (hex (Timed_program.words timed));
  printf "        ],\n        \"park\": %s,\n" (inline (hex park));
  printf "        \"preamble\": %s,\n" (inline (List.map preamble ~f:Int.to_string));
  printf
    "        \"setup\": {\"edges\": %d, \"cycles\": %d},\n"
    (List.length setup)
    (cycles setup_start setup);
  print_string "        \"bursts\": [\n";
  List.iter2_exn bursts runs ~f:(fun burst (start, edges) ->
    printf
      "            {\"words\": %s, \"cycles\": %d, \"frames\": [\n"
      (inline (hex burst))
      (cycles start edges);
    List.iter (frames ~config ~rows edges) ~f:(fun frame ->
      print_string "                [\n";
      print_items "                    " (List.map frame ~f:edge);
      print_string "                ],\n");
    print_string "            ]},\n");
  print_string "        ],\n    },\n"
;;

let () =
  let names = List.map Swept.all ~f:(fun s -> s.name) @ List.map Swept.not_swept ~f:fst in
  List.iter
    (Library.stamped :: (Library.certified @ Library.time_triggered))
    ~f:(fun { name; _ } ->
      if not (List.mem names name ~equal:String.equal)
      then raise_s [%message "neither swept nor said why not" name]);
  print_string
    "# Written by test/python/write_sweep_firmware.ml; `dune promote` after a change.\n\
     # Act 2's sweep: each firmware of test/certified.ml that engine 1 can stamp on wire\n\
     # 20, as a config's changes from DEFAULTS, words, the words that park its pins low\n\
     # first, and a stimulus. Each edge is its cycles from its frame's first: an int\n\
     # where the kernel's rows along the model's path allow that cycle alone, else (the\n\
     # model's, the least and the most they allow), None where unbounded.\n";
  printf "\n# cycles the host may take between polls, 150 us at 48 MHz\nPOLL = %d\n" poll;
  print_string "\nDEFAULTS = {\n";
  print_items
    "    "
    (List.map (fields Program_config.default) ~f:(fun (field, value) ->
       sprintf "\"%s\": %d" field value));
  print_string "}\n\nLOGGER = {\n";
  print_changes "    " logger_config;
  print_string "    \"words\": [\n";
  print_items "        " (hex logger_words);
  print_string "    ],\n}\n\nSWEPT = [\n";
  List.iter Swept.all ~f:print_swept;
  print_string "]\n\nNOT_SWEPT = [\n";
  List.iter Swept.not_swept ~f:(fun (name, why) ->
    printf "    (\"%s\", \"%s\"),\n" name why);
  print_string "]\n"
;;
