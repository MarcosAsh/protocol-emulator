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
    ((latency 10) (guard_at (1)) (blind_after_match 13) (blind_after_reject (2))
     (verdict_pc 7))
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
     (Error "latency 40 needs a budget of 38 cycles, above what set holds"))
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
  let c = firmware.certificate in
  let edge, guard =
    match predicate with
    | Predicate.Edge edge -> edge, None
    | Edge_while { edge; guard } -> edge, Some guard
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
          match guard, c.guard_at with
          | Some g, Some at ->
            cycle + at < Array.length samples
            && Bool.equal (bit (cycle + at) g.pin) g.high
          | _ -> true
        in
        if matches
        then cycle + c.blind_after_match + 1, (cycle + c.latency) :: verdicts
        else cycle + Option.value_exn c.blind_after_reject + 1, verdicts))
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
