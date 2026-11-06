open! Core
open Protocol_emulator
open Swd_blind

(* What the analyser and the kernel make of the firmware, which compiling it checked. *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict firmware));
  [%expect {| 22 words, 2 deadline waits, worst slack 1 |}]
;;

(* The host's clocks through the core and the target, read back from the pushed words. *)
let run ?(half = standard_half) clocks =
  let scenario =
    { scenario with
      script =
        Pin_trace.Scenario.load
          ~assumptions:(Certified.assumptions (List.hd_exn protocol.certified))
          ~config:(Timed_program.config firmware)
          ~program:(Timed_program.words firmware)
          ()
        @ [ Pin_trace.Scenario.start; Write (Host_port.Reg.tx, [ half ]) ]
        @ List.concat_map
            (List.chunks_of (words clocks) ~length:4)
            ~f:(fun words ->
              [ Pin_trace.Step.Write (Host_port.Reg.tx, words)
              ; Run ((List.length words * 16 * (half + 1)) + 200)
              ; Read (Host_port.Reg.rx, List.length words)
              ])
    }
  in
  let target = ref (Target.create ()) in
  let peer () =
    { Pin_trace.Peer.inputs = (fun () -> Target.line !target lsl swdio_pin)
    ; step =
        (fun ~pin_out ~pin_dir ->
          target
          := Target.step
               !target
               ~swclk:(Pin_trace.Peer.bit pin_out swclk_pin)
               ~host_drive:(Pin_trace.Peer.bit pin_dir swdio_pin = 1)
               ~host_level:(Pin_trace.Peer.bit pin_out swdio_pin))
    }
  in
  let _, reads = Pin_trace.run { scenario with peer } in
  List.concat reads, !target
;;

let%expect_test "a line reset, the DPIDR, then an AP read" =
  let pushed, target = run clocks in
  let dpidr = answer ~pushed ~first:dpidr_first
  and ap = answer ~pushed ~first:ap_first in
  print_s
    [%message
      (dpidr : Answer.t)
        (ap : Answer.t)
        ~log:(Target.log target : string list)
        ~violations:(Target.violations target : string list)];
  [%test_result: int] dpidr.data ~expect:Target.dpidr;
  [%expect
    {|
    ((dpidr ((ack 1) (data 0xbc12477) (parity_ok true)))
     (ap ((ack 1) (data 0x0) (parity_ok true)))
     (log ("line reset" "read DP 0x0: 0x0bc12477" "read AP 0x0: 0x00000000"))
     (violations ()))
    |}]
;;

(* The AP read posts CSW, which RDBUFF returns. The write is 46 clocks and 8 idle. *)
let%expect_test "a write to the AP, then two reads" =
  let first = 64 + 48 + 54 in
  let pushed, target =
    run
      (line_reset
       @ idle 8
       @ read ~ap:false ~addr:0
       @ idle 3
       @ write ~ap:true ~addr:0 0x23000052
       @ idle 8
       @ read ~ap:true ~addr:0
       @ idle 3
       @ read ~ap:false ~addr:0xc
       @ idle 11)
  in
  let ap = answer ~pushed ~first
  and rdbuff = answer ~pushed ~first:(first + 48) in
  print_s
    [%message
      (ap : Answer.t)
        (rdbuff : Answer.t)
        ~log:(Target.log target : string list)
        ~violations:(Target.violations target : string list)];
  [%expect
    {|
    ((ap ((ack 1) (data 0x0) (parity_ok true)))
     (rdbuff ((ack 1) (data 0x23000052) (parity_ok true)))
     (log
      ("line reset" "read DP 0x0: 0x0bc12477" "write AP 0x0: 0x23000052"
       "read AP 0x0: 0x00000000" "read DP 0xc: 0x23000052"))
     (violations ()))
    |}]
;;

(* Cases: driving the turnaround, a header with bad parity, and a header before two idle cycles. *)
let%expect_test "what the target refuses" =
  let show ?(first = 64) name clocks =
    let pushed, target = run clocks in
    print_s
      [%message
        name
          ~answer:(answer ~pushed ~first : Answer.t)
          ~log:(Target.log target : string list)
          ~violations:(Target.violations target : string list)]
  in
  let dpidr = read ~ap:false ~addr:0 in
  show
    "drives the first turnaround"
    (line_reset @ idle 8 @ List.take dpidr 8 @ idle 1 @ List.drop dpidr 9 @ idle 3);
  show
    "bad parity"
    (line_reset
     @ idle 8
     @ List.mapi dpidr ~f:(fun i clock -> if i = 5 then Clock.Drive false else clock)
     @ idle 3);
  show ~first:57 "one idle cycle" (line_reset @ idle 1 @ dpidr @ idle 3);
  [%expect
    {|
    ("drives the first turnaround"
     (answer ((ack 0) (data 0xbc12477) (parity_ok true)))
     (log ("line reset" "read DP 0x0: 0x0bc12477"))
     (violations ("host and target both drive SWDIO")))
    ("bad parity" (answer ((ack 7) (data 0xffffffff) (parity_ok false)))
     (log ("line reset")) (violations ("protocol error")))
    ("one idle cycle" (answer ((ack 1) (data 0xbc12477) (parity_ok true)))
     (log ("line reset" "read DP 0x0: 0x0bc12477"))
     (violations ("1 idle cycles after a line reset")))
    |}]
;;

(* SWCLK, and SWDIO with who drives it: a level per cycle for a DPIDR read. *)
let%expect_test "the line for a DPIDR read" =
  let machine =
    Machine.create
      ~config:(Timed_program.config firmware)
      ~program:(Timed_program.words firmware)
    |> ok_exn
  in
  let machine =
    List.fold
      (standard_half :: words (read ~ap:false ~addr:0))
      ~init:machine
      ~f:(fun machine word -> Machine.write_tx machine word |> ok_exn)
  in
  let levels =
    List.folding_map (List.range 0 1_200) ~init:machine ~f:(fun machine _ ->
      let machine = Machine.step machine ~inputs:0 in
      let bit pins pin = (pins lsr pin) land 1 in
      ( machine
      , ( bit machine.pin_out swclk_pin
        , bit machine.pin_out swdio_pin
        , bit machine.pin_dir swdio_pin ) ))
  in
  let runs =
    List.group levels ~break:(fun a b -> not ([%equal: int * int * int] a b))
    |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
  in
  print_s [%message (runs : ((int * int * int) * int) list)];
  [%expect
    {|
    (runs
     (((0 0 0) 8) ((0 1 0) 6) ((0 1 1) 17) ((1 1 1) 24) ((0 1 1) 3) ((0 0 1) 21)
      ((1 0 1) 24) ((0 0 1) 3) ((0 1 1) 21) ((1 1 1) 24) ((0 1 1) 3) ((0 0 1) 21)
      ((1 0 1) 24) ((0 0 1) 24) ((1 0 1) 24) ((0 0 1) 3) ((0 1 1) 21)
      ((1 1 1) 24) ((0 1 1) 3) ((0 0 1) 21) ((1 0 1) 24) ((0 0 1) 3) ((0 1 1) 21)
      ((1 1 1) 24) ((0 1 1) 15) ((0 1 0) 19) ((1 1 0) 24) ((0 1 0) 24)
      ((1 1 0) 24) ((0 1 0) 24) ((1 1 0) 24) ((0 1 0) 24) ((1 1 0) 24)
      ((0 1 0) 24) ((1 1 0) 24) ((0 1 0) 24) ((1 1 0) 24) ((0 1 0) 24)
      ((1 1 0) 24) ((0 1 0) 24) ((1 1 0) 24) ((0 1 0) 34) ((1 1 0) 24)
      ((0 1 0) 24) ((1 1 0) 24) ((0 1 0) 24) ((1 1 0) 24) ((0 1 0) 24)
      ((1 1 0) 24) ((0 1 0) 24) ((1 1 0) 24) ((0 1 0) 24) ((1 1 0) 24)
      ((0 1 0) 24) ((1 1 0) 24) ((0 1 0) 24) ((1 1 0) 24) ((0 1 0) 21)))
    |}]
;;
