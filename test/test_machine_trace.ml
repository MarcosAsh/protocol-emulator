open! Core
open Protocol_emulator

let trace ?(cycles = 200) ?(tx = []) source =
  let program = Asm.assemble source |> ok_exn in
  let machine =
    Machine.create
      ~config:(Asm.Program.configure program Program_config.default)
      ~program:(Asm.Program.words program |> ok_exn)
    |> ok_exn
  in
  Machine_trace.run machine ~cycles ~tx ~inputs:[]
;;

(* The level [to_string] prints for [pin] at each cycle, from its edge lines alone. *)
let printed_level text ~pin =
  let lines =
    String.split_lines text
    |> List.drop_while ~f:(fun line -> not (String.is_prefix line ~prefix:(pin ^ "  st")))
  in
  let words =
    List.hd_exn lines
    :: List.take_while (List.tl_exn lines) ~f:(String.is_prefix ~prefix:"      ")
    |> String.concat
    |> (fun line -> String.drop_prefix line 6)
    |> String.split ~on:','
    |> List.map ~f:(fun word -> String.split (String.strip word) ~on:' ')
  in
  let starts = List.mem (List.hd_exn words) "high" ~equal:String.equal in
  let edges =
    List.filter_map (List.tl_exn words) ~f:(function
      | "rise" :: cycle :: _ -> Some (Int.of_string cycle, true)
      | "fall" :: cycle :: _ -> Some (Int.of_string cycle, false)
      | _ -> None)
  in
  fun cycle ->
    List.fold edges ~init:starts ~f:(fun level (edge, to_) ->
      if edge <= cycle then to_ else level)
;;

(* 8N1, LSB first, each bit sampled at its middle *)
let decode_uart level ~start ~period =
  List.init 8 ~f:(fun i ->
    Bool.to_int (level (start + (period * (i + 1)) + (period / 2))) lsl i)
  |> List.fold ~init:0 ~f:( lor )
;;

let%expect_test "the byte pushed to uart_tx comes back off the pin it prints" =
  let text =
    trace ~tx:[ { word = 0x5a; cycle = 0 } ] (In_channel.read_all "uart_tx.asm")
    |> Machine_trace.to_string
  in
  print_string text;
  let level = printed_level text ~pin:"OUT0" in
  let start = List.find_exn (List.range 1 200) ~f:(fun cycle -> not (level cycle)) in
  let byte = decode_uart level ~start ~period:16 in
  print_s [%message (start : int) (byte : Int.Hex.t)];
  [%test_result: int] byte ~expect:0x5a;
  [%expect
    {|
    cycles 0 to 199, 4 a column: _ low, - high, | both
    OUT0  ||_______|---|___|-------|___|---|___|------------

    OUT0  starts low, rise 1, fall 6 +5, rise 38 +32, fall 54 +16, rise 70 +16, fall 102 +32,
          rise 118 +16, fall 134 +16, rise 150 +16

    rx: empty
    faults: none
    ((start 6) (byte 0x5a))
    |}]
;;

let%expect_test "late firmware is refused, and the model shows how late" =
  let source =
    String.substr_replace_all
      (In_channel.read_all "uart_tx.asm")
      ~pattern:"out pins, 1"
      ~with_:"out pins, 1 [13]"
  in
  (match Timed_program.check ~config:Program_config.default source with
   | Ok _ -> print_s [%message "accepted"]
   | Error { faults; _ } -> print_s [%message (faults : Timed_program.Fault.t list)]);
  trace ~tx:[ { word = 0x5a; cycle = 0 } ] source
  |> Machine_trace.to_string
  |> print_string;
  [%expect
    {|
    (faults
     (((line 12) (pc (8))
       (reason
        "this deadline wait can be reached late, as a pass of its loop takes 17 cycles and moves the deadline by 16, so the wait falls 1 cycle further behind each pass"))
      ((line 15) (pc (11))
       (reason "this deadline wait can be reached 1 cycle or more late"))
      ((line 17) (pc (13))
       (reason
        "this deadline wait can be reached late, by more on each pass of a loop or after an untimed wait"))))
    cycles 0 to 199, 4 a column: _ low, - high, | both
    OUT0  ||_______|----____|-------|____----|___|----------

    OUT0  starts low, rise 1, fall 6 +5, rise 39 +33, fall 56 +17, rise 73 +17, fall 107 +34,
          rise 124 +17, fall 141 +17, rise 158 +17

    rx: empty
    fault missed_deadline at cycle 38, pc 8
    |}]
;;

let%expect_test "words the firmware never pulls, and the pins as a VCD" =
  let trace =
    trace
      ~cycles:12
      ~tx:(List.init 10 ~f:(fun word -> { Machine_trace.Tx.word; cycle = word }))
      (In_channel.read_all "uart_tx.asm")
  in
  print_string (Machine_trace.to_string trace);
  print_string (Machine_trace.to_vcd trace);
  [%expect
    {|
    cycles 0 to 11, one a column: _ low, - high, | both
    OUT0  _-----______

    OUT0  starts low, rise 1, fall 6 +5

    rx: empty
    tx: 9 words never pulled
    faults: none
    $timescale 1ns $end
    $scope module core $end
    $var wire 1 ! OUT0 $end
    $upscope $end
    $enddefinitions $end
    #0
    0!
    #20
    1!
    #120
    0!
    #240
    |}]
;;

let%expect_test "inputs and tx words from the command line" =
  List.iter
    [ "IN0=1"; "w3=0@100"; "13=1@7"; "OUT0=1"; "IN0=2"; "IN9=1"; "0=1@-1" ]
    ~f:(fun text ->
      print_s
        [%message
          text
            ~_:
              (Or_error.try_with (fun () -> Machine_trace.Input.of_string text)
               : Machine_trace.Input.t Or_error.t)]);
  List.iter [ "0x5a"; "65535@3"; "65536" ] ~f:(fun text ->
    print_s
      [%message
        text
          ~_:
            (Or_error.try_with (fun () -> Machine_trace.Tx.of_string text)
             : Machine_trace.Tx.t Or_error.t)]);
  [%expect
    {|
    (IN0=1 (Ok ((pin 0) (level true) (cycle 0))))
    (w3=0@100 (Ok ((pin 23) (level false) (cycle 100))))
    (13=1@7 (Ok ((pin 13) (level true) (cycle 7))))
    (OUT0=1 (Error ("only the core drives an output pin" (text OUT0=1))))
    (IN0=2 (Error ("expected PIN=LEVEL or PIN=LEVEL@CYCLE" (text IN0=2))))
    (IN9=1 (Error ("no such pin" (text IN9))))
    (0=1@-1 (Error ("negative cycle" (cycle -1))))
    (0x5a (Ok ((word 90) (cycle 0))))
    (65535@3 (Ok ((word 65535) (cycle 3))))
    (65536 (Error ("not a 16-bit word" (text 65536))))
    |}]
;;
