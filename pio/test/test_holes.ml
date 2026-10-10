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
