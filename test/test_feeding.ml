open! Core
open Protocol_emulator

let assemble (t : Certified.t) =
  let program = Asm.assemble t.source |> ok_exn in
  program, Asm.Program.configure program t.config
;;

let stream = Certified.find_exn "uart_tx_stream"

let%expect_test "only firmware that never waits on the host is time-triggered" =
  List.iter
    [ Certified.find_exn "uart_tx"; stream ]
    ~f:(fun t ->
      let program, _ = assemble t in
      print_s [%message t.name ~_:(Feeding.time_triggered program : unit Or_error.t)]);
  [%expect
    {|
    (uart_tx (Error ("waits on the host" (pcs (2)))))
    (uart_tx_stream (Ok ()))
    |}]
;;

let%expect_test "the streaming uart keeps its certificate" =
  let program, config = assemble stream in
  print_endline
    (Analyser.to_string
       ~side_set_count:config.side_set_count
       (Analyser.analyse ~config program.instructions));
  print_s [%message (Analyser.check ~config program : Analyser.Verdict.t Or_error.t)];
  [%expect
    {|
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
    |}]
;;

let words = [ 0x55; 0x33; 0x0f; 0xa5; 0x81; 0x99 ]

let deadlines =
  let program, config = assemble stream in
  Feeding.schedule ~config program ~words:(List.length words) |> ok_exn
;;

let%expect_test "the feeding schedule: the last cycle the host can send each byte" =
  print_s [%message (deadlines : int list)];
  let gaps =
    List.map2_exn (List.tl_exn deadlines) (List.drop_last_exn deadlines) ~f:( - )
  in
  print_s [%message (gaps : int list)];
  [%expect {|
    (deadlines (18 98 178 258 338 418))
    (gaps (80 80 80 80 80))
    |}]
;;

(* The RTL and the model side by side, the host writing byte [k] in cycle [at k]. Returns
   the pins after every cycle and the cycle in which the underflow fault was set. The run
   stops before the pull after the last byte, which no host feeds. *)
let run ~at =
  let _, config = assemble stream in
  let program = Firmware.assemble stream.source in
  let schedule = List.mapi words ~f:(fun k word -> at k, word) in
  let host n =
    { Lockstep.Host.idle with tx = List.Assoc.find schedule n ~equal:Int.equal }
  in
  let levels = ref [] in
  let underflow = ref None in
  let react (m : Machine.t) =
    levels := m.pin_out :: !levels;
    if m.fault.underflow && Option.is_none !underflow then underflow := Some (m.now - 1)
  in
  let cycles = List.last_exn deadlines + 80 in
  let _, mismatch =
    Lockstep.run ~cycles ~host ~react ~config ~program ~inputs:(fun _ -> 0) ()
  in
  if Option.is_some mismatch then print_s [%message "RTL and model came apart"];
  List.rev !levels, !underflow
;;

let first_difference a b =
  List.zip_exn a b |> List.findi ~f:(fun _ (a, b) -> a <> b) |> Option.map ~f:fst
;;

let%expect_test "on time never faults; a cycle late faults, and moves no edge before" =
  let deadline = List.nth_exn deadlines in
  (* as early as the fifo allows, a frame ahead *)
  let early, early_fault = run ~at:(fun k -> Int.max 0 (deadline k - 80)) in
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
        (k : int)
          ~deadline:(deadline k : int)
          (fault : int option)
          ~pins_differ:(first_difference on_time late : int option)]);
  [%expect
    {|
    ((early_fault ()) (on_time_fault ()) (pins_differ ()))
    ((k 0) (deadline 18) (fault (19)) (pins_differ (19)))
    ((k 1) (deadline 98) (fault (99)) (pins_differ (99)))
    ((k 2) (deadline 178) (fault (179)) (pins_differ (179)))
    ((k 3) (deadline 258) (fault (259)) (pins_differ (259)))
    ((k 4) (deadline 338) (fault (339)) (pins_differ (339)))
    ((k 5) (deadline 418) (fault (419)) (pins_differ (419)))
    |}]
;;
