open! Core
open Protocol_emulator
open Ws2812

let pixel red green blue = { Pixel.red; green; blue }

(* six pixels are twelve words, more than the fifo holds, so the host tops it up while the
   string is going out; the second frame comes after the first has latched *)
let first_frame =
  [ pixel 0xff 0x00 0x00
  ; pixel 0x00 0xff 0x00
  ; pixel 0x00 0x00 0xff
  ; pixel 0x12 0x34 0x56
  ; pixel 0xa5 0x5a 0xc3
  ; pixel 0x00 0x00 0x00
  ]
;;

let second_frame = [ pixel 0x80 0x01 0x7e ]
let second_frame_cycle = 16_000
let cycles = 20_500

let schedule =
  List.concat_map first_frame ~f:Pixel.words @ List.concat_map second_frame ~f:Pixel.words
  |> List.mapi ~f:(fun i word -> (if i < 12 then 0 else second_frame_cycle), word)
;;

(* the word the host writes in cycle [n], if it is due and there is room *)
let due schedule ~n ~tx_level =
  match schedule with
  | (cycle, word) :: rest when cycle <= n && tx_level < Machine.fifo_depth ->
    Some word, rest
  | schedule -> None, schedule
;;

let level (m : Machine.t) = (m.pin_out lsr pin) land 1

let print_strip strip (fault : Machine.Fault.t) =
  print_s
    [%message
      ""
        ~frames:(Strip.frames strip : Pixel.t list list)
        ~measured_ns:(Strip.measured strip : Measured.t)
        ~violations:
          (Strip.violations strip |> List.dedup_and_sort ~compare:String.compare
           : string list)
        (fault : Machine.Fault.t)]
;;

let run source =
  let t = Machine.create ~config ~program:(Firmware.assemble source) |> ok_exn in
  let rec loop (t : Machine.t) strip schedule n =
    if n = cycles
    then t, strip
    else (
      let word, schedule = due schedule ~n ~tx_level:(List.length t.tx_fifo) in
      let t = Option.fold word ~init:t ~f:(fun t w -> Machine.write_tx t w |> ok_exn) in
      let t = Machine.step t ~inputs:0 in
      loop t (Strip.step strip ~level:(level t)) schedule (n + 1))
  in
  let t, strip = loop t (Strip.create ~cycle_ns) schedule 0 in
  strip, t.fault
;;

let%expect_test "two frames come out of the string as they went in" =
  let strip, fault = run standard in
  print_strip strip fault;
  [%expect
    {|
    ((frames
      ((((red 255) (green 0) (blue 0)) ((red 0) (green 255) (blue 0))
        ((red 0) (green 0) (blue 255)) ((red 18) (green 52) (blue 86))
        ((red 165) (green 90) (blue 195)) ((red 0) (green 0) (blue 0)))
       (((red 128) (green 1) (blue 126)))))
     (measured_ns
      ((T0H (400 400)) (T0L (840 840)) (T1H (800 800)) (T1L (440 440))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "ws2812 in lockstep" =
  let strip = ref (Strip.create ~cycle_ns) in
  let schedule = ref schedule in
  let tx_level = ref 0 in
  let model =
    Lockstep.lockstep
      ~cycles
      ~config
      ~program:(Firmware.assemble standard)
      ~inputs:(fun _ -> 0)
      ~host:(fun n ->
        let tx, rest = due !schedule ~n ~tx_level:!tx_level in
        schedule := rest;
        { Lockstep.Host.idle with tx })
      ~react:(fun m ->
        tx_level := List.length m.tx_fifo;
        strip := Strip.step !strip ~level:(level m))
      ()
  in
  print_strip !strip model.fault;
  [%expect
    {|
    ("lockstep held" (cycles 20500))
    ((frames
      ((((red 255) (green 0) (blue 0)) ((red 0) (green 255) (blue 0))
        ((red 0) (green 0) (blue 255)) ((red 18) (green 52) (blue 86))
        ((red 165) (green 90) (blue 195)) ((red 0) (green 0) (blue 0)))
       (((red 128) (green 1) (blue 126)))))
     (measured_ns
      ((T0H (400 400)) (T0L (840 840)) (T1H (800 800)) (T1L (440 440))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "every edge is placed by a deadline" =
  Timing_report.print ~config standard;
  [%expect
    {|
      1  set pins, 0                  phase 1  edge 2
     19  set pins, 1                  phase -19  edge -18
     21  out pins, 1                  phase -19  edge -18
     23  set pins, 0                  phase -19  edge -18
    ((words 32) (edge_jitter 0) (sample_jitter 0) (side_jitter 0) (may_miss 0))
    |}]
;;

let%expect_test "the shortest bit the structure can make" =
  Timing_report.print ~config (firmware ~third:6 ~tail:7);
  [%expect
    {|
      1  set pins, 0                  phase 1  edge 2
     19  set pins, 1                  phase -5  edge -4
     21  out pins, 1                  phase -5  edge -4
     23  set pins, 0                  phase -5  edge -4
    ((words 32) (edge_jitter 0) (sample_jitter 0) (side_jitter 0) (may_miss 0))
    |}]
;;

(* one cycle less and the thirteen cycles round the end of a word no longer fit: the
   analyser says so and the core raises the fault *)
let%expect_test "a bit too short for the end of a word" =
  let source = firmware ~third:6 ~tail:6 in
  Timing_report.print ~config source;
  [%expect
    {|
      1  set pins, 0                  phase 1  edge 2
     18  wait t+                      phase -7..1  slack -1..7  MAY MISS
     19  set pins, 1                  phase -5..-4  edge -4..-3  jitter 1
     21  out pins, 1                  phase -5  edge -4
     23  set pins, 0                  phase -5  edge -4
    ((words 32) (edge_jitter 1) (sample_jitter 0) (side_jitter 0) (may_miss 1))
    |}];
  let (_ : Strip.t), fault = run source in
  print_s [%message (fault : Machine.Fault.t)];
  [%expect
    {|
    (fault
     ((underflow false) (overflow false) (missed_deadline true) (decode false)))
    |}]
;;

(* the firmware keeps every deadline, but a zero of 580 ns is not a zero: the string says
   so *)
let%expect_test "a third of 29 cycles is out of tolerance" =
  let strip, fault = run (firmware ~third:29 ~tail:0) in
  print_strip strip fault;
  [%expect
    {|
    ((frames ())
     (measured_ns
      ((T0H (580 580)) (T0L (1160 1160)) (T1H (1160 1160)) (T1L (580 580))))
     (violations ("T0H of 580 ns" "T0L of 1160 ns" "T1H of 1160 ns"))
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
