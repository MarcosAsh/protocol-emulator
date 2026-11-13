open! Core
open Protocol_emulator
open Playground_checks

let clock_hz = 48_000_000

let show (r : Timing_table.Report.t) =
  print_endline r.verdict;
  print_endline r.detail;
  if not (String.is_empty r.limits) then print_endline r.limits
;;

(* what the page certifies goes through the kernel and the chip's load check again, from
   the source it shows *)
let%expect_test "the page's examples" =
  List.iter Table_example.all ~f:(fun (name, cited, table) ->
    print_endline [%string "== %{name}, %{cited}"];
    let r = Timing_table.run ~clock_hz table in
    show r;
    Option.iter r.firmware ~f:(fun (config, period) ->
      match Timed_program.check ~period ~config r.source with
      | Ok timed ->
        print_endline ("again: " ^ Chip_verdict.to_string (Chip_verdict.of_timed timed))
      | Error refusal -> print_s [%message "again: refused" (refusal.error : Error.t)]));
  [%expect
    {|
    == WS2812B, Worldsemi WS2812B datasheet, p.3, Data transfer time
    certified
    unit: 20 cycles, 416.7 ns at 48 MHz, the period 20 times 1
    37 words, 9 deadline waits, worst slack 10
    kernel: accepted, so no deadline is missed by the step lemma
    chip: its load check accepts the 54-word certificate
    model: two frames run on the engine's model, read back as sent, each run as the limits say
    certificate, 54 words: 0008 0006 0200 0001 0000 0480 4001 0008 0580 8001 0008 0a00 c001 0008 0d01 0001 000c 0e81 4001 0010 0f01 8001 0a10 1101 8001 040c ffff efff fff0 ffff f1ff fff3 ffff f4ff fff6 ffff f0ff fff1 ffff efff fff1 ffff efff fff2 0014 0014 0000 0017 ffff ffff 0000 0002 0000 001f
    T0H        250.0 ns to 550.0 ns     1 x 20 cycles = 416.7 ns  ok
    T0L        700.0 ns to 1000.0 ns    2 x 20 cycles = 833.3 ns  ok
    T1H        650.0 ns to 950.0 ns     2 x 20 cycles = 833.3 ns  ok
    T1L        300.0 ns to 600.0 ns     1 x 20 cycles = 416.7 ns  ok
    RES        at least 50.000 us       at least 121 x 20 cycles = 50.417 us  ok
    TH+TL      650.0 ns to 1850.0 ns    not checked: no run of the shape
    again: chip: its load check accepts the 54-word certificate
    == MIDI, MMA/AMEI CA-033 (2014), p.2, Hardware
    certified
    unit: 1536 cycles, 32.000 us at 48 MHz, the period 1536 times 1
    27 words, 7 deadline waits, worst slack 1529
    kernel: accepted, so no deadline is missed by the step lemma
    chip: its load check accepts the 39-word certificate
    model: two frames run on the engine's model, read back as sent, each run as the limits say
    certificate, 39 words: 0005 0004 0200 0001 0000 0480 4001 0008 0600 8001 0608 0980 c001 0a10 0a81 0001 0a14 fffa 03ff fa07 fffa 03ff fa04 fffa 04ff fa04 fffa 06ff fa06 0600 0600 0000 0002 0000 0007 0000 0001 ffff ffff
    rate       31.683 us to 32.323 us   1 x 1536 cycles = 32.000 us  ok
    again: chip: its load check accepts the 39-word certificate
    == 10BASE-T, IEEE 802.3i-1990, Clause 14
    refused: no unit at 48 MHz fits BR
    BR, 100.0 ns to 100.0 ns, is 4.80 to 4.80 cycles at 48 MHz: no whole number clears both ends by a cycle
    the kernel takes this firmware at 10 cycles a unit, 208.3 ns, or more
    BR is 20 cycles, 416.7 ns; its max of 100.0 ns allows 3, 354.2 ns over
    |}]
;;

(* one of each shape and refusal, with what the model run made of it *)
let%expect_test "each shape" =
  List.iter
    [ ( "clocked, at least 100 ns a phase"
      , "shape clocked\nbits 8\nhigh h\nlow l\nh 100 - ns\nl 100 - ns" )
    ; ( "clocked, falling edge, idle high, at most 1 MHz"
      , "shape clocked\nbits 12\nclock c\nsample falling\nclock-idle high\nc - 1 mhz" )
    ; "manchester, 1 Mbit/s +-10%", "shape manchester\nbits 16\nbit b\nb 0.9 1.1 mbit/s"
    ; ( "pulse, with a leader and a trailer"
      , "shape pulse\n\
         bits 32\n\
         leader lm ls\n\
         trailer m\n\
         zero m s0\n\
         one m s1\n\
         gap g\n\
         lm 8.5 9.5 ms\n\
         ls 4.2 4.8 ms\n\
         m 500 620 us\n\
         s0 500 620 us\n\
         s1 1.6 1.8 ms\n\
         g 40 - ms" )
    ; "uart, faster than the kernel", "shape uart\nbit b\nb - 100 ns"
    ; "a gap with a max", "shape uart\nbit b\ngap g\nb 8 9 us\ng 10 20 us"
    ; "a row the shape lacks", "shape uart\nbit b"
    ]
    ~f:(fun (name, table) ->
      print_endline ("== " ^ name);
      let r = Timing_table.run ~model_cycles:20_000_000 ~clock_hz table in
      print_endline r.verdict;
      List.filter (String.split_lines r.detail) ~f:(String.is_prefix ~prefix:"model")
      |> List.iter ~f:print_endline;
      print_endline r.limits);
  [%expect
    {|
    == clocked, at least 100 ns a phase
    certified
    model: two frames run on the engine's model, read back as sent, each run as the limits say
    h          at least 100.0 ns        1 x 7 cycles = 145.8 ns  ok
    l          at least 100.0 ns        1 x 7 cycles = 145.8 ns  ok
    == clocked, falling edge, idle high, at most 1 MHz
    certified
    model: two frames run on the engine's model, read back as sent, each run as the limits say
    c          at least 1000.0 ns       2 x 25 cycles = 1041.7 ns  ok
    == manchester, 1 Mbit/s +-10%
    certified
    model: two frames run on the engine's model, read back as sent, each run as the limits say
    b          909.1 ns to 1111.1 ns    2 x 24 cycles = 1000.0 ns  ok
    == pulse, with a leader and a trailer
    certified
    model: two frames run on the engine's model, read back as sent, each run as the limits say
    lm         8.500 ms to 9.500 ms     16 x 26880 cycles = 8.960 ms  ok
    ls         4.200 ms to 4.800 ms     8 x 26880 cycles = 4.480 ms  ok
    m          500.000 us to 620.000 us 1 x 26880 cycles = 560.000 us  ok
    s0         500.000 us to 620.000 us 1 x 26880 cycles = 560.000 us  ok
    s1         1.600 ms to 1.800 ms     3 x 26880 cycles = 1.680 ms  ok
    g          at least 40.000 ms       at least 72 x 26880 cycles = 40.320 ms  ok
    == uart, faster than the kernel
    refused: b, as the kernel needs a unit of 6 cycles at 48 MHz

    == a gap with a max
    refused: g, as the host paces frames, so a gap has no max the firmware can hold

    == a row the shape lacks
    not read
    |}]
;;
