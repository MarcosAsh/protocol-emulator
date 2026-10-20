open! Core
open Protocol_emulator

let program source =
  (Asm.assemble (String.concat ~sep:"\n" source) |> ok_exn).instructions |> Array.of_list
;;

let%expect_test "the truth of a few programs" =
  List.iter
    [ [ "mov t, now"; "add t, 2"; "wait t" ]
    ; [ "mov t, now"; "wait t" ]
    ; [ "wait t" ]
    ; [ "set p, 4"; "mov t, now"; "add t, 2"; "loop:"; "wait t+ [1]"; "jmp loop" ]
    ; [ "set p, 3"; "mov t, now"; "add t, 2"; "loop:"; "wait t+ [1]"; "jmp loop" ]
    ; [ "mov t, now"; "add t, 2"; "loop:"; "wait t+"; "jmp loop" ]
    ; [ "set x, 3"; "loop:"; "jmp x--, loop"; "halt" ]
    ; [ "loop:"; "set x, 1"; "jmp x--, loop"; "wait t" ]
    ]
    ~f:(fun source ->
      let p = program source in
      print_s
        [%message
          (Exhaustive.to_string p)
            ~truth:(Exhaustive.truth p : Exhaustive.Truth.t)
            ~admitted:(Exhaustive.admits p : bool)]);
  [%expect
    {|
    ("mov t, now; add t, 2; wait t" (truth (Safe (waited true))) (admitted true))
    ("mov t, now; wait t" (truth (Late (pc 1))) (admitted false))
    ("wait t" (truth (Unanchored (pc 0))) (admitted false))
    ("set p, 4; mov t, now; add t, 2; wait t+ [1]; jmp 3"
     (truth (Safe (waited true))) (admitted true))
    ("set p, 3; mov t, now; add t, 2; wait t+ [1]; jmp 3" (truth (Late (pc 3)))
     (admitted false))
    ("mov t, now; add t, 2; wait t+; jmp 2" (truth (Late (pc 2)))
     (admitted false))
    ("set x, 3; jmp x--, 1; halt" (truth (Safe (waited false))) (admitted true))
    ("set x, 1; jmp x--, 0; wait t" (truth (Safe (waited false)))
     (admitted true))
    |}]
;;

let%expect_test "counting x down before setting it is out of scope" =
  List.iter
    [ [ "loop:"; "jmp x--, loop" ]
    ; [ "set x, 1"; "loop:"; "jmp x--, loop" ]
    ; [ "loop:"; "jmp x--, loop"; "set x, 1"; "jmp loop" ]
    ; [ "jmp set"; "loop:"; "jmp x--, loop"; "set:"; "set x, 1"; "jmp loop" ]
    ]
    ~f:(fun source ->
      let p = program source in
      print_s
        [%message (Exhaustive.to_string p) ~in_scope:(Exhaustive.sets_x_first p : bool)]);
  [%expect
    {|
    ("jmp x--, 0" (in_scope false))
    ("set x, 1; jmp x--, 1" (in_scope true))
    ("jmp x--, 0; set x, 1; jmp 0" (in_scope false))
    ("jmp 2; jmp x--, 1; set x, 1; jmp 1" (in_scope true))
    |}]
;;

let%expect_test "every program of four words, with a table SAT finds for each refusal" =
  Exhaustive.print ~witness:true (Exhaustive.run ~check_every:50 Exhaustive.Bound.tiny);
  [%expect
    {|
    ((bound ((words 4) (delays (0)) (imms (7)) (values ()))) (programs 24081)
     (out_of_scope 19660) (checked 140)
     (truths
      ((late 456) ("safe, never waits" 1505) ("safe, waits" 36)
       (unanchored 2424)))
     (safe_admitted (1541 1541)) (precision 100.00%) (waiting_admitted (36 36))
     (precision_waiting 100.00%) (unsound ()))
    ((class_ Wait) (safe 18) (admitted 18) (precision 100.00%))
    ((class_ Wait_advance) (safe 18) (admitted 18) (precision 100.00%))
    ((class_ Anchor) (safe 756) (admitted 756) (precision 100.00%))
    ((class_ Step) (safe 1168) (admitted 1168) (precision 100.00%))
    ((class_ Jump) (safe 1176) (admitted 1176) (precision 100.00%))
    ((class_ Nop) (safe 728) (admitted 728) (precision 100.00%))
    ((class_ Halt) (safe 190) (admitted 190) (precision 100.00%))
    |}]
;;
