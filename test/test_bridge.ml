open! Core
open Protocol_emulator
open Bridge

let ok (outcome : Outcome.t) =
  List.for_all outcome.faults ~f:(Machine.Fault.equal Machine.Fault.none)
  && (not (List.exists outcome.irq ~f:Fn.id))
  && Option.is_none outcome.mismatch
;;

(* each edge in cycles after IN0's stop bit begins *)
let print_frames frames (outcome : Outcome.t) =
  List.iter2_exn frames outcome.frames ~f:(fun (_, byte) (frame : Frame.t) ->
    print_s
      [%message
        ""
          ~sent:(sprintf "%02x" byte : string)
          ~clocked_out:(sprintf "%02x" frame.byte : string)
          ~wire:(frame.wire_fall - frame.stop : int)
          ~first_rise:(frame.first_rise - frame.stop : int)
          ~last_fall:(frame.last_fall - frame.stop : int)]);
  print_s [%message (ok outcome : bool)]
;;

let%expect_test "bytes on IN0 come out on MOSI, on the rtl beside the model" =
  let bytes = [ 0xa5; 0x3c; 0x00; 0xff; 0x81 ] in
  let frames = List.mapi bytes ~f:(fun n byte -> 20 + (n * spacing), byte) in
  print_frames frames (rtl ~cycles:(20 + (6 * spacing)) frames);
  [%expect
    {|
    ((sent a5) (clocked_out a5) (wire 9) (first_rise 129) (last_fall 279))
    ((sent 3c) (clocked_out 3c) (wire 9) (first_rise 129) (last_fall 279))
    ((sent 00) (clocked_out 00) (wire 9) (first_rise 129) (last_fall 279))
    ((sent ff) (clocked_out ff) (wire 9) (first_rise 129) (last_fall 279))
    ((sent 81) (clocked_out 81) (wire 9) (first_rise 129) (last_fall 279))
    ("ok outcome" true)
    |}]
;;

(* Any bytes at any gaps the bridge allows, on the model: each comes out as it went in,
   every edge as many cycles after its stop bit as in the frames above. *)
let%expect_test "any bytes, any gaps" =
  let latencies = Hash_set.Poly.create () in
  Quickcheck.test
    ~trials:200
    (Quickcheck.Generator.list_non_empty
       (Quickcheck.Generator.both (Int.gen_incl 0 (2 * spacing)) (Int.gen_incl 0 0xff)))
    ~f:(fun gaps ->
      let frames =
        List.folding_map gaps ~init:(20 - spacing) ~f:(fun last (gap, byte) ->
          let start = last + spacing + gap in
          start, (start, byte))
      in
      let last, _ = List.last_exn frames in
      let outcome = model ~cycles:(last + (2 * spacing)) frames in
      [%test_result: bool] (ok outcome) ~expect:true;
      [%test_result: int list]
        (List.map outcome.frames ~f:(fun f -> f.byte))
        ~expect:(List.map frames ~f:snd);
      List.iter outcome.frames ~f:(fun f ->
        Hash_set.add
          latencies
          (f.wire_fall - f.stop, f.first_rise - f.stop, f.last_fall - f.stop)));
  print_s [%message (Hash_set.to_list latencies : (int * int * int) list)];
  [%expect {| ("Hash_set.to_list latencies" ((9 129 279))) |}]
;;

(* Frames [spacing] apart all come out. A cycle closer, the wire's next start bit falls
   before engine 1 arms its capture, which breaks the premise its certificate rests on: it
   misses a deadline and halts. Closer still it takes a data bit's fall for the start bit
   and clocks out wrong bytes, with no irq. *)
let%expect_test "as close as the bridge keeps up" =
  let bytes = [ 0xa5; 0x00; 0xff; 0x81; 0x7e; 0x55 ] in
  List.iter
    [ spacing; spacing - 1; spacing - 10 ]
    ~f:(fun apart ->
      let frames = List.mapi bytes ~f:(fun n byte -> 20 + (n * apart), byte) in
      let outcome = model ~cycles:(20 + (8 * apart)) frames in
      print_s
        [%message
          ""
            (apart : int)
            ~clocked_out:
              (List.map outcome.frames ~f:(fun f -> sprintf "%02x" f.byte) : string list)
            ~irq:(outcome.irq : bool list)
            ~missed_deadline:
              (List.map outcome.faults ~f:(fun f -> f.missed_deadline) : bool list)]);
  [%expect
    {|
    ((apart 276) (clocked_out (a5 00 ff 81 7e 55)) (irq (false false))
     (missed_deadline (false false)))
    ((apart 275) (clocked_out (a5)) (irq (false false))
     (missed_deadline (false true)))
    ((apart 266) (clocked_out (a5 ff e0 ff)) (irq (false false))
     (missed_deadline (false false)))
    |}]
;;
