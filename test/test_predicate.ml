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

let%expect_test "pins that cannot be read, or a budget too long to set, are refused" =
  List.iter
    [ Predicate.Edge { pin = 5; rising = true }, 10
    ; ( Edge_while { edge = { pin = 0; rising = true }; guard = { pin = 11; high = true } }
      , 10 )
    ; scl_rise, 40
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
     (Error "latency 40 needs a budget of 38, above what set holds"))
    |}]
;;

let verdict_bit (firmware : Predicate.Firmware.t) (machine : Machine.t) =
  (machine.pin_out lsr firmware.config.set_base) land 1
;;

(* The cycles in which the verdict issues: the pin shows it after that step. *)
let machine_verdicts (firmware : Predicate.Firmware.t) samples =
  let words = Asm.Program.words firmware.program |> ok_exn in
  let machine = Machine.create ~config:firmware.config ~program:words |> ok_exn in
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
  (* the prologue: set p, set pins *)
  let watching_from = 2 in
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
let random_samples =
  let open Quickcheck.Generator.Let_syntax in
  let%map runs =
    List.gen_with_length
      60
      (Quickcheck.Generator.both (Int.gen_incl 0 3) (Int.gen_incl 1 8))
  in
  List.concat_map runs ~f:(fun (pins, cycles) -> List.init cycles ~f:(fun _ -> pins))
;;

let%expect_test "on the model, every match lands exactly at the certified latency" =
  List.iter
    [ i2c_start, 10; i2c_start, 6; scl_rise, 4; scl_rise, 25 ]
    ~f:(fun (p, l) ->
      let firmware = Predicate.compile p ~latency:l |> ok_exn in
      let matches = ref 0 in
      Quickcheck.test ~trials:100 random_samples ~f:(fun samples ->
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
    ((predicate "pin 1 rises") (l 4) (matches 1334))
    ((predicate "pin 1 rises") (l 25) (matches 632))
    |}]
;;

let%expect_test "the engine runs the compiled firmware as the model does" =
  let firmware = Predicate.compile i2c_start ~latency:10 |> ok_exn in
  let samples =
    Quickcheck.random_value ~seed:(`Deterministic "i2c") random_samples |> Array.of_list
  in
  let machine =
    Lockstep.lockstep
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

let%expect_test "the watch cocotb runs on the chip is the compiler's" =
  let firmware = Predicate.compile i2c_start ~latency:10 |> ok_exn in
  print_s
    [%message
      ""
        ~same:
          (String.equal firmware.source (In_channel.read_all "i2c_start_watch.asm")
           : bool)];
  [%expect {| (same true) |}]
;;

let quiet = Predicate.Quiet { pin = 2 }

let%expect_test "a pin that stops moving compiles to a poll per level" =
  let firmware = Predicate.compile ~latency:20 quiet |> ok_exn in
  print_string firmware.source;
  print_s [%sexp (firmware.certificate : Predicate.Certificate.t)];
  [%expect {|
    ; pin 2 stops moving: pin 5 pulses 20 to 25 cycles on
        set p, 15           ; the budget
        set pins, 0
        jmp pin, high
        jmp low
    low_wait:
        wait 0 pin 2 [1]
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
        jmp low_wait
    ((latency 20) (jitter 5)
     (sampling (Polls (min_run 6) (unseen_before_verdict 2)))
     (verdict_pcs (12 22)))
    |}]
;;

let%expect_test "a quiet latency the polls cannot meet is refused" =
  List.iter [ 11; 12; 36; 37 ] ~f:(fun latency ->
    print_s [%message (latency : int) (compiled quiet ~latency : int Or_error.t)]);
  [%expect {|
    ((latency 11)
     ("compiled quiet ~latency"
      (Error "latency 11 exceeded by 1 cycle: pin 2 stops moving needs 12")))
    ((latency 12) ("compiled quiet ~latency" (Ok 12)))
    ((latency 36) ("compiled quiet ~latency" (Ok 36)))
    ((latency 37)
     ("compiled quiet ~latency"
      (Error "latency 37 needs a budget of 32, above what set holds")))
    |}]
;;

(* The cycles whose sample of [pin] differs from the cycle before's. *)
let changes samples ~pin =
  List.filter_mapi
    (List.zip_exn (List.drop_last_exn samples) (List.tl_exn samples))
    ~f:(fun i (was, is) -> Option.some_if (((was lxor is) lsr pin) land 1 = 1) (i + 1))
;;

(* Runs of the pin at least [min_run] long, some ending before a verdict is due and some
   after, from a first run long enough to leave the prologue behind. *)
let quiet_samples ~min_run ~due =
  let open Quickcheck.Generator.Let_syntax in
  let%map runs =
    List.gen_with_length
      30
      (Quickcheck.Generator.union
         [ Int.gen_incl min_run due; Int.gen_incl (due + 1) (2 * due) ])
  in
  List.concat_mapi ((2 * due) :: runs) ~f:(fun i cycles ->
    List.init cycles ~f:(fun _ -> (i % 2) lsl 2))
;;

let%expect_test "on the model, a quiet verdict comes latency to latency + jitter after \
                 the last edge, and each quiet run gets one"
  =
  List.iter [ 12; 20; 36 ] ~f:(fun latency ->
    let firmware = Predicate.compile quiet ~latency |> ok_exn in
    let { Predicate.Certificate.jitter; sampling; _ } = firmware.certificate in
    let min_run, unseen =
      match sampling with
      | Polls { min_run; unseen_before_verdict } -> min_run, unseen_before_verdict
      | Waits _ -> raise_s [%message "waits, not polls"]
    in
    let due = latency + jitter in
    let verdicts = ref 0 in
    Quickcheck.test ~trials:100 (quiet_samples ~min_run ~due) ~f:(fun samples ->
      let length = List.length samples in
      let seen = machine_verdicts firmware samples in
      let changes = changes samples ~pin:2 in
      verdicts := !verdicts + List.length seen;
      (* each verdict answers the last edge the polls could see, and no other verdict *)
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
        then raise_s [%message "a quiet run without a verdict" (edge : int) (next : int)]));
    print_s [%message "" (latency : int) (jitter : int) ~verdicts:(!verdicts : int)]);
  [%expect {|
    ((latency 12) (jitter 5) (verdicts 2339))
    ((latency 20) (jitter 5) (verdicts 2104))
    ((latency 36) (jitter 5) (verdicts 1911))
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
      ~cycles:(Array.length samples)
      ~config:firmware.config
      ~program:(Asm.Program.words firmware.program |> ok_exn)
      ~inputs:(fun cycle -> samples.(cycle))
      ()
  in
  print_s [%message (machine.fault : Machine.Fault.t)];
  [%expect {|
    ("lockstep held" (cycles 947))
    (machine.fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    |}]
;;
