open! Core
open Protocol_emulator
open Sent

let msb_first nibbles =
  List.concat_map nibbles ~f:(fun n -> List.init 4 ~f:(fun i -> (n lsr (3 - i)) land 1))
;;

let%expect_test "the core's CRC is the SAE's table" =
  let nibbles = Quickcheck.Generator.(list_with_length 6 (Int.gen_incl 0 15)) in
  Quickcheck.test ~trials:1000 ~sexp_of:[%sexp_of: int list] nibbles ~f:(fun nibbles ->
    let core =
      List.fold (msb_first nibbles) ~init:config.crc_init ~f:(fun crc bit ->
        Crc.step ~width:4 ~poly:config.crc_poly ~reflect:false crc ~bit)
    in
    [%test_result: int] ~message:"crc" core ~expect:(crc4 nibbles));
  print_s [%message (crc4 [ 0; 0; 0; 0; 0; 0 ] : int) (crc4 [ 1; 2; 3; 4; 5; 6 ] : int)];
  [%expect {| (("crc4 [0; 0; 0; 0; 0; 0]" 5) ("crc4 [1; 2; 3; 4; 5; 6]" 2)) |}]
;;

let frame status data = { Frame.status; data }

let frames =
  [ frame 0x0 [ 0; 0; 0; 0; 0; 0 ]
  ; frame 0xf [ 15; 15; 15; 15; 15; 15 ]
  ; frame 0x5 [ 1; 2; 3; 4; 5; 6 ]
  ; frame 0xa [ 0xc; 0xa; 0xf; 0xe; 0x0; 0x7 ]
  ]
;;

(* The host writes the tick, then each frame's words from cycle [at], as the fifo has
   room. *)
let run ?(late = 0) ?(source = firmware) ~tick ~cycles () =
  let schedule =
    (0, tick)
    :: List.concat_mapi frames ~f:(fun i frame ->
      List.map (words frame) ~f:(fun word -> (if i = 2 then late else 0), word))
  in
  let t = Machine.create ~config ~program:(Firmware.assemble source) |> ok_exn in
  let rec loop (t : Machine.t) schedule levels n =
    if n = cycles
    then t, List.rev levels
    else (
      let t, schedule =
        match schedule with
        | (at, word) :: rest when at <= n && List.length t.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx t word |> ok_exn, rest
        | schedule -> t, schedule
      in
      let t = Machine.step t ~inputs:0 in
      loop t schedule (((t.pin_out lsr pin) land 1 = 1) :: levels) (n + 1))
  in
  loop t schedule [] 0
;;

let print_run ?late ~tick ~cycles () =
  let t, levels = run ?late ~tick ~cycles () in
  let decoded = decode ~cycle_ns levels in
  Or_error.iter decoded ~f:(fun (decoded, _) ->
    [%test_result: Frame.t list] ~message:"frames" decoded ~expect:frames);
  print_s
    [%message
      ""
        (tick : int)
        ~measured_ns:(Or_error.map decoded ~f:snd : Measured.t Or_error.t)
        (t.fault : Machine.Fault.t)]
;;

let%expect_test "the core sends every frame, at the standard tick and the shortest" =
  print_run ~tick:standard_tick ~cycles:185_000 ();
  print_run ~tick:shortest_tick ~cycles:26_000 ();
  [%expect
    {|
    ((tick 150)
     (measured_ns
      (Ok ((sync (168000 168000)) (low (15000 15000)) (pause (36000 36000)))))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((tick 21)
     (measured_ns
      (Ok ((sync (23520 23520)) (low (2100 2100)) (pause (5040 5040)))))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* The third frame's words come 15,000 cycles in, 5,000 after the second frame ends. *)
let%expect_test "a late frame lengthens the pause before it" =
  print_run ~late:15_000 ~tick:shortest_tick ~cycles:30_000 ();
  [%expect
    {|
    ((tick 21)
     (measured_ns
      (Ok ((sync (23520 23520)) (low (2100 2100)) (pause (5040 116780)))))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "the decoder refuses a fall a tick late and a short low" =
  let _, levels = run ~tick:standard_tick ~cycles:60_000 () in
  let levels = Array.of_list levels in
  let falls =
    List.filter
      (List.range 1 (Array.length levels))
      ~f:(fun i -> levels.(i - 1) && not levels.(i))
  in
  let edit ~f = Array.to_list (Array.mapi levels ~f) in
  (* the third fall a tick late, so the status is one more and data 1 one less *)
  let third = List.nth_exn falls 2 in
  let late =
    edit ~f:(fun i level -> level || (i >= third && i < third + standard_tick))
  in
  (* its low cut to 3 ticks *)
  let second = List.nth_exn falls 1 in
  let short =
    edit ~f:(fun i level ->
      level || (i >= second + (3 * standard_tick) && i < second + (5 * standard_tick)))
  in
  let decoded levels = decode ~cycle_ns levels |> Or_error.map ~f:fst in
  print_s
    [%message
      ""
        ~late:(decoded late : Frame.t list Or_error.t)
        ~short:(decoded short : Frame.t list Or_error.t)];
  [%expect
    {|
    ((late (Error ("no nibble" (n 11) (low_ticks 4))))
     (short (Error ("no nibble" (n 12) (low_ticks 3)))))
    |}]
;;

(* At the shortest tick, so the run is short. *)
let%expect_test "sent in lockstep" =
  let tick = shortest_tick + 1 in
  let schedule = ref (tick :: List.concat_map frames ~f:words) in
  let tx_level = ref 0 in
  let levels = ref [] in
  let model =
    Lockstep.lockstep
      ~cycles:27_000
      ~config
      ~program:(Firmware.assemble firmware)
      ~inputs:(fun _ -> 0)
      ~host:(fun _ ->
        match !schedule with
        | word :: rest when !tx_level < Machine.fifo_depth ->
          schedule := rest;
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
          (decode ~cycle_ns (List.rev !levels) |> Or_error.map ~f:fst
           : Frame.t list Or_error.t)
        (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ("lockstep held" (cycles 27000))
    ((frames
      (Ok
       (((status 0) (data (0 0 0 0 0 0)))
        ((status 15) (data (15 15 15 15 15 15)))
        ((status 5) (data (1 2 3 4 5 6))) ((status 10) (data (12 10 15 14 0 7))))))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "every edge is placed by a deadline" =
  Timing_report.print ~period:standard_tick ~config firmware;
  [%expect
    {|
      4  set pins, 1                  phase 1  edge 2  gap ?..?
     10  set pins, 0                  phase 1  edge 2  gap 151..?
     17  set pins, 1                  phase 1  edge 2  gap 750
     27  set pins, 0                  phase 1  edge 2  gap 297..?
     34  set pins, 1                  phase 1  edge 2  gap 750
     45  set pins, 0                  phase 1  edge 2  gap 305..?
     52  set pins, 1                  phase 1  edge 2  gap 750
    ((words 82) (edge_jitter 0) (sample_jitter 0) (side_jitter 0) (may_miss 0))
    |}]
;;

module G = Hardcaml_verify.Comb_gates

let table source ~floor =
  let program = Asm.assemble source |> ok_exn in
  let config = Asm.Program.configure program config in
  ( config
  , Asm.Program.words program |> ok_exn
  , Analyser.analyse ~period_floor:floor ~config program.instructions
    |> Kernel.Table.of_analyser )
;;

(* The host picks the tick, so the analyser's rows are for every load of the floor or more
   and the kernel accepts them at each, by checked SAT; at one less it refuses. *)
let%expect_test "the kernel accepts every tick from the shortest up" =
  let check ~floor =
    let config, words, table = table firmware ~floor in
    Kernel.check ~period:floor ~config ~words table
  in
  print_s
    [%message
      ""
        ~kernel:(check ~floor:shortest_tick : unit Or_error.t)
        ~one_less:(check ~floor:(shortest_tick - 1) : unit Or_error.t)];
  let config, words, table = table firmware ~floor:shortest_tick in
  let loads_from floor =
    Table_query.every_load_from ~floor ~single_capture_edge:false ~config ~words table
  in
  Checked_unsat.prove
    [%string "sent: every load of %{shortest_tick#Int} or more"]
    ~cases:[ G.vdd ]
    ~claim:(loads_from shortest_tick);
  Checked_unsat.prove
    ~show:[ "loaded" ]
    [%string "sent: every load of %{shortest_tick - 1#Int} or more"]
    ~cases:[ G.vdd ]
    ~claim:(loads_from (shortest_tick - 1));
  [%expect
    {|
    ((kernel (Ok ()))
     (one_less
      (Error
       ("rows the kernel rejects" (rejected (((pc 26) (fails ("in time")))))))))
    (QED "sent: every load of 21 or more")
    (counterexample "sent: every load of 20 or more"
     (model ((loaded 0000000000010100))))
    |}]
;;

(* Each version before the last, rebuilt from the one after it, with what the assembler,
   the analyser and the kernel said of it at the standard tick and from the shortest, and
   what a run at the standard tick shows: the decoded frames and the fault register. *)
let replace source changes =
  List.fold changes ~init:source ~f:(fun source (pattern, with_) ->
    if not (String.is_substring source ~substring:pattern)
    then raise_s [%message "BUG: not in the source" pattern];
    String.substr_replace_first source ~pattern ~with_)
;;

(* The fourth: the sync's loop moved [t] 51 ticks on with no wait, which the rows bound at
   one tick but not from a floor. The anchor before the idle level came last, for the
   report's jitter. *)
let fourth =
  replace
    firmware
    [ "    mov t, now\n    set pins, 1", "    set pins, 1"
    ; ( "    add t, p\n    add t, p\n    wait t+\n    jmp x--, sync\n"
      , "    add t, p\n    add t, p\n    add t, p\n    jmp x--, sync\n" )
    ]
;;

(* The third: the nibble's loop moved [t] with no wait, [x] times, and the analyser does
   not bound an [x] shifted from the data, so the phase after it had no floor. *)
let third = replace fourth [ "length:\n    wait t+\n", "length:\n    add t, p\n" ]

(* The second: the pause waited on its end, and the next sync on it again, late in every
   frame; and [x] came from the isr, which bounds it no better. *)
let second =
  replace
    third
    [ ( "    add t, p                 ; 12 ticks of pause, more if the host is late\n"
      , "    add t, p\n    wait t                   ; 12 ticks of pause\n" )
    ; ( "    out x, 4                 ; status, not in the CRC\n"
      , "    mov isr, osr\n    in null, 12\n    mov x, isr\n    out null, 4\n" )
    ; ( "    mov osr, isr\n    out x, 4\n    jmp pulse\n"
      , "    in null, 12\n    mov x, isr\n    jmp pulse\n" )
    ; ( "    mov isr, osr\n\
        \    out x, 4\n\
        \    mov osr, isr             ; the same nibble again, a bit at a time through \
         the CRC\n"
      , "    mov isr, osr\n    in null, 12\n    mov x, isr\n" )
    ]
;;

(* The first: 51 is past a [set]'s five bits. *)
let first =
  replace
    second
    [ ( "    set x, 16\nsync:\n    add t, p\n    add t, p\n    add t, p\n"
      , "    set x, 50\nsync:\n    add t, p\n" )
    ]
;;

let%expect_test "the versions before" =
  List.iter
    [ "first", first; "second", second; "third", third; "fourth", fourth ]
    ~f:(fun (name, source) ->
      match Asm.assemble source with
      | Error error -> print_s [%message name ~assembler:(error : Error.t)]
      | Ok program ->
        let config = Asm.Program.configure program config in
        let verdicts ~period ~floor =
          let rows =
            Analyser.analyse ?period ?period_floor:floor ~config program.instructions
          in
          let analyser =
            Analyser.check ?period ?period_floor:floor ~config program |> Result.is_ok
          in
          let kernel =
            Kernel.check
              ?period:(Option.first_some period floor)
              ~config
              ~words:(Asm.Program.words program |> ok_exn)
              (Kernel.Table.of_analyser rows)
          in
          [%message (analyser : bool) (kernel : unit Or_error.t)]
        in
        let t, levels = run ~source ~tick:standard_tick ~cycles:185_000 () in
        print_s
          [%message
            name
              ~standard:(verdicts ~period:(Some standard_tick) ~floor:None : Sexp.t)
              ~from_shortest:(verdicts ~period:None ~floor:(Some shortest_tick) : Sexp.t)
              ~decoded:
                (decode ~cycle_ns levels
                 |> Or_error.map ~f:(fun (decoded, _) ->
                   [%equal: Frame.t list] decoded frames)
                 : bool Or_error.t)
              (t.fault : Machine.Fault.t)]);
  [%expect
    {|
    (first
     (assembler
      ((line 20 "    set x, 50")
       (value "out of range" (value 50) (lo 0) (hi 31)))))
    (second
     (standard
      ((analyser false)
       (kernel
        (Error
         ("rows the kernel rejects"
          (rejected
           (((pc 8) (fails ("in time")))
            ((pc 28) (fails ("in time" "next phase")))
            ((pc 46) (fails ("in time" "next phase"))))))))))
     (from_shortest
      ((analyser false)
       (kernel
        (Error
         ("rows the kernel rejects"
          (rejected
           (((pc 8) (fails ("in time")))
            ((pc 28) (fails ("in time" "next phase")))
            ((pc 46) (fails ("in time" "next phase"))))))))))
     (decoded (Ok true))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline true) (decode false))))
    (third
     (standard
      ((analyser true)
       (kernel
        (Error
         ("rows the kernel rejects"
          (rejected
           (((pc 25) (fails ("in time" "next phase")))
            ((pc 43) (fails ("in time" "next phase"))))))))))
     (from_shortest
      ((analyser true)
       (kernel
        (Error
         ("rows the kernel rejects"
          (rejected
           (((pc 25) (fails ("in time" "next phase")))
            ((pc 43) (fails ("in time" "next phase"))))))))))
     (decoded (Ok true))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (fourth (standard ((analyser true) (kernel (Ok ()))))
     (from_shortest
      ((analyser true)
       (kernel
        (Error
         ("rows the kernel rejects"
          (rejected (((pc 25) (fails ("in time" "next phase"))))))))))
     (decoded (Ok true))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
