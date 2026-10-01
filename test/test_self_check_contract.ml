open! Core
open! Hardcaml
open Hardcaml_lws
open Self_check_monitor

module Contract = Self_check_contract.Make (struct
    let max_inner = 9
  end)

module Harness = Hardcaml_test_harness.Lws_harness.Make (Contract.I) (Contract.O)

let ( <--. ) = Bits.( <--. )

(* The first cycle with a break and the cycle the irq is due by, as the reference lists
   them and as the circuit says them, a cycle later. *)
module Answer = struct
  type t =
    { first : int option
    ; due : int option
    }
  [@@deriving sexp_of, equal]

  let of_reference (reference : Reference.t list) =
    { first = List.hd reference |> Option.map ~f:(fun v -> v.at)
    ; due =
        List.find_map reference ~f:(fun v ->
          match v.kind with
          | By by -> Some by
          | Pending | Alias -> None)
    }
  ;;
end

(* How many named waves had a break, an irq due, and a break the contract lets go, and the
   first where the circuit and the reference differ. *)
let differ cases =
  Harness.run
    ~random_initial_state:`All
    ~create:Contract.hierarchical
    (fun (h @ local) ~inputs ~outputs ->
       let o = Before_and_after_edge.before_edge outputs in
       let answer edges w =
         let m = Array.length edges in
         inputs.clocking.clear := Bits.vdd;
         Lws.step h;
         inputs.clocking.clear := Bits.gnd;
         List.iteri inputs.inner ~f:(fun n edge ->
           edge <--. if n < m - 1 then edges.(n) else 0);
         inputs.count <--. m - 1;
         inputs.least <--. edges.(m - 1);
         let first = ref None in
         let due = ref None in
         (* past the wave the line idles high, a frame on from its last start *)
         for n = 0 to Bytes.length w + edges.(m - 1) + 32 do
           inputs.line
           := Bits.of_bool (n >= Bytes.length w || Char.to_int (Bytes.get w n) = 1);
           Lws.step h;
           let seen r output =
             if Option.is_none !r && Bits.to_bool !output then r := Some (n - 1)
           in
           seen first o.violated;
           seen due o.overdue
         done;
         { Answer.first = !first; due = !due }
       in
       let tally = Hashtbl.create (module String) in
       let count key = Hashtbl.incr tally key in
       let differ =
         List.filter_map cases ~f:(fun (name, edges, w) ->
           let reference = Reference.violations ~edges w in
           let expect = Answer.of_reference reference in
           if Option.is_some expect.first then count "break";
           if Option.is_some expect.due then count "due";
           if Option.is_some expect.first && Option.is_none expect.due then count "let go";
           let actual = answer edges w in
           Option.some_if (not (Answer.equal expect actual)) (name, edges, expect, actual))
       in
       print_s
         [%message
           ""
             ~cases:(List.length cases : int)
             ~tally:
               (Hashtbl.to_alist tally |> List.sort ~compare:[%compare: string * int]
                : (string * int) list)
             ~differ:(List.length differ : int)];
       List.take differ 3
       |> List.iter ~f:(fun (name, edges, expect, actual) ->
         print_s
           [%message name (edges : int array) (expect : Answer.t) (actual : Answer.t)]))
;;

let named name (c : Case.t) = name, c.edges, Case.wave c

let fuzzed ~seed ~cases ~long =
  let rs = Random.State.make [| seed |] in
  List.init cases ~f:(fun n ->
    named [%string "%{seed#Int}:%{n#Int}"] (snd (Gen.mutated rs ~long)))
;;

let%expect_test "the circuit is the reference on the fuzzer's cases" =
  differ (fuzzed ~seed:11 ~cases:1500 ~long:false @ fuzzed ~seed:12 ~cases:40 ~long:true);
  [%expect
    {| ((cases 1540) (tally ((break 1315) (due 1300) ("let go" 15))) (differ 0)) |}]
;;

(* The blind cases by name: a lone pulse before the least with the next frame 2^16 on, and
   a fall at [watch_from] with a pulse in the first frame 2^16 on, each a cycle either
   side too. *)
let%expect_test "the circuit is the reference where the checker is blind" =
  let near = [ -1; 0; 1 ] in
  let least =
    List.map near ~f:(fun by ->
      named
        [%string "least %{by#Int}"]
        (Case.frames
           [| 300; 600 |]
           [| 0; 1 |]
           ~idle:[ (1 lsl 16) - 1 + by ]
           ~mutations:[ Pulse { at = 100 + 600 - 1; width = 1 } ]))
  in
  let stale =
    List.concat_map near ~f:(fun by ->
      let at = watch_from + (1 lsl 16) + by in
      List.map [ 1; 3 ] ~f:(fun width ->
        named
          [%string "stale %{by#Int} %{width#Int}"]
          (Case.frames
             [| 300; 600 |]
             [| 0; 1 |]
             ~lead_in:(at - 400)
             ~mutations:[ Pulse { at = watch_from; width = 1 }; Pulse { at; width } ])))
  in
  let first_frames =
    List.concat_map [ 0; 1; 5 ] ~f:(fun d ->
      List.map [ 1; 2 ] ~f:(fun width ->
        named
          [%string "first %{d#Int} %{width#Int}"]
          (Case.frames
             [| 40; 60; 80; 100; 130 |]
             [| 0; 1; 0; 1; 1 |]
             ~lead_in:(50 + d)
             ~idle:[ 0 ]
             ~mutations:[ Pulse { at = watch_from - 1 + d; width } ])))
  in
  differ (least @ stale @ first_frames);
  [%expect {| ((cases 15) (tally ((break 11) (due 8) ("let go" 3))) (differ 0)) |}]
;;

(* Frames of 6 to 30 cycles with up to nine edges, which the rows refuse but the contract
   takes, so breaks near the least, at the last edge and between back to back frames are
   common; random levels before the first and a few flipped runs anywhere. *)
let small rs n =
  let rand lo hi = lo + Random.State.int rs (hi - lo + 1) in
  let least = rand 6 30 in
  let inner =
    List.take
      (List.permute ~random_state:rs (List.range 1 least))
      (rand 1 (Int.min 9 (least - 1)))
    |> List.sort ~compare
  in
  let last = List.last_exn inner in
  let w = Bytes.make (rand 40 250) '\001' in
  let set i v = if i >= 0 && i < Bytes.length w then Bytes.set w i (Char.of_int_exn v) in
  List.iter (List.range 0 (rand 0 12)) ~f:(fun i -> set i (Random.State.int rs 2));
  let rec frames f =
    if f < Bytes.length w
    then (
      let level = ref 0 in
      List.iter (List.range 0 least) ~f:(fun k ->
        if List.mem inner k ~equal:Int.equal then level := Random.State.int rs 2;
        set (f + k) (if k >= last then 1 else !level));
      frames
        (f
         + least
         +
         match Random.State.int rs 4 with
         | 0 | 1 -> 0
         | 2 -> rand 1 3
         | _ -> rand 4 20))
  in
  frames (rand 8 20);
  List.iter
    (List.range 0 (rand 0 3))
    ~f:(fun _ ->
      let at = rand 0 (Bytes.length w - 1) in
      List.iter
        (List.range at (at + rand 1 3))
        ~f:(fun i -> if i < Bytes.length w then set i (1 - Char.to_int (Bytes.get w i))));
  [%string "small %{n#Int}"], Array.of_list (inner @ [ least ]), w
;;

let%expect_test "the circuit is the reference on small frames" =
  let rs = Random.State.make [| 13 |] in
  differ (List.init 20_000 ~f:(small rs));
  [%expect
    {| ((cases 20000) (tally ((break 15821) (due 15603) ("let go" 218))) (differ 0)) |}]
;;
