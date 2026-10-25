open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Plinkoo.firmware));
  [%expect {| 90 words, 15 deadline waits, worst slack 0 |}]
;;

let%expect_test "section 6's checksum" =
  printf "0x%02x\n" (Plinkoo.checksum [ 0x03; 0x12; 0x34; 0x56 ]);
  [%expect {| 0x61 |}]
;;

(* The firmware against a peripheral, or with none, DAT pulled up: the frames it took and
   the acks the host reads back. *)
let run ?(peripheral = true) ~cycles payloads =
  let machine =
    Machine.create
      ~config:(Timed_program.config Plinkoo.firmware)
      ~program:(Timed_program.words Plinkoo.firmware)
    |> ok_exn
  in
  (* each word in as the fifo has room *)
  let rec go machine p words n =
    if n = 0
    then machine, p
    else (
      let machine, words =
        match words with
        | w :: rest when List.length machine.Machine.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx machine w |> ok_exn, rest
        | _ -> machine, words
      in
      let pulled = peripheral && Plinkoo.Peripheral.pulls_low p in
      let machine =
        Machine.step machine ~inputs:(Bool.to_int (not pulled) lsl Plinkoo.dat)
      in
      let stb = (machine.pin_out lsr Plinkoo.stb) land 1 = 1 in
      let dat = (machine.pin_dir lsr Plinkoo.dat) land 1 = 0 && not pulled in
      go machine (Plinkoo.Peripheral.step p ~stb ~dat) words (n - 1))
  in
  let machine, p =
    go
      machine
      (Plinkoo.Peripheral.create ())
      (List.concat_map payloads ~f:Plinkoo.words)
      cycles
  in
  let rec acks machine =
    match Machine.read_rx machine with
    | Some (word, machine) -> word :: acks machine
    | None -> []
  in
  Plinkoo.Peripheral.frames p, acks machine, machine.fault
;;

let%expect_test "a peripheral takes both frames and acknowledges them" =
  let frames, acks, fault = run ~cycles:30_000 Plinkoo.frames in
  print_s
    [%message
      (frames : (Int.Hex.t list * bool) list) (acks : int list) (fault : Machine.Fault.t)];
  [%expect
    {|
    ((frames
      (((0x3 0x12 0x34 0x56 0x61) true)
       ((0x8 0x0 0xff 0x80 0x1 0xa5 0x5a 0x7e 0xc3 0x38) true)))
     (acks (0 0))
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false))))
    |}]
;;

let%expect_test "with no peripheral DAT stays high: no ack" =
  let _, acks, _ = run ~peripheral:false ~cycles:12_000 [ [ 0x42 ] ] in
  print_s [%message (acks : int list)];
  [%expect {| (acks (1)) |}]
;;

let%expect_test "every payload, against the peripheral" =
  Quickcheck.test
    ~trials:20
    (let%bind.Quickcheck.Generator n = Int.gen_incl 1 8 in
     List.gen_with_length n (Int.gen_incl 0 255))
    ~sexp_of:[%sexp_of: int list]
    ~f:(fun payload ->
      let frames, acks, _ = run ~cycles:12_000 [ payload ] in
      let bytes =
        (List.length payload :: payload)
        @ [ Plinkoo.checksum (List.length payload :: payload) ]
      in
      [%test_result: (int list * bool) list]
        ~message:"taken"
        frames
        ~expect:[ bytes, true ];
      [%test_result: int list] ~message:"acks" acks ~expect:[ 0 ])
;;

let%expect_test "the bench's run against section 4's limits" =
  print_string
    (Datasheet.to_string Plinkoo.bench (Datasheet.check Plinkoo.limits Plinkoo.bench));
  [%expect
    {|
    plinkoo            tSYN           >=     4800 ns  run    248 (5166.7 ns)   needs  232       Plinkoo, PLK-2 data sheet, revision 1.3 section 4, pp.1-2; margin a cycle
    plinkoo            tSYN           <=     5200 ns  run    248 (5166.7 ns)   needs  248       Plinkoo, PLK-2 data sheet, revision 1.3 section 4, pp.1-2; margin a cycle
    plinkoo            tSYH           >=      325 ns  run    24 (500.0 ns)     needs   17       Plinkoo, PLK-2 data sheet, revision 1.3 section 4, p.1: a tB at tSYN's 5.2 us max; margin a cycle
    plinkoo            tB             >=  303.542 ns  run    16 (333.3 ns)     needs   16       Plinkoo, PLK-2 data sheet, revision 1.3 note 1, p.2: tSYN/16 less 6 %, at this firmware's 248-cycle sync; margin a cycle
    plinkoo            tB             <=  342.292 ns  run    16 (333.3 ns)     needs   15 FAIL  Plinkoo, PLK-2 data sheet, revision 1.3 note 1, p.2: tSYN/16 and 6 %, at this firmware's 248-cycle sync; margin a cycle
    plinkoo            fSTB           >=  285.714 ns  run    16 (333.3 ns)     needs   15       Plinkoo, PLK-2 data sheet, revision 1.3 section 4, p.2: 3.5 MHz max; margin a cycle
    plinkoo            tSL            >=      140 ns  kernel 8 (166.7 ns)      needs    8       Plinkoo, PLK-2 data sheet, revision 1.3 section 4, pp.1-2; margin a cycle
    plinkoo            tSH            >=      140 ns  kernel 8 (166.7 ns)      needs    8       Plinkoo, PLK-2 data sheet, revision 1.3 section 4, pp.1-2; margin a cycle
    plinkoo            tFRM           >=     1500 ns  run    7701 (160437.5 ns) needs   73       Plinkoo, PLK-2 data sheet, revision 1.3 section 4, p.2, and note 4; margin a cycle
    |}]
;;

(* tDS, tDH and tREL are DAT against STB, two pins, so a limit's one pin cannot bound
   them: the bench's run does, rise by rise, at the same one-cycle margin. tREL is the
   checksum's last rise, the one before the ack's, where DAT was low and is let go. *)
let%expect_test "DAT against STB on the bench's run" =
  let stimulus = Option.value_exn Plinkoo.bench.stimulus in
  let pins = Datasheet.run_pins Plinkoo.bench ~quiet_pin:Plinkoo.stb stimulus in
  let rises = Plinkoo.around_rises pins in
  let entry parameter limit =
    { Datasheet.firmware = "plinkoo"
    ; parameter
    ; limit
    ; sheet = { part = "Plinkoo"; document = "PLK-2 revision 1.3"; page = "section 4" }
    ; margin = Cycle
    ; bound = Datasheet.level ~pin:Datasheet.set_pin ~high:true ()
    }
  in
  let report parameter limit bound =
    let v = Datasheet.verdict (entry parameter limit) ~clock_hz:Bench.clock_hz ~bound in
    printf
      "%-5s %s bound %s needs %d %s\n"
      parameter
      (match limit with
       | At_least ns -> sprintf ">= %g ns" ns
       | At_most ns -> sprintf "<= %g ns" ns)
      (Option.value_map bound ~default:"-" ~f:(fun n ->
         sprintf "%d (%s)" n (Bench.time n)))
      v.needed
      (if v.ok then "ok" else "FAIL")
  in
  (* a frame's rises: its bits, then the ack's *)
  let frame_rises = List.group rises ~break:(fun (a, _, _) (b, _, _) -> b - a > 1_000) in
  let checksum_last = List.map frame_rises ~f:(fun r -> List.nth_exn (List.rev r) 1) in
  let data = List.concat_map frame_rises ~f:List.drop_last_exn in
  report
    "tDS"
    (At_least 120.)
    (List.map data ~f:(fun (_, b, _) -> b) |> List.min_elt ~compare);
  report
    "tDH"
    (At_least 80.)
    (List.filter_map data ~f:(fun (_, _, a) -> a) |> List.min_elt ~compare);
  report
    "tREL"
    (At_most 100.)
    (List.filter_map checksum_last ~f:(fun (_, _, a) ->
       Option.filter a ~f:(fun a -> a < 16))
     |> List.max_elt ~compare);
  [%expect
    {|
    tDS   >= 120 ns bound 7 (146 ns) needs 7 ok
    tDH   >= 80 ns bound 4 (83 ns) needs 5 FAIL
    tREL  <= 100 ns bound 4 (83 ns) needs 3 FAIL
    |}]
;;

let%expect_test "what refuses it, at its edge" =
  List.iter (Named_refusal.refusals Plinkoo.limits Plinkoo.bench) ~f:(fun t ->
    print_endline (Named_refusal.to_line t));
  [%expect
    {| plinkoo: edge 6, tB 333 ns, inside the 342 ns max but not its margin (Plinkoo, PLK-2 data sheet, revision 1.3 note 1, p.2: tSYN/16 and 6 %, at this firmware's 248-cycle sync; 16 cycles at 48 MHz, 15 needed) |}]
;;
