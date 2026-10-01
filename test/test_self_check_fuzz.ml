open! Core
open Self_check_monitor

(* A case, what the contract says of it, and what the model's checker did; with [rtl], the
   rtl's irq too, which holds in lockstep with the model. *)
let show ?(rtl = false) name (c : Case.t) =
  let verdict, reference, run = check c in
  let reference = List.take reference 2 in
  let rtl_irq =
    Option.some_if rtl ()
    |> Option.map ~f:(fun () ->
      let irq, held = run_rtl ~base:c.base ~edges:c.edges (Case.wave c) in
      if not held then raise_s [%message "the rtl left lockstep" name];
      irq)
  in
  print_s
    [%message
      name
        (verdict : Verdict.t)
        (reference : Reference.t list)
        ~irq_at:(run.irq_at : int option)
        (rtl_irq : (bool option[@sexp.option]))]
;;

let four = [| 500; 1000; 1500; 2000 |]

(* The old checker took the capture it read after each check as the next stamp, so a fall
   just after a check that moved nothing, of a low pulse of any width, went unseen; so did
   a high pulse's fall just before a check. The stamp is now the edge's own cycle. *)
let%expect_test "a fall just after or just before a check" =
  let e = 100 + 1000 in
  show
    ~rtl:true
    "low pulse 400 wide from E+3"
    (Case.frames four [| 0; 1; 1; 1 |] ~mutations:[ Pulse { at = e + 3; width = 400 } ]);
  show
    ~rtl:true
    "high pulse 400 wide to E-1"
    (Case.frames four [| 0; 0; 0; 1 |] ~mutations:[ Pulse { at = e - 401; width = 400 } ]);
  let unseen levels ~fall_at ~widths =
    List.concat_map (List.range (-6) 13) ~f:(fun d ->
      List.filter_map widths ~f:(fun width ->
        let c =
          Case.frames four levels ~mutations:[ Pulse { at = fall_at e d width; width } ]
        in
        match check c with
        | Caught, _, _ | Quiet, _, _ -> None
        | verdict, _, _ -> Some (d, width, verdict)))
  in
  let low =
    unseen [| 0; 1; 1; 1 |] ~fall_at:(fun e d _ -> e + d) ~widths:[ 1; 2; 3; 50; 499 ]
  in
  let high =
    unseen
      [| 0; 0; 0; 1 |]
      ~fall_at:(fun e d width -> e + d - width)
      ~widths:[ 1; 2; 3; 8 ]
  in
  print_s
    [%message (low : (int * int * Verdict.t) list) (high : (int * int * Verdict.t) list)];
  [%expect
    {|
    ("low pulse 400 wide from E+3" (verdict Caught)
     (reference (((at 1103) (kind (By 2099))) ((at 1503) (kind (By 2099)))))
     (irq_at (1609)) (rtl_irq true))
    ("high pulse 400 wide to E-1" (verdict Caught)
     (reference (((at 699) (kind (By 2099))) ((at 1099) (kind (By 2099)))))
     (irq_at (2099)) (rtl_irq true))
    ((low ()) (high ()))
    |}]
;;

(* The old checker armed the capture after the least and looked at the line again only
   about 22 cycles later, and a next frame starting in that span was anchored late. The
   checker now waits for the next frame from the least itself. *)
let%expect_test "the span between a frame's least and the next frame" =
  let edges = [| 300; 600 |] in
  let levels = [| 0; 1 |] in
  show
    ~rtl:true
    "high pulse 15 wide at F+3, the frame a cycle after the least"
    (Case.frames
       edges
       levels
       ~idle:[ 1 ]
       ~mutations:[ Pulse { at = 100 + 600 + 1 + 3; width = 15 } ]);
  show
    "low pulse 8 wide at the least, the frame 10 after it"
    (Case.frames
       edges
       levels
       ~idle:[ 10 ]
       ~mutations:[ Pulse { at = 100 + 600; width = 8 } ]);
  let unseen =
    List.concat_map [ 0; 1; 3; 5; 8; 10; 15; 20; 25; 30; 40; 200 ] ~f:(fun idle ->
      List.concat_map (List.range (-8) 45) ~f:(fun d ->
        List.filter_map [ 1; 2; 3; 5; 10; 20 ] ~f:(fun width ->
          let c =
            Case.frames
              edges
              levels
              ~idle:[ idle ]
              ~mutations:[ Pulse { at = 700 + d; width } ]
          in
          match check c with
          | Caught, _, _ | Quiet, _, _ -> None
          | verdict, _, _ -> Some (idle, d, width, verdict))))
  in
  print_s [%message (unseen : (int * int * int * Verdict.t) list)];
  [%expect
    {|
    ("high pulse 15 wide at F+3, the frame a cycle after the least"
     (verdict Caught)
     (reference (((at 704) (kind (By 1300))) ((at 719) (kind (By 1300)))))
     (irq_at (1300)) (rtl_irq true))
    ("low pulse 8 wide at the least, the frame 10 after it" (verdict Caught)
     (reference (((at 708) (kind (By 1299))) ((at 710) (kind (By 1299)))))
     (irq_at (1012)))
    (unseen ())
    |}]
;;

(* A glitch after the old checker's last check disarmed the capture, and the next frame
   was anchored on the glitch's stamp; a deadline it then missed raised no irq. The anchor
   is now the fall the wait releases on, checked against the capture, and the kernel
   proves no deadline is missed from any anchor. *)
let%expect_test "a glitch after the least" =
  let edges = [| 40; 300; 600 |] in
  let levels = [| 0; 1; 1 |] in
  List.iter [ 0; 1; 10; 100; 5000 ] ~f:(fun idle ->
    List.iter [ 3; 5 ] ~f:(fun d ->
      show
        [%string "pulse at E+%{d#Int}, then the frame %{idle#Int} after the least"]
        (Case.frames
           edges
           levels
           ~idle:[ idle; 0 ]
           ~mutations:[ Pulse { at = 700 + d; width = 1 } ])));
  [%expect
    {|
    ("pulse at E+3, then the frame 0 after the least" (verdict Caught)
     (reference (((at 703) (kind (By 1299))) ((at 704) (kind (By 1299)))))
     (irq_at (1009)))
    ("pulse at E+5, then the frame 0 after the least" (verdict Caught)
     (reference (((at 705) (kind (By 1299))) ((at 706) (kind (By 1299)))))
     (irq_at (1009)))
    ("pulse at E+3, then the frame 1 after the least" (verdict Caught)
     (reference (((at 703) (kind (By 1300))) ((at 704) (kind (By 1300)))))
     (irq_at (1010)))
    ("pulse at E+5, then the frame 1 after the least" (verdict Caught)
     (reference (((at 705) (kind (By 1300))) ((at 706) (kind (By 1300)))))
     (irq_at (1010)))
    ("pulse at E+3, then the frame 10 after the least" (verdict Caught)
     (reference (((at 704) (kind (By 1302))) ((at 710) (kind (By 1302)))))
     (irq_at (1008)))
    ("pulse at E+5, then the frame 10 after the least" (verdict Caught)
     (reference (((at 706) (kind (By 1304))) ((at 710) (kind (By 1304)))))
     (irq_at (1010)))
    ("pulse at E+3, then the frame 100 after the least" (verdict Caught)
     (reference (((at 704) (kind (By 1302))) ((at 800) (kind (By 1302)))))
     (irq_at (748)))
    ("pulse at E+5, then the frame 100 after the least" (verdict Caught)
     (reference (((at 706) (kind (By 1304))) ((at 800) (kind (By 1304)))))
     (irq_at (750)))
    ("pulse at E+3, then the frame 5000 after the least" (verdict Caught)
     (reference (((at 704) (kind (By 1302))))) (irq_at (748)))
    ("pulse at E+5, then the frame 5000 after the least" (verdict Caught)
     (reference (((at 706) (kind (By 1304))))) (irq_at (750)))
    |}]
;;

(* The old checker raised a false alarm on back to back frames whose first check was the
   least its rows took. *)
let%expect_test "back to back frames at the least first edge" =
  show "first 32, back to back" (Case.frames [| 32; 61; 90 |] [| 0; 1; 1 |] ~idle:[ 0 ]);
  let alarms =
    List.concat_map (List.range 29 65) ~f:(fun first ->
      List.filter_map (List.range 0 40) ~f:(fun idle ->
        let edges = [| first; first + 17; first + 17 + 20 |] in
        let c = Case.frames edges [| 0; 1; 1 |] ~idle:[ idle; idle ] in
        match check c with
        | Quiet, _, _ -> None
        | verdict, _, _ -> Some (first, idle, verdict)))
  in
  print_s [%message (alarms : (int * int * Verdict.t) list)];
  show
    ~rtl:true
    "first 29, back to back"
    (Case.frames [| 29; 46; 66 |] [| 0; 1; 1 |] ~idle:[ 0 ]);
  [%expect
    {|
    ("first 32, back to back" (verdict Quiet) (reference ()) (irq_at ()))
    (alarms ())
    ("first 29, back to back" (verdict Quiet) (reference ()) (irq_at ())
     (rtl_irq false))
    |}]
;;

let%expect_test "a frame that ends low" =
  let edges = [| 100; 200; 300; 400 |] in
  let c = Case.frames edges [| 0; 1; 0; 1 |] in
  show ~rtl:true "last rise missing" { c with mutations = [ Missing { at = 100 + 300 } ] };
  show
    "stuck low from the fall at 200"
    { c with mutations = [ Missing { at = 100 + 300 } ]; cycles = c.cycles + 20_000 };
  [%expect
    {|
    ("last rise missing" (verdict Caught)
     (reference (((at 400) (kind (By 499))))) (irq_at (412)) (rtl_irq true))
    ("stuck low from the fall at 200" (verdict Caught)
     (reference (((at 400) (kind (By 499))))) (irq_at (412)))
    |}]
;;

(* The one blind case: a one-cycle low pulse in the cycle before the least stamps the
   capture, and a next frame whose first edge comes a multiple of 2^16 cycles later reads
   as fresh in the 16 bits the checker compares. A cycle either side is caught. *)
let%expect_test "the blind case" =
  let edges = [| 300; 600 |] in
  List.iter [ -1; 0; 1 ] ~f:(fun by ->
    let idle = (1 lsl 16) - 1 + by in
    show
      [%string
        "pulse at E-1, next frame 2^16%{if by < 0 then \"-1\" else if by > 0 then \"+1\" \
         else \"\"} after it"]
      (Case.frames
         edges
         [| 0; 1 |]
         ~idle:[ idle ]
         ~mutations:[ Pulse { at = 100 + 600 - 1; width = 1 } ]));
  [%expect
    {|
    ("pulse at E-1, next frame 2^16-1 after it" (verdict Caught)
     (reference (((at 699) (kind (By 66244))))) (irq_at (66244)))
    ("pulse at E-1, next frame 2^16 after it" (verdict (Unseen Alias))
     (reference (((at 699) (kind Alias)))) (irq_at ()))
    ("pulse at E-1, next frame 2^16+1 after it" (verdict Caught)
     (reference (((at 699) (kind (By 66246))))) (irq_at (66246)))
    |}]
;;

(* The first frame is the first fall after the checker sees the line high, here a cycle
   and five after the line comes up at 50, clean and with a pulse. *)
let%expect_test "the first frame" =
  List.iter [ 1; 5 ] ~f:(fun d ->
    let c =
      Case.frames
        [| 300; 600 |]
        [| 0; 1 |]
        ~lead_in:(50 + d)
        ~mutations:[ Pulse { at = 0; width = 50 } ]
    in
    show ~rtl:true [%string "first edge at %{50 + d#Int}"] c;
    show
      [%string "first edge at %{50 + d#Int}, pulse inside"]
      { c with mutations = c.mutations @ [ Pulse { at = 50 + d + 150; width = 1 } ] });
  [%expect
    {|
    ("first edge at 51" (verdict Quiet) (reference ()) (irq_at ())
     (rtl_irq false))
    ("first edge at 51, pulse inside" (verdict Caught)
     (reference (((at 201) (kind (By 650))) ((at 202) (kind (By 650)))))
     (irq_at (650)))
    ("first edge at 55" (verdict Quiet) (reference ()) (irq_at ())
     (rtl_irq false))
    ("first edge at 55, pulse inside" (verdict Caught)
     (reference (((at 205) (kind (By 654))) ((at 206) (kind (By 654)))))
     (irq_at (654)))
    |}]
;;

(* A fall in the first cycle the checker reads took the capture, and the old checker
   restarted on its stale stamp in the middle of the next frame. The stale stamp now
   stands for the first frame's, blind to a fall 2^16 cycles on; a cycle either side is
   caught. *)
let%expect_test "a fall before the line is first high" =
  let stale = [ Case.Pulse { at = watch_from; width = 1 } ] in
  show
    ~rtl:true
    "low at 7, frames at 100 and 230"
    (Case.frames
       [| 40; 60; 80; 100; 130 |]
       [| 0; 1; 0; 1; 1 |]
       ~idle:[ 0 ]
       ~mutations:stale);
  List.iter [ -1; 0; 1 ] ~f:(fun by ->
    let at = watch_from + (1 lsl 16) + by in
    show
      [%string
        "low at 7, pulse 2^16%{if by < 0 then \"-1\" else if by > 0 then \"+1\" else \
         \"\"} after it"]
      (Case.frames
         [| 300; 600 |]
         [| 0; 1 |]
         ~lead_in:(at - 400)
         ~mutations:(stale @ [ Pulse { at; width = 1 } ])));
  [%expect
    {|
    ("low at 7, frames at 100 and 230" (verdict Quiet) (reference ()) (irq_at ())
     (rtl_irq false))
    ("low at 7, pulse 2^16-1 after it" (verdict Caught)
     (reference (((at 65542) (kind (By 65741))) ((at 65543) (kind (By 65741)))))
     (irq_at (65741)))
    ("low at 7, pulse 2^16 after it" (verdict (Unseen Alias))
     (reference (((at 65543) (kind Alias)) ((at 65544) (kind Alias))))
     (irq_at ()))
    ("low at 7, pulse 2^16+1 after it" (verdict Caught)
     (reference (((at 65544) (kind (By 65743))) ((at 65545) (kind (By 65743)))))
     (irq_at (65743)))
    |}]
;;

(* Random certified frames with pulses, moved, missing and added edges, against the
   contract; [long] reaches frames near 2^14 cycles and idle gaps near 2^16. *)
let fuzz ~seed ~cases ~long =
  let rs = Random.State.make [| seed |] in
  let counts = Hashtbl.create (module String) in
  let bad = ref [] in
  for _ = 1 to cases do
    let _, c = Gen.mutated rs ~long in
    let verdict, reference, run = check c in
    let key =
      match verdict with
      | Quiet -> "quiet"
      | Caught -> "caught"
      | Unseen kind -> Sexp.to_string [%sexp "unseen", (kind : Reference.Kind.t)]
      | Missed _ | False_alarm _ | Missed_deadline ->
        bad := (verdict, reference, run, c) :: !bad;
        "bad"
    in
    Hashtbl.update counts key ~f:(fun n -> 1 + Option.value n ~default:0)
  done;
  print_s
    [%message
      ""
        ~verdicts:
          (Hashtbl.to_alist counts |> List.sort ~compare:[%compare: string * int]
           : (string * int) list)];
  List.iter
    (List.take (List.rev !bad) 3)
    ~f:(fun (verdict, reference, run, c) ->
      print_s
        [%message
          (verdict : Verdict.t) (reference : Reference.t list) (run : Run.t) (c : Case.t)])
;;

let%expect_test "fuzz against the contract" =
  fuzz ~seed:1 ~cases:3000 ~long:false;
  fuzz ~seed:2 ~cases:100 ~long:true;
  [%expect
    {|
    (verdicts (("(unseen Pending)" 32) (caught 2554) (quiet 414)))
    (verdicts (("(unseen Pending)" 3) (caught 89) (quiet 8)))
    |}]
;;

let%expect_test "the rtl checks as the model does" =
  let rs = Random.State.make [| 3 |] in
  let differ = ref 0 in
  let ran = ref 0 in
  while !ran < 8 do
    let _, c = Gen.mutated rs ~long:false in
    if c.cycles < 20_000
    then (
      incr ran;
      let _, _, run = check c in
      let irq, held = run_rtl ~base:c.base ~edges:c.edges (Case.wave c) in
      if not (held && Bool.equal irq (Option.is_some run.irq_at)) then incr differ)
  done;
  print_s [%message (!ran : int) (!differ : int)];
  [%expect {| ((!ran 8) (!differ 0)) |}]
;;
