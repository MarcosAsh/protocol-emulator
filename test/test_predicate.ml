open! Core
open Protocol_emulator

let sda = 0
let scl = 1

let i2c_start =
  Predicate.Edge_while
    { edge = { pin = sda; rising = false }; guard = { pin = scl; high = true } }
;;

let scl_rise = Predicate.Edge { pin = scl; rising = true }

let%expect_test "an i2c start compiles, with its latency certified" =
  let firmware = Predicate.compile ~latency:10 i2c_start |> ok_exn in
  print_string firmware.source;
  print_s [%sexp (firmware.certificate : Predicate.Certificate.t)];
  [%expect
    {|
    ; pin 0 falls while pin 1 is high: pin 5 pulses 10 cycles on
        set p, 6            ; the budget
        set pins, 0
    watch:
        wait fall pin 0     ; the event
        jmp !pin, watch     ; pin 1 low: no match
        mov t, now          ; the anchor
        add t, p
        wait t              ; pads every match to the latency
        set pins, 1         ; the verdict
        set pins, 0
        jmp watch
    ((latency 10) (jitter 0)
     (sampling
      (Waits (guard_at (1)) (blind_after_match 13) (blind_after_reject (2))))
     (verdict_pcs (7)))
    |}]
;;

let compiled predicate ~latency =
  Predicate.compile predicate ~latency
  |> Or_error.map ~f:(fun (f : Predicate.Firmware.t) -> f.certificate.latency)
;;

let%expect_test "a latency one cycle short of the code is refused" =
  List.iter
    [ i2c_start, [ 5; 6 ]; scl_rise, [ 2; 3; 4 ] ]
    ~f:(fun (predicate, latencies) ->
      List.iter latencies ~f:(fun latency ->
        print_s [%message (latency : int) (compiled predicate ~latency : int Or_error.t)]));
  [%expect
    {|
    ((latency 5)
     ("compiled predicate ~latency"
      (Error
       "latency 5 exceeded by 1 cycle: pin 0 falls while pin 1 is high needs 6")))
    ((latency 6) ("compiled predicate ~latency" (Ok 6)))
    ((latency 2)
     ("compiled predicate ~latency"
      (Error "latency 2 exceeded by 2 cycles: pin 1 rises needs 4")))
    ((latency 3)
     ("compiled predicate ~latency"
      (Error "latency 3 exceeded by 1 cycle: pin 1 rises needs 4")))
    ((latency 4) ("compiled predicate ~latency" (Ok 4)))
    |}]
;;

let%expect_test "pins that cannot be read, or a budget too long for p, are refused" =
  List.iter
    [ Predicate.Edge { pin = 5; rising = true }, 10
    ; ( Edge_while { edge = { pin = 0; rising = true }; guard = { pin = 11; high = true } }
      , 10 )
    ; scl_rise, 70_000
    ]
    ~f:(fun (predicate, latency) ->
      print_s [%message (compiled predicate ~latency : int Or_error.t)]);
  [%expect
    {|
    ("compiled predicate ~latency"
     (Error "event pin 5 is not an input, a bidirectional pin or a wire"))
    ("compiled predicate ~latency"
     (Error "guard pin 11 is not an input, a bidirectional pin or a wire"))
    ("compiled predicate ~latency"
     (Error "latency 70000 needs a budget of 69998, above what p holds"))
    |}];
  (* the core never drives a bidirectional pin it has not set the direction of *)
  List.iter [ 11; 12; 4 ] ~f:(fun verdict_pin ->
    print_s
      [%message
        (verdict_pin : int)
          ~_:
            (Predicate.compile ~verdict_pin ~latency:10 scl_rise
             |> Or_error.map ~f:(fun (f : Predicate.Firmware.t) -> f.config.set_base)
             : int Or_error.t)]);
  [%expect
    {|
    ((verdict_pin 11) (Ok 11))
    ((verdict_pin 12) (Error "verdict pin 12 is not an output pin"))
    ((verdict_pin 4) (Error "verdict pin 4 is not an output pin"))
    |}]
;;

let verdict_bit (firmware : Predicate.Firmware.t) (machine : Machine.t) =
  (machine.pin_out lsr firmware.config.set_base) land 1
;;

(* The cycles in which the verdict issues: the pin shows it after that step. *)
let machine_verdicts (firmware : Predicate.Firmware.t) samples =
  let words = Asm.Program.words firmware.program |> ok_exn in
  let machine = Machine.create ~config:firmware.config ~program:words |> ok_exn in
  let machine =
    Option.fold firmware.budget_from_host ~init:machine ~f:(fun machine budget ->
      Machine.write_tx machine budget |> ok_exn)
  in
  List.foldi
    samples
    ~init:(machine, 0, [])
    ~f:(fun cycle (machine, was, verdicts) inputs ->
      let machine = Machine.step machine ~inputs in
      let level = verdict_bit firmware machine in
      machine, level, if was = 0 && level = 1 then cycle :: verdicts else verdicts)
  |> fun (_, _, verdicts) -> List.rev verdicts
;;

(* The predicate read off the samples, blind where the certificate says, each match a
   verdict [latency] cycles on. *)
let expected_verdicts (firmware : Predicate.Firmware.t) predicate samples =
  let samples = Array.of_list samples in
  let bit cycle pin = (samples.(cycle) lsr pin) land 1 = 1 in
  let latency = firmware.certificate.latency in
  let guard_at, blind_after_match, blind_after_reject =
    match firmware.certificate.sampling with
    | Waits { guard_at; blind_after_match; blind_after_reject } ->
      guard_at, blind_after_match, blind_after_reject
    | Polls _ -> raise_s [%message "polls, not waits"]
  in
  let edge, guard =
    match predicate with
    | Predicate.Edge edge -> edge, None
    | Edge_while { edge; guard } -> edge, Some guard
    | Quiet _ -> raise_s [%message "not an edge"]
  in
  (* the prologue's instructions each take a cycle, the budget being in the fifo *)
  let watching_from =
    List.findi_exn firmware.program.instructions ~f:(fun _ -> function
      | Op { op = Wait (Pin_edge _); _ } -> true
      | _ -> false)
    |> fst
  in
  let _, verdicts =
    Array.foldi samples ~init:(watching_from, []) ~f:(fun cycle (ready, verdicts) _ ->
      let seen =
        cycle >= ready
        && cycle > 0
        && Bool.( <> ) (bit (cycle - 1) edge.pin) (bit cycle edge.pin)
        && Bool.equal (bit cycle edge.pin) edge.rising
      in
      if not seen
      then ready, verdicts
      else (
        let matches =
          match guard, guard_at with
          | Some g, Some at ->
            cycle + at < Array.length samples
            && Bool.equal (bit (cycle + at) g.pin) g.high
          | _ -> true
        in
        if matches
        then cycle + blind_after_match + 1, (cycle + latency) :: verdicts
        else cycle + Option.value_exn blind_after_reject + 1, verdicts))
  in
  List.rev verdicts |> List.filter ~f:(fun v -> v < Array.length samples)
;;

(* Pins 0 and 1 held for a few cycles at a time. *)
let random_samples ?(runs = 60) () =
  let open Quickcheck.Generator.Let_syntax in
  let%map runs =
    List.gen_with_length
      runs
      (Quickcheck.Generator.both (Int.gen_incl 0 3) (Int.gen_incl 1 8))
  in
  List.concat_map runs ~f:(fun (pins, cycles) -> List.init cycles ~f:(fun _ -> pins))
;;

let%expect_test "on the model, every match lands exactly at the certified latency" =
  List.iter
    [ i2c_start, 10; i2c_start, 6; i2c_start, 300; scl_rise, 4; scl_rise, 25 ]
    ~f:(fun (p, l) ->
      let firmware = Predicate.compile p ~latency:l |> ok_exn in
      let matches = ref 0 in
      (* long enough to hold a few matches past the latency *)
      let runs = Int.max 60 (l * 2) in
      Quickcheck.test ~trials:100 (random_samples ~runs ()) ~f:(fun samples ->
        let expected = expected_verdicts firmware p samples in
        matches := !matches + List.length expected;
        [%test_result: int list] (machine_verdicts firmware samples) ~expect:expected);
      print_s
        [%message
          ""
            ~predicate:(Predicate.to_string p : string)
            (l : int)
            ~matches:(!matches : int)]);
  [%expect
    {|
    ((predicate "pin 0 falls while pin 1 is high") (l 10) (matches 544))
    ((predicate "pin 0 falls while pin 1 is high") (l 6) (matches 593))
    ((predicate "pin 0 falls while pin 1 is high") (l 300) (matches 748))
    ((predicate "pin 1 rises") (l 4) (matches 1334))
    ((predicate "pin 1 rises") (l 25) (matches 632))
    |}]
;;

let%expect_test "the engine runs the compiled firmware as the model does" =
  let firmware = Predicate.compile i2c_start ~latency:10 |> ok_exn in
  let samples =
    Quickcheck.random_value ~seed:(`Deterministic "i2c") (random_samples ())
    |> Array.of_list
  in
  let machine =
    Lockstep.lockstep
      ?preload:(Option.map firmware.budget_from_host ~f:List.return)
      ~cycles:(Array.length samples)
      ~config:firmware.config
      ~program:(Asm.Program.words firmware.program |> ok_exn)
      ~inputs:(fun cycle -> samples.(cycle))
      ()
  in
  print_s [%message (machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ("lockstep held" (cycles 260))
    (machine.fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    |}]
;;

let%expect_test "the language reads what to_string writes, and says what it expects" =
  let predicates =
    let open Quickcheck.Generator.Let_syntax in
    let pin = Int.gen_incl 0 27 in
    let edge =
      let%map pin
      and rising = Bool.quickcheck_generator in
      { Predicate.Edge.pin; rising }
    in
    Quickcheck.Generator.union
      [ (edge >>| fun edge -> Predicate.Edge edge)
      ; (let%map edge
         and pin
         and high = Bool.quickcheck_generator in
         Predicate.Edge_while { edge; guard = { pin; high } })
      ; (pin >>| fun pin -> Predicate.Quiet { pin })
      ]
  in
  Quickcheck.test ~trials:200 predicates ~f:(fun predicate ->
    [%test_result: Predicate.t Or_error.t]
      (Predicate.of_string (Predicate.to_string predicate))
      ~expect:(Ok predicate));
  List.iter
    [ "pin  0   rises"; "pin 0 falls while pin one is high"; "sda falls" ]
    ~f:(fun text ->
      print_s [%message text ~_:(Predicate.of_string text : Predicate.t Or_error.t)]);
  [%expect
    {|
    ("pin  0   rises" (Ok (Edge ((pin 0) (rising true)))))
    ("pin 0 falls while pin one is high" (Error "\"one\" is not a pin number"))
    ("sda falls"
     (Error
      "\"sda falls\": expected pin N rises|falls, then perhaps while pin M is high|low, or pin N stops moving"))
    |}]
;;

let quiet = Predicate.Quiet { pin = 2 }

let%expect_test "a pin that stops moving compiles to a poll per level" =
  let firmware = Predicate.compile ~latency:20 quiet |> ok_exn in
  print_string firmware.source;
  print_s [%sexp (firmware.certificate : Predicate.Certificate.t)];
  [%expect
    {|
    ; pin 2 stops moving: pin 5 pulses 20 to 24 cycles on
        set p, 15           ; the budget
        set pins, 0
        jmp pin, high
    .wrap_target
    low:
        mov t, now          ; the anchor
        add t, p
        set x, 2
    low_poll:
        jmp pin, high       ; an edge
        jmp x--, low_poll
        wait t              ; pads the verdict to the latency
        jmp pin, high
        set pins, 1         ; the verdict
        set pins, 0
        wait 1 pin 2 [1]
    high:
        mov t, now          ; the anchor
        add t, p
        set x, 2
    high_poll:
        jmp !pin, low       ; an edge
        jmp x--, high_poll
        wait t              ; pads the verdict to the latency
        jmp !pin, low
        set pins, 1         ; the verdict
        set pins, 0
        wait 0 pin 2 [1]
    .wrap
    ((latency 20) (jitter 4)
     (sampling (Polls (min_run 5) (unseen_before_verdict 2)))
     (verdict_pcs (10 20)))
    |}]
;;

(* The host's budget takes three instructions where [set] took one, moving every pc on. *)
let%expect_test "a budget from the host moves the anchors and verdicts it certifies" =
  List.iter
    [ i2c_start, 300; quiet, 100 ]
    ~f:(fun (predicate, latency) ->
      let firmware = Predicate.compile predicate ~latency |> ok_exn in
      let anchor_pcs =
        List.filter_mapi firmware.program.instructions ~f:(fun pc -> function
          | Op { op = Mov { dest = T; source = Now; _ }; _ } -> Some pc
          | _ -> None)
      in
      print_s
        [%message
          (latency : int)
            ~budget_from_host:(firmware.budget_from_host : int option)
            (anchor_pcs : int list)
            ~certificate:(firmware.certificate : Predicate.Certificate.t)]);
  [%expect {|
    ((latency 300) (budget_from_host (296)) (anchor_pcs (6))
     (certificate
      ((latency 300) (jitter 0)
       (sampling
        (Waits (guard_at (1)) (blind_after_match 303) (blind_after_reject (2))))
       (verdict_pcs (9)))))
    ((latency 100) (budget_from_host (95)) (anchor_pcs (5 15))
     (certificate
      ((latency 100) (jitter 4)
       (sampling (Polls (min_run 5) (unseen_before_verdict 2)))
       (verdict_pcs (12 22)))))
    |}]
;;

let%expect_test "a quiet latency the polls cannot meet is refused" =
  List.iter [ 11; 12; 1000; 5000 ] ~f:(fun latency ->
    print_s [%message (latency : int) (compiled quiet ~latency : int Or_error.t)]);
  [%expect
    {|
    ((latency 11)
     ("compiled quiet ~latency"
      (Error "latency 11 exceeded by 1 cycle: pin 2 stops moving needs 12")))
    ((latency 12) ("compiled quiet ~latency" (Ok 12)))
    ((latency 1000) ("compiled quiet ~latency" (Ok 1000)))
    ((latency 5000)
     ("compiled quiet ~latency"
      (Error "latency 5000 is beyond 31 polls however far apart")))
    |}]
;;

let%expect_test "a quiet layout that samples the wrong pin or level is a bug" =
  let firmware = Predicate.compile quiet ~latency:20 |> ok_exn in
  let check ?(config = firmware.config) source =
    let program = Asm.assemble source |> ok_exn in
    Predicate.For_testing.quiet_layout
      (Asm.Program.configure program config)
      ~pin:2
      (Array.of_list program.instructions)
      ~to_anchor:Isa.jmp_cycles
  in
  let mutated ~from ~into =
    String.substr_replace_first firmware.source ~pattern:from ~with_:into
  in
  List.iter
    [ "as compiled", check firmware.source
    ; "jmp_pin 3", check ~config:{ firmware.config with jmp_pin = 3 } firmware.source
    ; ( "prologue on !pin"
      , check
          (mutated
             ~from:"jmp pin, high\n.wrap_target"
             ~into:"jmp !pin, high\n.wrap_target") )
    ; ( "low poll on !pin"
      , check (mutated ~from:"jmp pin, high       ; an edge" ~into:"jmp !pin, high") )
    ; ( "low final poll on !pin"
      , check
          (mutated ~from:"latency\n    jmp pin, high" ~into:"latency\n    jmp !pin, high")
      )
    ; ( "high poll on pin"
      , check (mutated ~from:"jmp !pin, low       ; an edge" ~into:"jmp pin, low") )
    ; "low level wait for 0", check (mutated ~from:"wait 1 pin 2" ~into:"wait 0 pin 2")
    ; "low level wait on pin 3", check (mutated ~from:"wait 1 pin 2" ~into:"wait 1 pin 3")
    ; "high level wait for 1", check (mutated ~from:"wait 0 pin 2" ~into:"wait 1 pin 2")
    ; ( "level wait without its delay"
      , check (mutated ~from:"wait 0 pin 2 [1]" ~into:"wait 0 pin 2") )
    ]
    ~f:(fun (name, result) -> print_s [%message name ~_:(result : unit Or_error.t)]);
  [%expect
    {|
    ("as compiled" (Ok ()))
    ("jmp_pin 3"
     (Error
      ("BUG: pc 2 enters an anchor but not 2 cycles after a sample of pin 2"
       "BUG: pc 2 enters an anchor but not 2 cycles after a sample of pin 2"
       "BUG: pc 6 enters an anchor but not 2 cycles after a sample of pin 2"
       "BUG: pc 9 enters an anchor but not 2 cycles after a sample of pin 2"
       "BUG: pc 16 enters an anchor but not 2 cycles after a sample of pin 2"
       "BUG: pc 19 enters an anchor but not 2 cycles after a sample of pin 2")))
    ("prologue on !pin"
     (Error
      ("BUG: the anchor at pc 3 is not entered at one level"
       "BUG: the anchor at pc 13 is not entered at one level")))
    ("low poll on !pin"
     (Error "BUG: the anchor at pc 13 is not entered at one level"))
    ("low final poll on !pin"
     (Error "BUG: the anchor at pc 13 is not entered at one level"))
    ("high poll on pin"
     (Error "BUG: the anchor at pc 3 is not entered at one level"))
    ("low level wait for 0"
     (Error "BUG: the anchor at pc 13 is not entered at one level"))
    ("low level wait on pin 3"
     (Error
      "BUG: pc 12 enters an anchor but not 2 cycles after a sample of pin 2"))
    ("high level wait for 1"
     (Error "BUG: the anchor at pc 3 is not entered at one level"))
    ("level wait without its delay"
     (Error
      "BUG: pc 22 enters an anchor but not 2 cycles after a sample of pin 2"))
    |}]
;;

(* The cycles whose sample of [pin] differs from the cycle before's. *)
let changes samples ~pin =
  List.filter_mapi
    (List.zip_exn (List.drop_last_exn samples) (List.tl_exn samples))
    ~f:(fun i (was, is) -> Option.some_if (((was lxor is) lsr pin) land 1 = 1) (i + 1))
;;

(* Runs of the pin at least [min_run] long, some ending before a verdict is due and some
   after, the first as short as any; the pulse sweep below covers the prologue. *)
let quiet_samples ~min_run ~due =
  let open Quickcheck.Generator.Let_syntax in
  let%map runs =
    List.gen_with_length
      30
      (Quickcheck.Generator.union
         [ Int.gen_incl min_run due; Int.gen_incl (due + 1) (2 * due) ])
  in
  List.concat_mapi (min_run :: runs) ~f:(fun i cycles ->
    List.init cycles ~f:(fun _ -> (i % 2) lsl 2))
;;

let polls (firmware : Predicate.Firmware.t) =
  match firmware.certificate.sampling with
  | Polls { min_run; unseen_before_verdict } -> min_run, unseen_before_verdict
  | Waits _ -> raise_s [%message "waits, not polls"]
;;

(* Raises unless each verdict answers the last edge the polls could see, inside the
   window, no edge twice, and every run longer than the window gets one. Gives the
   verdicts. *)
let check_quiet (firmware : Predicate.Firmware.t) samples =
  let { Predicate.Certificate.latency; jitter; _ } = firmware.certificate in
  let _, unseen = polls firmware in
  let due = latency + jitter in
  let length = List.length samples in
  let seen = machine_verdicts firmware samples in
  let changes = changes samples ~pin:2 in
  let answered =
    List.map seen ~f:(fun v ->
      match List.last (List.filter changes ~f:(fun c -> c <= v - unseen)) with
      | None -> None
      | Some edge ->
        if v - edge < latency || v - edge > due
        then raise_s [%message "verdict out of its window" (v : int) (edge : int)];
        Some edge)
    |> List.filter_opt
  in
  if List.contains_dup answered ~compare
  then raise_s [%message "two verdicts for one edge" (answered : int list)];
  List.iteri changes ~f:(fun i edge ->
    let next = Option.value (List.nth changes (i + 1)) ~default:length in
    if next > edge + due && edge + due < length && not (List.mem answered edge ~equal)
    then raise_s [%message "a quiet run without a verdict" (edge : int) (next : int)]);
  List.length seen
;;

let%expect_test "on the model, a quiet verdict comes latency to latency + jitter after \
                 the last edge, and each quiet run gets one"
  =
  List.iter [ 12; 20; 36; 200; 1000 ] ~f:(fun latency ->
    let firmware = Predicate.compile quiet ~latency |> ok_exn in
    let jitter = firmware.certificate.jitter in
    let min_run, _ = polls firmware in
    let verdicts = ref 0 in
    let trials = if latency > 100 then 10 else 100 in
    Quickcheck.test
      ~trials
      (quiet_samples ~min_run ~due:(latency + jitter))
      ~f:(fun samples -> verdicts := !verdicts + check_quiet firmware samples);
    print_s [%message "" (latency : int) (jitter : int) ~verdicts:(!verdicts : int)]);
  [%expect
    {|
    ((latency 12) (jitter 4) (verdicts 2132))
    ((latency 20) (jitter 4) (verdicts 1949))
    ((latency 36) (jitter 4) (verdicts 1768))
    ((latency 200) (jitter 6) (verdicts 157))
    ((latency 1000) (jitter 31) (verdicts 159))
    |}]
;;

(* One pulse off a steady level, or a step, starting at every cycle through the prologue
   and a whole half. A pulse [min_run] long is always seen; one a cycle shorter is missed
   at some start, so [min_run] is tight. *)
let%expect_test "a pulse of min_run is seen from every start, one shorter is not" =
  List.iter [ 12; 20; 36; 200 ] ~f:(fun latency ->
    let firmware = Predicate.compile quiet ~latency |> ok_exn in
    let min_run, _ = polls firmware in
    let due = latency + firmware.certificate.jitter in
    List.iter [ 0; 1 ] ~f:(fun background ->
      let other = 1 - background in
      let samples ~start ~pulse =
        List.init
          (start + pulse + (3 * due))
          ~f:(fun cycle ->
            (if cycle >= start && cycle < start + pulse then other else background) lsl 2)
      in
      let holds samples =
        Result.is_ok (Result.try_with (fun () -> check_quiet firmware samples))
      in
      let starts = List.range 1 (due + 20) in
      let failing pulse =
        List.filter starts ~f:(fun start -> not (holds (samples ~start ~pulse)))
      in
      let step_failing =
        List.filter starts ~f:(fun start -> not (holds (samples ~start ~pulse:(4 * due))))
      in
      print_s
        [%message
          ""
            (latency : int)
            (background : int)
            ~min_run_missed:(failing min_run : int list)
            ~step_missed:(step_failing : int list)
            ~shorter_missed_somewhere:(not (List.is_empty (failing (min_run - 1))) : bool)]));
  [%expect
    {|
    ((latency 12) (background 0) (min_run_missed ()) (step_missed ())
     (shorter_missed_somewhere true))
    ((latency 12) (background 1) (min_run_missed ()) (step_missed ())
     (shorter_missed_somewhere true))
    ((latency 20) (background 0) (min_run_missed ()) (step_missed ())
     (shorter_missed_somewhere true))
    ((latency 20) (background 1) (min_run_missed ()) (step_missed ())
     (shorter_missed_somewhere true))
    ((latency 36) (background 0) (min_run_missed ()) (step_missed ())
     (shorter_missed_somewhere true))
    ((latency 36) (background 1) (min_run_missed ()) (step_missed ())
     (shorter_missed_somewhere true))
    ((latency 200) (background 0) (min_run_missed ()) (step_missed ())
     (shorter_missed_somewhere true))
    ((latency 200) (background 1) (min_run_missed ()) (step_missed ())
     (shorter_missed_somewhere true))
    |}]
;;

let%expect_test "the engine runs the quiet firmware as the model does" =
  let firmware = Predicate.compile quiet ~latency:20 |> ok_exn in
  let samples =
    Quickcheck.random_value
      ~seed:(`Deterministic "quiet")
      (quiet_samples ~min_run:8 ~due:27)
    |> Array.of_list
  in
  let machine =
    Lockstep.lockstep
      ?preload:(Option.map firmware.budget_from_host ~f:List.return)
      ~cycles:(Array.length samples)
      ~config:firmware.config
      ~program:(Asm.Program.words firmware.program |> ok_exn)
      ~inputs:(fun cycle -> samples.(cycle))
      ()
  in
  print_s [%message (machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ("lockstep held" (cycles 901))
    (machine.fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    |}]
;;
