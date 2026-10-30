open! Core
open! Hardcaml
open Hardcaml_lws
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Line_stuff.I) (Line_stuff.O)

(* USB's stuffing of [bits]: a 0 after every six 1s *)
let reference bits =
  List.folding_map bits ~init:0 ~f:(fun ones bit ->
    match bit, ones with
    | 1, 5 -> 0, [ 1; 0 ]
    | 1, _ -> ones + 1, [ 1 ]
    | _ -> 0, [ 0 ])
  |> List.concat
;;

(* [stream] through the stuffing with usb_transmit's table as its flag, then the finish
   and the drain on junk bits, as the firmware runs them: the wire's bits, and each step's
   count of bits owed *)
let send (h @ local) ~(inputs : _ Line_stuff.I.t) ~outputs ~junk stream =
  (* [sent] as the step takes it, the registers as it leaves them *)
  let (o : _ Line_stuff.O.t) = Before_and_after_edge.before_edge outputs in
  let (after : _ Line_stuff.O.t) = Before_and_after_edge.after_edge outputs in
  let ones = ref 0 in
  let wire = Queue.create () in
  let counts = Queue.create () in
  let step data =
    let stuffing = !ones = 6 in
    inputs.step := Bits.vdd;
    inputs.stuffing := Bits.of_bool stuffing;
    inputs.data := Bits.of_unsigned_int ~width:1 data;
    Lws.step h;
    let sent = Bits.to_unsigned_int !(o.sent) in
    Queue.enqueue wire sent;
    Queue.enqueue counts (Bits.to_unsigned_int !(after.count));
    ones := if sent = 1 then !ones + 1 else 0
  in
  List.iter stream ~f:step;
  inputs.step := Bits.gnd;
  inputs.finish := Bits.vdd;
  Lws.step h;
  inputs.finish := Bits.gnd;
  while !ones = 6 || Bits.to_bool !(after.owed) do
    step (junk ())
  done;
  inputs.step := Bits.gnd;
  Queue.to_list wire, Queue.to_list counts
;;

let clear (h @ local) (inputs : _ Line_stuff.I.t) =
  inputs.enable := Bits.vdd;
  inputs.clocking.clear := Bits.vdd;
  Lws.step h;
  inputs.clocking.clear := Bits.gnd
;;

let%expect_test "eight 1s, a 0 and a 1: two bits owed after the stuffing, paid in the \
                 drain"
  =
  Harness.run ~create:Line_stuff.hierarchical (fun (h @ local) ~inputs ~outputs ->
    clear h inputs;
    let stream = [ 1; 1; 1; 1; 1; 1; 1; 1; 0; 1 ] in
    let wire, counts = send h ~inputs ~outputs ~junk:(Fn.const 1) stream in
    print_s [%message (stream : int list) (wire : int list) (counts : int list)];
    [%test_result: int list] wire ~expect:(reference stream));
  [%expect
    {|
    ((stream (1 1 1 1 1 1 1 1 0 1)) (wire (1 1 1 1 1 1 0 1 1 0 1))
     (counts (0 0 0 0 0 0 1 1 1 1 0)))
    |}]
;;

(* Any stream of up to 96 bits, all 1s the most stuffed, from any power-up state once
   cleared, and junk in the drain: the wire is the reference's stuffing, nothing owed at
   the end. A second packet after the first starts as the first did. Ninety-six slots owe
   at most thirteen bits, so the fifteen it can hold are room to spare. *)
let%expect_test "the wire is USB's stuffing of the stream, packet after packet" =
  let stream =
    let open Quickcheck.Generator.Let_syntax in
    let%bind n = Int.gen_incl 1 96 in
    let%bind ones = Int.gen_incl 0 100 in
    List.gen_with_length
      n
      (Quickcheck.Generator.map (Int.gen_incl 0 99) ~f:(fun r -> Bool.to_int (r < ones)))
  in
  let most = ref 0 in
  Quickcheck.test
    ~trials:300
    ~examples:[ List.init 96 ~f:(Fn.const 1), [ 1; 0 ] ]
    (Quickcheck.Generator.both stream stream)
    ~sexp_of:[%sexp_of: int list * int list]
    ~f:(fun (first, second) ->
      Harness.run
        ~random_initial_state:`All
        ~create:Line_stuff.hierarchical
        (fun (h @ local) ~inputs ~outputs ->
           clear h inputs;
           let junk = Random.State.make [| List.length first |] in
           let junk () = Random.State.int junk 2 in
           List.iter [ first; second ] ~f:(fun stream ->
             let wire, counts = send h ~inputs ~outputs ~junk stream in
             most := Int.max !most (List.fold counts ~init:0 ~f:Int.max);
             [%test_result: int list] wire ~expect:(reference stream))
           [@nontail]));
  print_s [%message "the most owed" (!most : int)];
  [%expect {| ("the most owed" (!most 13)) |}]
;;
