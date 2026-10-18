open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Frumbleglide.firmware));
  [%expect {| 34 words, 11 deadline waits, worst slack 18 |}]
;;

(* tCELL against whole cycles at the chip's clock: none lies inside the limits *)
let%expect_test "tCELL in cycles at 48 MHz" =
  let cycles ns = ns *. Float.of_int Bench.clock_hz /. 1e9 in
  printf "%.2f to %.2f cycles\n" (cycles 2_005.) (cycles 2_015.);
  List.iter [ 96; 97 ] ~f:(fun n -> printf "%d cycles %s\n" n (Bench.time n));
  [%expect {|
    96.24 to 96.72 cycles
    96 cycles 2 us
    97 cycles 2.021 us
    |}]
;;

let levels ~cycles words =
  let machine =
    Machine.create
      ~config:(Timed_program.config Frumbleglide.firmware)
      ~program:(Timed_program.words Frumbleglide.firmware)
    |> ok_exn
  in
  let machine =
    List.fold words ~init:machine ~f:(fun m w -> Machine.write_tx m w |> ok_exn)
  in
  List.folding_map (List.range 0 cycles) ~init:machine ~f:(fun machine _ ->
    let machine = Machine.step machine ~inputs:0 in
    machine, (machine.pin_out lsr Frumbleglide.pin) land 1 = 1)
  |> List.group ~break:Bool.( <> )
  |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
;;

(* Section 6's 0x8001: six 1s, a 1, fourteen 0s and a 1, read at each mid-cell transition,
   a fall a 1, and each cell's width *)
let%expect_test "section 6's word, cell by cell" =
  let levels = levels ~cycles:5_000 [ 0x8001 ] in
  let mids = List.hd_exn (Frumbleglide.mids ~clock_hz:Bench.clock_hz levels) in
  let edges =
    List.folding_map levels ~init:0 ~f:(fun at (high, n) -> at + n, (at + n, not high))
  in
  let bits =
    List.map mids ~f:(fun m ->
      match List.Assoc.find edges ~equal:Int.equal m with
      | Some true -> "0"
      | Some false -> "1"
      | None -> "?")
  in
  printf "%s\n" (String.concat bits);
  List.map2_exn (List.drop_last_exn mids) (List.tl_exn mids) ~f:(fun a b -> b - a)
  |> List.map ~f:Int.to_string
  |> String.concat ~sep:" "
  |> print_endline;
  [%expect
    {|
    1111111000000000000001
    96 97 96 97 96 97 96 97 96 97 96 97 96 97 96 97 96 96 97 96 97
    |}]
;;

let%expect_test "the bench's run against section 4's limits" =
  print_string
    (Datasheet.to_string
       Frumbleglide.bench
       (Datasheet.check Frumbleglide.limits Frumbleglide.bench));
  [%expect
    {|
    frumbleglide       tCELL          >=     2005 ns  run    96 (2000.0 ns)    needs   98 FAIL  Frumbleglide, FGL-0 data sheet, revision 0.9 section 4, p.1, and note 1, p.2: each cell; margin a cycle
    frumbleglide       tCELL          <=     2015 ns  run    97 (2020.8 ns)    needs   95 FAIL  Frumbleglide, FGL-0 data sheet, revision 0.9 section 4, p.1, and note 1, p.2: each cell; margin a cycle
    frumbleglide       tMID           >=   902.25 ns  run    48 (1000.0 ns)    needs   45       Frumbleglide, FGL-0 data sheet, revision 0.9 section 4, p.1: 45 % of tCELL's min; margin a cycle
    frumbleglide       tMID           <=  1108.25 ns  run    49 (1020.8 ns)    needs   52       Frumbleglide, FGL-0 data sheet, revision 0.9 section 4, p.1: 55 % of tCELL's max; margin a cycle
    frumbleglide       tGAP           >=    40000 ns  run    2069 (43104.2 ns) needs 1921       Frumbleglide, FGL-0 data sheet, revision 0.9 section 4, p.1, and note 3, p.2; margin a cycle
    |}]
;;

let%expect_test "what refuses it, at its edge" =
  List.iter (Named_refusal.refusals Frumbleglide.limits Frumbleglide.bench) ~f:(fun t ->
    print_endline (Named_refusal.to_line t));
  [%expect
    {|
    frumbleglide: edge 4, tCELL 2 us < 2.005 us min (Frumbleglide, FGL-0 data sheet, revision 0.9 section 4, p.1, and note 1, p.2: each cell; 96 cycles at 48 MHz, 98 needed)
    frumbleglide: edge 4, tCELL 2 us, inside the 2.015 us max but not its margin (Frumbleglide, FGL-0 data sheet, revision 0.9 section 4, p.1, and note 1, p.2: each cell; 96 cycles at 48 MHz, 95 needed)
    |}]
;;

(* the clocks a cell of each whole number of cycles clears tCELL at, the chip's 48 MHz
   among none of them *)
let%expect_test "where tCELL's cliffs fall" =
  List.iter
    (Datasheet.cliffs Frumbleglide.limits Frumbleglide.bench)
    ~f:(fun (t, bound, cliff) ->
      print_s [%message t.parameter (bound : int option) (cliff : Datasheet.Cliff.t)]);
  [%expect
    {|
    (tCELL (bound (96)) (cliff (Up_to 47381546)))
    (tCELL (bound (97)) (cliff (From 48635236)))
    (tMID (bound (48)) (cliff (Up_to 52091992)))
    (tMID (bound (49)) (cliff (From 45116175)))
    (tGAP (bound (2069)) (cliff (Up_to 51700000)))
    |}]
;;
