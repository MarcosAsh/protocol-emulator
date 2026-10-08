open! Core
open Protocol_emulator
open Can

let%expect_test "the CRC is CRC-15/CAN" =
  let bits =
    String.to_list "123456789"
    |> List.concat_map ~f:(fun c ->
      List.init 8 ~f:(fun i -> (Char.to_int c lsr (7 - i)) land 1 = 1))
  in
  print_s [%message (crc15 bits : Int.Hex.t)];
  [%expect {| ("crc15 bits" 0x59e) |}]
;;

let frames =
  [ Frame.data ~id:0x123 [ 0xde; 0xad ]
  ; Frame.data ~id:0x000 [ 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00 ]
  ; Frame.data ~id:0x7ff [ 0xff; 0xff; 0xff; 0xff; 0xff; 0xff; 0xff; 0xff ]
  ; Frame.data ~id:0x555 []
  ; Frame.remote ~id:0x0f0 ~dlc:4
  ]
;;

let frame_generator =
  let open Quickcheck.Generator.Let_syntax in
  let%bind id = Int.gen_incl 0 0x7ff in
  match%bind Bool.quickcheck_generator with
  | true ->
    let%map dlc = Int.gen_incl 0 8 in
    Frame.remote ~id ~dlc
  | false ->
    let%bind length = Int.gen_incl 0 8 in
    let%map data = List.gen_with_length length (Int.gen_incl 0 0xff) in
    Frame.data ~id data
;;

let%expect_test "the decoder reads back every frame the builder makes" =
  Quickcheck.test
    ~trials:1000
    ~sexp_of:[%sexp_of: Frame.t]
    frame_generator
    ~f:(fun frame ->
      [%test_result: Frame.t Or_error.t] (decode (line frame)) ~expect:(Ok frame));
  let frame = Frame.data ~id:0 [ 0 ] in
  let line = line frame in
  print_s
    [%message
      ""
        ~line:
          (String.of_list (List.map line ~f:(fun b -> if b then '1' else '0')) : string)];
  (* a stuff bit that repeats the level, and a data bit flipped *)
  let flip n = List.mapi line ~f:(fun i b -> if i = n then not b else b) in
  print_s [%message "" ~stuff:(decode (flip 5) : Frame.t Or_error.t)];
  print_s [%message "" ~data:(decode (flip 22) : Frame.t Or_error.t)];
  [%expect
    {|
    (line 00000100000100000100010000010001000100001001101111111111111)
    (stuff (Error ("stuff error" (bit 5))))
    (data (Error (CRC (sent 0x2213) (expected 0x3efa))))
    |}]
;;

(* Each frame's bits sampled mid-bit from the falling edge of its SOF, the next SOF looked
   for after the frame's last bit. *)
let sampled levels frames ~period =
  let levels = Array.of_list levels in
  let sof_after start =
    List.range (Int.max start 1) (Array.length levels)
    |> List.find ~f:(fun i -> levels.(i - 1) && not levels.(i))
  in
  List.fold frames ~init:(0, []) ~f:(fun (start, sent) frame ->
    let bits = List.length (line frame) in
    match sof_after start with
    | Some sof when sof + (bits * period) <= Array.length levels ->
      ( sof + (bits * period)
      , List.init bits ~f:(fun bit -> levels.(sof + (bit * period) + (period / 2)))
        :: sent )
    | _ -> start, [] :: sent)
  |> snd
  |> List.rev
;;

(* The host writes the period, then every frame's words as the fifo has room. *)
let run frames ~period =
  let schedule = period :: List.concat_map frames ~f:words in
  let cycles =
    List.sum (module Int) frames ~f:(fun frame -> List.length (line frame) + 2) * period
  in
  let t = Machine.create ~config ~program:(Timed_program.words firmware) |> ok_exn in
  let t, levels = Machine_run.run t ~tx:schedule ~pin:tx_pin ~cycles ~inputs:0 in
  t, sampled (List.map levels ~f:(fun level -> level = 1)) frames ~period
;;

let%expect_test "the core sends what the builder makes, back to back" =
  List.iter [ period; shortest_period ] ~f:(fun period ->
    let t, sent = run frames ~period in
    print_s [%message (period : int) (t.fault : Machine.Fault.t)];
    List.iter2_exn frames sent ~f:(fun frame sent ->
      [%test_result: bool list] ~message:"line" sent ~expect:(line frame);
      [%test_result: Frame.t Or_error.t]
        ~message:"decoded"
        (decode sent)
        ~expect:(Ok frame);
      print_s
        [%message
          ""
            ~id:(frame.id : Int.Hex.t)
            ~bits:(List.length sent : int)
            ~stuff_bits:(List.length sent - 47 - (8 * List.length frame.data) : int)]));
  [%expect
    {|
    ((period 96)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((id 0x123) (bits 64) (stuff_bits 1))
    ((id 0x0) (bits 127) (stuff_bits 16))
    ((id 0x7ff) (bits 126) (stuff_bits 15))
    ((id 0x555) (bits 48) (stuff_bits 1))
    ((id 0xf0) (bits 47) (stuff_bits 0))
    ((period 15)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((id 0x123) (bits 64) (stuff_bits 1))
    ((id 0x0) (bits 127) (stuff_bits 16))
    ((id 0x7ff) (bits 126) (stuff_bits 15))
    ((id 0x555) (bits 48) (stuff_bits 1))
    ((id 0xf0) (bits 47) (stuff_bits 0))
    |}]
;;

(* At a period near the floor, so the run is short. *)
let%expect_test "can in lockstep" =
  let period = shortest_period + 1 in
  let schedule = ref (period :: List.concat_map frames ~f:words) in
  let tx_level = ref 0 in
  let model =
    Lockstep.lockstep
      ~cycles:
        (List.sum (module Int) frames ~f:(fun frame -> List.length (line frame) + 2)
         * period)
      ~config
      ~program:(Timed_program.words firmware)
      ~inputs:(fun _ -> 0)
      ~host:(fun _ ->
        match !schedule with
        | word :: rest when !tx_level < Machine.fifo_depth ->
          schedule := rest;
          { Lockstep.Host.idle with tx = Some word }
        | _ -> Lockstep.Host.idle)
      ~react:(fun m -> tx_level := List.length m.tx_fifo)
      ()
  in
  print_s [%message (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ("lockstep held" (cycles 6752))
    (model.fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    |}]
;;

let%expect_test "every edge is placed by a deadline" =
  Timing_report.print ~period ~config (Timed_program.source firmware);
  [%expect
    {|
      6  set pins, 1                  phase -95  edge -94  gap ?..?
     15  set pins, 0                  phase -95  edge -94  gap 103..?
     19  out pins, 1                  phase -95  edge -94  gap 89..103
     23  out pins, 1                  phase -95  edge -94  gap 89..103
     29  mov pins, !pins              phase -95  edge -94  gap 94..98
     37  out pins, 1                  phase -95  edge -94  gap 88..104
     41  out pins, 1                  phase -95  edge -94  gap 88..104
     47  mov pins, !pins              phase -95  edge -94  gap 94..98
     51  set pins, 1                  phase -95  edge -94  gap 91..101
    ((words 56) (edge_jitter 0) (sample_jitter 0) (side_jitter 0) (may_miss 0))
    |}]
;;

module G = Hardcaml_verify.Comb_gates

(* The host picks the rate, so the analyser's rows are for every load of the floor or more
   and the kernel accepts them at each, by checked SAT; at one less it refuses them. *)
let%expect_test "the kernel accepts every period from the shortest up" =
  let program = Timed_program.program firmware in
  let config = Asm.Program.configure program config in
  let words = Asm.Program.words program |> ok_exn in
  let table ~floor =
    Analyser.analyse ~period_floor:floor ~config program.instructions
    |> Kernel.Table.of_analyser
  in
  let check ~floor =
    Kernel.check ~period:floor ~single_capture_edge:false ~config ~words (table ~floor)
  in
  print_s
    [%message
      ""
        ~analyser:
          (Analyser.check ~period:shortest_period ~config program
           : Analyser.Verdict.t Or_error.t)
        ~kernel:(check ~floor:shortest_period : unit Or_error.t)
        ~one_less:(check ~floor:(shortest_period - 1) : unit Or_error.t)];
  let loads_from floor =
    Table_query.every_load_from
      ~floor
      ~single_capture_edge:false
      ~config
      ~words
      (table ~floor:shortest_period)
  in
  Checked_unsat.prove
    [%string "can: every load of %{shortest_period#Int} or more"]
    ~cases:[ G.vdd ]
    ~claim:(loads_from shortest_period);
  (* the tooth: one less than the table allows *)
  Checked_unsat.prove
    ~show:[ "loaded" ]
    [%string "can: every load of %{shortest_period - 1#Int} or more"]
    ~cases:[ G.vdd ]
    ~claim:(loads_from (shortest_period - 1));
  [%expect
    {|
    ((analyser (Ok ((words 56) (deadline_waits 10) (worst_slack (0)))))
     (kernel (Ok ()))
     (one_less
      (Error
       ("rows the kernel rejects"
        (rejected (((pc 36) (fails ("in time"))) ((pc 40) (fails ("in time")))))))))
    (QED "can: every load of 15 or more")
    (counterexample "can: every load of 14 or more"
     (model ((loaded 0000000000001110))))
    |}]
;;
