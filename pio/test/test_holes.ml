open! Core
open Pio

let spec text = Spec.of_string text |> ok_exn

let%expect_test "with no reference the search finds the fastest program" =
  let holes =
    Holes.parse {|
.program square
.side_set 1
    nop side 1 [?]
    nop side 0 [?]
|}
    |> ok_exn
  in
  let spec = spec "rule high: side0+ -> side0- >= 5\nrule low: side0- -> side0+ >= 3" in
  let search = Holes.solve holes ~passes:(Holes.meets [ spec ]) |> ok_exn in
  print_s [%message "" ~minimal:(search.minimal : (int * int list list) option)];
  [%expect {| (minimal ((6 ((4 2))))) |}]
;;

let%expect_test "side-set values keep the reference's binary form" =
  let reference = ".program p\n.side_set 2\n    nop side 0b01 [1]\n    nop side 0b10\n" in
  let holes =
    Holes.parse
      ~reference
      ".program p\n.side_set 2\n    nop side ? [1]\n    nop side 0b10\n"
    |> ok_exn
  in
  List.iter [ [ 1 ]; [ 3 ]; [ 0 ] ] ~f:(fun values ->
    print_endline (Holes.fill holes values);
    print_s [%message "" ~cost:(Holes.cost holes values : int)]);
  [%expect
    {|
    .program p
    .side_set 2
        nop side 0b01 [1]
        nop side 0b10
    (cost 0)
    .program p
    .side_set 2
        nop side 0b11 [1]
        nop side 0b10
    (cost 1)
    .program p
    .side_set 2
        nop side 0b00 [1]
        nop side 0b10
    (cost 1)
    |}]
;;

let%expect_test "a ? that is no hole, a changed line and a value out of range are errors" =
  let reference = ".program p\n.side_set 1 opt\n    nop [7]\n    nop\n" in
  List.iter
    ~f:(fun (reference, text) ->
      print_s
        [%message
          ""
            ~_:
              (Holes.parse ?reference text |> Or_error.map ~f:Holes.holes
               : Holes.Hole.t list Or_error.t)])
    [ None, ".program p\n    set x, ?\n"
    ; None, ".program p\n    nop\n"
    ; Some reference, ".program p\n.side_set 1 opt\n    nop [?]\n    nop [1]\n"
    ; ( Some ".program p\n.side_set 2\n    nop side 0 [9]\n"
      , ".program p\n.side_set 2\n    nop side 0 [?]\n" )
    ; None, ".program p\n    nop side ?\n"
    ; Some reference, ".program p\n.side_set 1 opt\n    nop [?]\n    nop side ?\n"
    ];
  [%expect
    {|
    (Error ("a ? that is neither [?] nor side ?" (line 2)))
    (Error "no holes")
    (Error ("differs from the reference outside a hole" (line 4)))
    (Error ("reference value out of the hole's range" (line 3) (value 9)))
    (Error ("line 2" "no .side_set declared"))
    (Ok
     (((line 3) (kind Delay) (reference (7)) (domain (0 1 2 3 4 5 6 7)))
      ((line 4) (kind Side) (reference ()) (domain (0 1)))))
    |}]
;;

let i2c_spec = In_channel.read_all "holes/i2c.spec" |> spec
let i2c_reference = In_channel.read_all "pico_examples/i2c.pio"

let i2c_holes =
  Holes.parse ~reference:i2c_reference (In_channel.read_all "holes/i2c.pio") |> ok_exn
;;

let print_search (search : Holes.Search.t) =
  List.iter search.checked ~f:(fun (cost, size) -> printf "cost %d: %d tried\n" cost size);
  print_s [%message "" ~minimal:(search.minimal : (int * int list list) option)]
;;

(* The reference's lines the fix changes, before and after. *)
let print_changes ~reference text =
  List.zip_exn (String.split_lines reference) (String.split_lines text)
  |> List.iteri ~f:(fun i (before, after) ->
    if not (String.equal before after)
    then printf "%d\n  - %s\n  + %s\n" (i + 1) before after)
;;

(* Writes [text] and runs pio_check on it with [spec], as a user would, printing its
   verdicts and exit code. *)
let certify ~spec text =
  Out_channel.write_all "certify.pio" ~data:text;
  Out_channel.write_all "certify.spec" ~data:spec;
  let status =
    Sys_unix.command "../bin/pio_check.exe certify.pio -spec certify.spec > certify.txt"
  in
  In_channel.read_lines "certify.txt"
  |> List.filter ~f:(fun line -> not (String.is_prefix line ~prefix:" "))
  |> List.iter ~f:print_endline;
  printf "pio_check exit %d\n" status
;;

(* With all 18 of the program's delays as holes (970,442 assignments up to cost 7, about
   12 minutes), every minimal fix is [jmp x-- do_exec [6]] plus one cycle on one of the
   five instructions between an ACK's scl fall and the next scl rise, this one among them. *)
let%expect_test "#796: the fewest delay cycles that meet Standard-mode at the pin" =
  List.iter (Holes.holes i2c_holes) ~f:(fun hole -> print_s [%sexp (hole : Holes.Hole.t)]);
  let search = Holes.solve i2c_holes ~passes:(Holes.meets [ i2c_spec ]) |> ok_exn in
  print_search search;
  let fix =
    Holes.fill i2c_holes (Option.value_exn search.minimal |> snd |> List.hd_exn)
  in
  print_changes ~reference:i2c_reference fix;
  certify ~spec:(In_channel.read_all "holes/i2c.spec") fix;
  [%expect
    {|
    ((line 53) (kind Delay) (reference (2)) (domain (0 1 2 3 4 5 6 7)))
    ((line 62) (kind Delay) (reference (2)) (domain (0 1 2 3 4 5 6 7)))
    ((line 71) (kind Delay) (reference (0)) (domain (0 1 2 3 4 5 6 7)))
    ((line 72) (kind Delay) (reference (0)) (domain (0 1 2 3 4 5 6 7)))
    cost 0: 1 tried
    cost 1: 6 tried
    cost 2: 19 tried
    cost 3: 42 tried
    cost 4: 75 tried
    cost 5: 118 tried
    cost 6: 170 tried
    cost 7: 228 tried
    (minimal ((7 ((2 3 0 6)))))
    62
      -     jmp pin do_nack side 0 [2] ; Test SDA for ACK/NAK, fall through if ACK
      +     jmp pin do_nack side 0 [3] ; Test SDA for ACK/NAK, fall through if ACK
    72
      -     jmp x-- do_exec            ; Repeat n + 1 times
      +     jmp x-- do_exec [6]        ; Repeat n + 1 times
    i2c
    t_low: scl- -> scl+ >= 4.7us: ok, 16 cycles (5000ns) at pc 4
    t_high: scl+ -> scl- >= 4us: ok, 16 cycles (5000ns) at pc 7
    t_hd_sta: sda- -> scl- >= 4us: ok, 16 cycles (5000ns) at pc 16 exec set pindirs, 0 side 0 [7]
    t_su_sta: scl+ -> sda- >= 4.7us: ok, 16 cycles (5000ns) at pc 16 exec set pindirs, 0 side 1 [7]
    t_su_sto: scl+ -> sda+ >= 4us: ok, 16 cycles (5000ns) at pc 16 exec set pindirs, 1 side 1 [7]
    t_su_dat: sda -> scl+ >= 250ns: ok, 8 cycles (2496ns) at pc 4
    pio_check exit 0
    |}]
;;

let%expect_test "#796 with a full 1000 ns Standard-mode rise on scl: no delay fix" =
  (* SCL reaches 0.7 VDD 1.42 us after its release, so t_SU;STA needs 4.7 + 1.42 us at the
     pin. Between two START or STOP steps only the step, [out exec] and [jmp x-- do_exec]
     run, and all four holes together fail, so the sequences in pio_i2c.c must change, as
     the issue's fix does. *)
  let rise = Spec.of_string ~base:i2c_spec "rule t_su_sta_rise: scl+ -> sda- >= 6.12us" in
  let search = Holes.solve i2c_holes ~passes:(Holes.meets [ ok_exn rise ]) |> ok_exn in
  print_s
    [%message
      ""
        ~tried:(List.sum (module Int) search.checked ~f:snd : int)
        ~of_:(8 * 8 * 8 * 8 : int)
        ~minimal:(search.minimal : (int * int list list) option)];
  [%expect {| ((tried 4096) (of_ 4096) (minimal ())) |}]
;;
