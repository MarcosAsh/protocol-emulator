open! Core
open Protocol_emulator
open Dshot

let%expect_test "the frame word" =
  print_s [%message (frame ~throttle:1046 ~telemetry:false : Int.Hex.t)];
  [%expect {| ("frame ~throttle:1046 ~telemetry:false" 0x82c6) |}]
;;

let frames = [ 0, false; 48, false; 1046, false; 2047, true; 1365, true ]
let words = List.map frames ~f:(fun (throttle, telemetry) -> frame ~throttle ~telemetry)

(* The host writes every word as the fifo has room. *)
let run source ~cycles =
  let t = Machine.create ~config ~program:(Firmware.assemble source) |> ok_exn in
  let t, levels = Machine_run.run t ~tx:words ~pin ~cycles ~inputs:0 in
  t, List.map levels ~f:(fun level -> level = 1)
;;

let%expect_test "the core sends every frame within the rate's timing" =
  List.iter
    [ "dshot600", dshot600, Rate.dshot600, 9_000
    ; "dshot1200", dshot1200, Rate.dshot1200, 4_500
    ]
    ~f:(fun (name, source, rate, cycles) ->
      let t, levels = run source ~cycles in
      let decoded = decode rate ~cycle_ns levels in
      Or_error.iter decoded ~f:(fun (decoded, _) ->
        [%test_result: (int * bool) list] ~message:"frames" decoded ~expect:frames);
      print_s
        [%message
          name
            ~measured_ns:(Or_error.map decoded ~f:snd : Measured.t Or_error.t)
            (t.fault : Machine.Fault.t)]);
  [%expect
    {|
    (dshot600
     (measured_ns (Ok ((T0H (620 620)) (bit (1660 1660)) (T1H (1240 1240)))))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (dshot1200
     (measured_ns (Ok ((T0H (320 320)) (bit (840 840)) (T1H (640 640)))))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "the decoder refuses a flipped bit and a short high" =
  (* the first frame and the low after it *)
  let _, levels = run dshot600 ~cycles:1_600 in
  let rises =
    List.zip_exn (true :: List.drop_last_exn levels) levels
    |> List.filter_mapi ~f:(fun i (was, level) -> Option.some_if (level && not was) i)
  in
  (* the fifth bit of 0x0000 is a zero: hold it high for a one's time, or cut it to 27
     cycles, 540 ns *)
  let fifth = List.nth_exn rises 4 in
  let flipped =
    List.mapi levels ~f:(fun i level -> level || (i >= fifth && i < fifth + 62))
  in
  let short =
    List.mapi levels ~f:(fun i level -> level && (i < fifth + 27 || i > fifth + 30))
  in
  print_s
    [%message
      ""
        ~flipped:
          (decode Rate.dshot600 ~cycle_ns flipped |> Or_error.map ~f:fst
           : (int * bool) list Or_error.t)
        ~short:
          (decode Rate.dshot600 ~cycle_ns short |> Or_error.map ~f:fst
           : (int * bool) list Or_error.t)];
  [%expect
    {|
    ((flipped (Error (checksum (word 0x800))))
     (short (Error ("out of spec" T0H (ns 540) (nominal 625)))))
    |}]
;;

let%expect_test "dshot600 in lockstep" =
  let words = ref words in
  let tx_level = ref 0 in
  let levels = ref [] in
  let model =
    Lockstep.lockstep
      ~cycles:9_000
      ~config
      ~program:(Firmware.assemble dshot600)
      ~inputs:(fun _ -> 0)
      ~host:(fun _ ->
        match !words with
        | word :: rest when !tx_level < Machine.fifo_depth ->
          words := rest;
          { Lockstep.Host.idle with tx = Some word }
        | _ -> Lockstep.Host.idle)
      ~react:(fun m ->
        tx_level := List.length m.tx_fifo;
        levels := ((m.pin_out lsr pin) land 1 = 1) :: !levels)
      ()
  in
  print_s
    [%message
      ""
        ~frames:
          (decode Rate.dshot600 ~cycle_ns (List.rev !levels) |> Or_error.map ~f:fst
           : (int * bool) list Or_error.t)
        (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ("lockstep held" (cycles 9000))
    ((frames (Ok ((0 false) (48 false) (1046 false) (2047 true) (1365 true))))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "every edge is placed by a deadline" =
  Timing_report.print ~config dshot600;
  Timing_report.print ~config dshot1200;
  [%expect
    {|
      1  set pins, 0                  phase 1  edge 2  gap ?..?
      9  set pins, 1                  phase -30  edge -29  gap 21..?
     11  out pins, 1                  phase -30  edge -29  gap 31
     13  set pins, 0                  phase -30  edge -29  gap 31
    ((words 21) (edge_jitter 0) (sample_jitter 0) (side_jitter 0) (may_miss 0))
      1  set pins, 0                  phase 1  edge 2  gap ?..?
      9  set pins, 1                  phase -15  edge -14  gap 10..?
     11  out pins, 1                  phase -15  edge -14  gap 16
     13  set pins, 0                  phase -15  edge -14  gap 16
    ((words 20) (edge_jitter 0) (sample_jitter 0) (side_jitter 0) (may_miss 0))
    |}]
;;

(* Both rates as first written, but for the gap below and the anchor before the line is
   first set, which only makes that edge's report exact: the kernel accepts the rows. *)
let%expect_test "the kernel accepts both rates" =
  List.iter
    [ "dshot600", dshot600; "dshot1200", dshot1200 ]
    ~f:(fun (name, source) ->
      let program = Asm.assemble source |> ok_exn in
      let config = Asm.Program.configure program config in
      let words = Asm.Program.words program |> ok_exn in
      let rows = Analyser.analyse ~config program.instructions in
      print_s
        [%message
          name
            ~kernel:
              (Kernel.check ~config ~words (Kernel.Table.of_analyser rows)
               : unit Or_error.t)]);
  [%expect {|
    (dshot600 (kernel (Ok ())))
    (dshot1200 (kernel (Ok ())))
    |}]
;;

(* The first version's gap after a frame: the kernel accepted it, but the frames ran
   together, as the line was low for 2.4 us after each, under the decoder's two bits. The
   kernel checks deadlines, not how long the protocol wants the line idle. *)
let%expect_test "the first version, with a short gap between frames" =
  let pattern =
    "    set y, 7\ngap:\n    wait t+\n    jmp y--, gap             ; low between frames\n"
  in
  if not (String.is_substring dshot600 ~substring:pattern)
  then raise_s [%message "BUG: not in the source" pattern];
  let first =
    String.substr_replace_first
      dshot600
      ~pattern
      ~with_:
        "    add t, p\n    add t, p\n    wait t                   ; low between frames\n"
  in
  let program = Asm.assemble first |> ok_exn in
  let words = Asm.Program.words program |> ok_exn in
  let rows = Analyser.analyse ~config program.instructions in
  let t, levels = run first ~cycles:9_000 in
  print_s
    [%message
      ""
        ~kernel:
          (Kernel.check ~config ~words (Kernel.Table.of_analyser rows) : unit Or_error.t)
        ~decoded:
          (decode Rate.dshot600 ~cycle_ns levels |> Or_error.map ~f:fst
           : (int * bool) list Or_error.t)
        (t.fault : Machine.Fault.t)];
  [%expect
    {|
    ((kernel (Ok ())) (decoded (Error ("not 16 bits" ("List.length frame" 80))))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
