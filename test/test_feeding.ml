open! Core
open Protocol_emulator

(* A late message can make you fault, never make you jitter: formal/late_host.sv proves it
   of the RTL for any time-triggered program. These tests show it on the streaming
   firmware, with the deadline of every word from [Feeding.schedule]. *)

let assemble (t : Certified.t) =
  let program = Asm.assemble t.source |> ok_exn in
  program, Asm.Program.configure program t.config
;;

let%expect_test "only firmware that never waits on the host is time-triggered" =
  List.iter
    (Certified.find_exn "uart_tx"
     :: Certified.find_exn "spi_master"
     :: Certified.time_triggered)
    ~f:(fun t ->
      let program, _ = assemble t in
      print_s [%message t.name ~_:(Feeding.time_triggered program : unit Or_error.t)]);
  [%expect
    {|
    (uart_tx (Error ("waits on the host" (pcs (2)))))
    (spi_master (Error ("waits on the host" (pcs (1)))))
    (uart_tx_stream (Ok ()))
    (spi_master_stream (Ok ()))
    |}]
;;

let%expect_test "the streaming firmware keeps its certificates" =
  List.iter Certified.time_triggered ~f:(fun t ->
    let program, config = assemble t in
    print_endline t.name;
    print_endline
      (Analyser.to_string
         ~side_set_count:config.side_set_count
         (Analyser.analyse ~config program.instructions));
    print_s [%message (Analyser.check ~config program : Analyser.Verdict.t Or_error.t)]);
  [%expect
    {|
    uart_tx_stream
      0  set p, 8                     phase ?..?
      1  set pins, 1                  phase ?..?  edge ?..?  jitter ?  gap ?..?
      2  mov t, now                   phase ?..?
      3  add t, p                     phase 1
      4  wait t+                      phase -6..-4  slack 4..6
      5  set pins, 0                  phase -7  edge -6  gap 8..10
      6  set x, 7                     phase -6
      7  wait t+                      phase -5..-4  slack 4..5
      8  out pins, 1                  phase -7  edge -6  gap 7..9
      9  jmp x--, 7                   phase -6
     10  wait t+                      phase -4  slack 4
     11  set pins, 1                  phase -7  edge -6  gap 8
     12  jmp 4                        phase -6
    ("Analyser.check ~config program"
     (Ok ((words 13) (deadline_waits 3) (worst_slack (4)))))
    spi_master_stream
      0  set p, 8 side 0              phase ?..?  side ?..?  jitter ?
      1  mov t, now side 0            phase ?..?
      2  add t, p side 0              phase 1
      3  wait t+ side 0               phase -6  slack 6
      4  out pins, 1 side 0           phase -7  edge -6  gap ?..?
      5  wait t+ side 0               phase -6..-4  slack 4..6
      6  in pins, 1 side 1            phase -7  sample -7  side -6
      7  wait t+ side 1               phase -6  slack 6
      8  out pins, 1 side 0           phase -7  edge -6  side -6  gap 14..18
      9  jmp 5                        phase -6
    ("Analyser.check ~config program"
     (Ok ((words 10) (deadline_waits 3) (worst_slack (4)))))
    |}]
;;

let deadlines (t : Certified.t) ~words =
  let program, config = assemble t in
  Feeding.schedule ~config program ~words:(List.length words) |> ok_exn
;;

(* The RTL and the model side by side, the host writing word [k] in cycle [at k] and
   reading every reply at once. Returns the pins after every cycle and the cycle in which
   the underflow fault was set. The run stops before the pull after the last word, which
   no host feeds. *)
let run (t : Certified.t) ~words ~frame ~at =
  let _, config = assemble t in
  let program = Firmware.assemble t.source in
  let schedule = List.mapi words ~f:(fun k word -> at k, word) in
  let host n =
    { Lockstep.Host.idle with
      tx = List.Assoc.find schedule n ~equal:Int.equal
    ; pop_rx = true
    }
  in
  let pins = ref [] in
  let underflow = ref None in
  let react (m : Machine.t) =
    pins := m.pin_out :: !pins;
    if m.fault.underflow && Option.is_none !underflow then underflow := Some (m.now - 1)
  in
  let cycles = List.last_exn (deadlines t ~words) + frame in
  let finished, mismatch =
    Lockstep.run ~cycles ~host ~react ~config ~program ~inputs:(fun _ -> 0) ()
  in
  if Option.is_some mismatch then print_s [%message "RTL and model came apart"];
  if finished.fault.overflow then print_s [%message "overflow"];
  List.rev !pins, !underflow
;;

let first_difference a b =
  List.zip_exn a b |> List.findi ~f:(fun _ (a, b) -> a <> b) |> Option.map ~f:fst
;;

(* Every word on time, then every word a frame early, then one word at a time a cycle
   late. On time never faults and sends what early sends, cycle for cycle; a cycle late
   faults in the cycle the core takes the word, and the pins are the same up to it. *)
let feed (t : Certified.t) ~words =
  let deadlines = deadlines t ~words in
  let deadline = List.nth_exn deadlines in
  let gaps =
    List.map2_exn (List.tl_exn deadlines) (List.drop_last_exn deadlines) ~f:( - )
  in
  print_s [%message t.name (deadlines : int list) (gaps : int list)];
  let frame = List.hd_exn gaps in
  let run = run t ~words ~frame in
  let early, early_fault = run ~at:(fun k -> Int.max 0 (deadline k - frame)) in
  let on_time, on_time_fault = run ~at:deadline in
  print_s
    [%message
      (early_fault : int option)
        (on_time_fault : int option)
        ~pins_differ:(first_difference early on_time : int option)];
  List.iteri words ~f:(fun k _ ->
    let late, fault = run ~at:(fun j -> deadline j + if j = k then 1 else 0) in
    print_s
      [%message
        "one late"
          (k : int)
          (fault : int option)
          ~pins_differ:(first_difference on_time late : int option)])
;;

let%expect_test "uart: each byte's deadline, on time and a cycle late" =
  feed (Certified.find_exn "uart_tx_stream") ~words:[ 0x55; 0x33; 0x0f; 0xa5; 0x81; 0x99 ];
  [%expect
    {|
    (uart_tx_stream (deadlines (18 98 178 258 338 418)) (gaps (80 80 80 80 80)))
    ((early_fault ()) (on_time_fault ()) (pins_differ ()))
    ("one late" (k 0) (fault (19)) (pins_differ (19)))
    ("one late" (k 1) (fault (99)) (pins_differ (99)))
    ("one late" (k 2) (fault (179)) (pins_differ (179)))
    ("one late" (k 3) (fault (259)) (pins_differ (259)))
    ("one late" (k 4) (fault (339)) (pins_differ (339)))
    ("one late" (k 5) (fault (419)) (pins_differ (419)))
    |}]
;;

let%expect_test "spi: each byte's deadline, on time and a cycle late" =
  feed
    (Certified.find_exn "spi_master_stream")
    ~words:(List.map [ 0xaa; 0xc3; 0xf0; 0x96; 0x81; 0xe7 ] ~f:(fun byte -> byte lsl 8));
  [%expect
    {|
    (spi_master_stream (deadlines (9 137 265 393 521 649))
     (gaps (128 128 128 128 128)))
    ((early_fault ()) (on_time_fault ()) (pins_differ ()))
    ("one late" (k 0) (fault (10)) (pins_differ (10)))
    ("one late" (k 1) (fault (138)) (pins_differ (138)))
    ("one late" (k 2) (fault (266)) (pins_differ (266)))
    ("one late" (k 3) (fault (394)) (pins_differ (394)))
    ("one late" (k 4) (fault (522)) (pins_differ (522)))
    ("one late" (k 5) (fault (650)) (pins_differ (650)))
    |}]
;;
