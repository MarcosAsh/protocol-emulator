open! Core
open Pio

let programs text = Pioasm.parse text |> ok_exn

let vendored file name =
  In_channel.read_all ("pico_examples/" ^ file)
  |> programs
  |> List.find_exn ~f:(fun (program : Pioasm.Program.t) -> String.equal program.name name)
;;

let pins specs = List.map specs ~f:(fun spec -> Timing.Pin.of_string spec |> ok_exn)
let rules specs = List.map specs ~f:(fun spec -> Timing.Rule.of_string spec |> ok_exn)

let initially high (pins : Timing.Pin.t list) =
  List.map pins ~f:(fun pin -> { pin with initial = Some high })
;;

let check ?(config = Timing.Config.default) program =
  let report = Timing.analyse config program in
  print_string (Timing.Report.to_string report);
  print_s [%message "" ~passed:(Timing.Report.passed report : bool)]
;;

let%expect_test "a square wave: each edge ends a pulse of known width" =
  programs
    {|
.program square
    set pindirs, 1
.wrap_target
    set pins, 1 [2]
    set pins, 0
    jmp next [1]
next:
    nop
.wrap
|}
  |> List.hd_exn
  |> check
       ~config:
         { Timing.Config.default with rules = rules [ "high: set0+ -> set0- >= 3" ] };
  [%expect
    {|
    square
      0  set pindirs, 1                    1  -
      1  set pins, 1 [2]                   3  -              set0+ -,4
      2  set pins, 0                       1  -              set0- 3
      3  jmp next [1]                      2  -
      4  nop                               1  -
    high: set0+ -> set0- >= 3 cycles: ok, 3 cycles at pc 2
    (passed true)
    |}]
;;

let%expect_test "uart_tx: every bit is 8 cycles and the stop bit at least 8" =
  vendored "uart_tx.pio" "uart_tx"
  |> check
       ~config:
         { Timing.Config.default with
           pins = pins [ "tx=out0,side0" ] |> initially true
         ; fifo_ready = true
         ; rules = rules [ "bit: tx -> tx >= 8" ]
         };
  [%expect
    {|
    uart_tx
      0  pull side 1 [7]                   8  -              tx+ 8
      1  set x, 7 side 0 [7]               8  -              tx- -,8
      2  out pins, 1                       1  -              tx- 8  tx+ 8,16
      3  jmp x-- bitloop [6]               7  -
    bit: tx -> tx >= 8 cycles: ok, 8 cycles at pc 0
    (passed true)
    |}]
;;

let%expect_test "uart_rx: samples 12 + 8k after the start edge's wait, the next wait at \
                 78"
  =
  vendored "uart_rx.pio" "uart_rx"
  |> check
       ~config:
         { Timing.Config.default with
           pins = pins [ "rx=in0,jmp" ]
         ; fifo_ready = true
         ; cell = Some 8
         };
  [%expect
    {|
    uart_rx
      0  wait 0 pin 0                     1+  -,2..78        samples rx  anchor
      1  set x, 7 [10]                    11  1
      2  in pins, 1                        1  12..68         samples rx
      3  jmp x-- bitloop [6]               7  13..69
      4  jmp pin good_stop                 1  76             samples rx
      5  irq 4 rel                         1  77
      6  wait 1 pin 0                     1+  78             samples rx  anchor
      7  jmp start                         1  1
      8  push                              1  77
    cells of 8 cycles from each anchor: sender may run 3.75% fast or 5.56% slow
    (passed true)
    |}]
;;

let%expect_test "uart_rx tolerates less sender error as the divider nears 1" =
  let program = vendored "uart_rx.pio" "uart_rx" in
  List.iter [ 115_200.; 3e6; 12e6; 15.625e6 ] ~f:(fun baud ->
    let clkdiv = 125e6 /. (8. *. baud) in
    let report =
      Timing.analyse
        { Timing.Config.default with
          fifo_ready = true
        ; cell = Some 8
        ; clock = Some { sys_hz = 125e6; clkdiv }
        }
        program
    in
    let receiver =
      Timing.Report.to_string report
      |> String.split_lines
      |> List.find_exn ~f:(String.is_prefix ~prefix:"cells")
    in
    printf "%10.0f baud, clkdiv %8.4f: %s\n" baud clkdiv receiver);
  [%expect
    {|
      115200 baud, clkdiv 135.6337: cells of 8 cycles from each anchor: sender may run 3.73% fast or 5.54% slow
     3000000 baud, clkdiv   5.2083: cells of 8 cycles from each anchor: sender may run 3.28% fast or 5.07% slow
    12000000 baud, clkdiv   1.3021: cells of 8 cycles from each anchor: sender may run 1.60% fast or 3.47% slow
    15625000 baud, clkdiv   1.0000: cells of 8 cycles from each anchor: sender may run 2.50% fast or 4.17% slow
    |}]
;;

let%expect_test "ws2812: T1 = 3 high for a 0, T1 + T2 = 6 for a 1, low at least T3" =
  vendored "ws2812.pio" "ws2812"
  |> check
       ~config:
         { Timing.Config.default with
           autopull = true
         ; pins = pins [ "din=side0" ]
         ; rules = rules [ "t0h: din+ -> din- >= 3"; "tl: din- -> din+ >= 4" ]
         };
  [%expect
    {|
    ws2812
      0  out x, 1 side 0 [T3 - 1]         4+  -              din- -,6
      1  jmp !x do_zero side 1 [T1 - 1]    3  -              din+ 4..?
      2  jmp bitloop side 1 [T2 - 1]       3  -
      3  nop side 0 [T2 - 1]               3  -              din- 3
    t0h: din+ -> din- >= 3 cycles: ok, 3 cycles at pc 3
    tl: din- -> din+ >= 4 cycles: ok, 4 cycles at pc 1
    (passed true)
    |}]
;;

(* 1 us a cycle as onewire_library.c sets it; Maxim's standard-speed slot is A = 6, C =
   60, D = 10, E = 9, H = 480, I = 70 us. *)
let%expect_test "onewire: the slots match Maxim's recommended timings" =
  vendored "onewire_library.pio" "onewire"
  |> check
       ~config:
         { Timing.Config.default with
           fifo_ready = true
         ; pins = pins [ "dq=side0:!dir,in0" ] |> initially true
         ; clock = Some { sys_hz = 125e6; clkdiv = 125. }
         ; rules = rules [ "t_rec: dq+ -> dq- >= 1us"; "t_low1: dq- -> dq+ >= 1us" ]
         };
  [%expect
    {|
    onewire
      0  set x, 28 side 1 [15]            16  -              dq-
      1  jmp x-- loop_a side 1 [15]       16  -
      2  set x, 8 side 0 [6]               7  -              dq+ 480
      3  jmp x-- loop_b side 0 [6]         7  -
      4  mov isr, pins side 0              1  -              samples dq (dq+ 70, dq- 550)
      5  push side 0                       1  -
      6  set x, 24 side 0 [7]              8  -
      7  jmp x-- loop_c side 0 [15]       16  -
      8  out x, 1 side 0                   1  -
      9  jmp !x send_0 side 1 [5]          6  -              dq- 10..481
     10  set x, 2 side 0 [8]               9  -              dq+ 6
     11  in pins, 1 side 0 [4]             5  -              samples dq (dq+ 9, dq- 15)
     12  jmp x-- loop_e side 0 [15]       16  -
     13  jmp fetch_bit side 0              1  -
     14  set x, 2 side 1 [5]               6  -
     15  jmp x-- loop_d side 1 [15]       16  -
     16  in null, 1 side 0 [8]             9  -              dq+ 60
    t_rec: dq+ -> dq- >= 1us: ok, 10 cycles (10000ns) at pc 9
    t_low1: dq- -> dq+ >= 1us: ok, 6 cycles (6000ns) at pc 10
    (passed true)
    |}]
;;

let%expect_test "manchester_rx samples a third of a bit in, not the quarter its comment \
                 says"
  =
  vendored "manchester_encoding.pio" "manchester_rx"
  |> check
       ~config:
         { Timing.Config.default with pins = pins [ "rx=in0,jmp" ]; fifo_ready = true };
  [%expect
    {|
    manchester_rx
      0  wait 0 pin 0                     1+  -,11           samples rx  anchor
      1  in y, 1 [8]                       9  1
      2  jmp pin start_of_0                1  10             samples rx
      3  wait 1 pin 0                     1+  11             samples rx  anchor
      4  in x, 1 [8]                       9  1
      5  jmp pin start_of_0                1  10             samples rx
    (passed true)
    |}]
;;

(* The escape sequences pio_i2c.c sends, each after an instruction count of its length
   less one, which [out x, 6] takes; [scl] is the side-set pin, [sda] the set pin. *)
let i2c_sequences ~hold =
  let sc0_sd0 = "set pindirs, 0 side 0 [7]" in
  let sc0_sd1 = "set pindirs, 1 side 0 [7]" in
  let sc1_sd0 = "set pindirs, 0 side 1 [7]" in
  let sc1_sd1 = "set pindirs, 1 side 1 [7]" in
  let held step = List.init hold ~f:(fun _ -> step) in
  let sequence guard steps =
    let x = List.length steps - 1 in
    [%string "x=%{x#Int},%{guard}: %{String.concat ~sep:\" | \" steps}"]
  in
  [ sequence "scl=1,sda=1" (held sc1_sd0 @ [ sc0_sd0; "mov isr, null" ])
  ; sequence "scl=0" ([ sc0_sd0 ] @ held sc1_sd0 @ [ sc1_sd1 ])
  ; sequence
      "scl=0"
      ([ sc0_sd1 ] @ held sc1_sd1 @ held sc1_sd0 @ [ sc0_sd0; "mov isr, null" ])
  ]
;;

(* UM10204 table 10, Standard-mode, at the 100 kHz pio_i2c.pio sets on a 125 MHz clock. *)
let check_i2c ~hold program =
  check
    program
    ~config:
      { Timing.Config.default with
        pins =
          pins [ "sda=set0:dir,out0:dir,in0,jmp"; "scl=side0:dir,in1" ] |> initially true
      ; autopull = true
      ; autopush = true
      ; irq_wait_halts = true
      ; entry = Some "entry_point"
      ; exec =
          List.map (i2c_sequences ~hold) ~f:(fun sequence ->
            Timing.Exec_sequence.of_string program sequence |> ok_exn)
      ; clock = Some { sys_hz = 125e6; clkdiv = 125e6 /. (32. *. 100e3) }
      ; rules =
          rules
            [ "t_low: scl- -> scl+ >= 4.7us"
            ; "t_high: scl+ -> scl- >= 4.0us"
            ; "t_hd_sta: sda- -> scl- >= 4.0us"
            ; "t_su_sta: scl+ -> sda- >= 4.7us"
            ; "t_su_sto: scl+ -> sda+ >= 4.0us"
            ; "t_su_dat: sda -> scl+ >= 250ns"
            ]
      }
;;

let%expect_test "pico-examples i2c misses Standard-mode START, STOP and SCL low times" =
  vendored "i2c.pio" "i2c" |> check_i2c ~hold:1;
  [%expect
    {|
    i2c
      0  jmp y-- entry_point               1  11
      1  irq wait 0 rel                   1+  12
      2  set x, 7                          1  -,14..?,48..?,61..?
      3  out pindirs, 1 [7]               8+  -,15..?,21..?,49..?,62..? sda- -,13..?,31..?,32..?  sda+ 26..?,31..?,32..?
      4  nop side 1 [2]                    3  -,23..?,29..?,57..? scl+ 15..?,16..?,24..?
      5  wait 1 pin, 1 [4]                5+  -,26..?,32..?  samples scl (scl+ -,3..?, scl- -,18..?,19..?,27..?)  anchor
      6  in pins, 1 [7]                   8+  5              samples sda (sda+ -,16..?, sda- 16..?)
      7  jmp x-- bitloop side 0 [7]        8  13..?          scl- -,16..?
      8  out pindirs, 1 [7]               8+  21..?          sda- 32..?  sda+ 32..?
      9  nop side 1 [7]                    8  29..?          scl+ 16..?
     10  wait 1 pin, 1 [7]                8+  37..?          samples scl (scl+ 8..?, scl- 24..?)  anchor
     11  jmp pin do_nack side 0 [2]        3  8              scl- 16..?  samples sda (sda+ 24..?, sda- 24..?)
     12  out x, 6                         1+  -,11..12,45..?,58..?
     13  out y, 1                         1+  -,12..?,46..?,59..?
     14  jmp !x do_byte                    1  -,13..?,47..?,60..?
     15  out null, 32                     1+  -,14..?,48..?,61..?
     16  out exec, 16                     1+  15..?
     16    exec set pindirs, 0 side 1 [7]    8  -,50..?        sda- -,14..?
     16    exec set pindirs, 0 side 0 [7]    8  -,60..?        scl- -,34..?
     16    exec mov isr, null              1  -,70..?
     16    exec set pindirs, 0 side 0 [7]    8  -,16..?,63..?  sda- 32..?
     16    exec set pindirs, 0 side 1 [7]    8  -,26..?        scl+ 18..?,27..?
     16    exec set pindirs, 1 side 1 [7]    8  -,36..?        sda+ 20..?,47..?
     16    exec set pindirs, 1 side 0 [7]    8  -,16..?,63..?  sda+ 27..?,32..?
     16    exec set pindirs, 1 side 1 [7]    8  -,26..?        scl+ 18..?,27..?
     16    exec set pindirs, 0 side 1 [7]    8  -,36..?        sda- 20..?
     16    exec set pindirs, 0 side 0 [7]    8  -,46..?        scl- 20..?
     16    exec mov isr, null              1  -,56..?
     17  jmp x-- do_exec                   1  24..?
    t_low: scl- -> scl+ >= 4.7us: FAIL, 15 cycles (4680ns) at pc 4
    t_high: scl+ -> scl- >= 4us: ok, 16 cycles (5000ns) at pc 7
    t_hd_sta: sda- -> scl- >= 4us: FAIL, 10 cycles (3120ns) at pc 16 exec set pindirs, 0 side 0 [7]
    t_su_sta: scl+ -> sda- >= 4.7us: FAIL, 10 cycles (3120ns) at pc 16 exec set pindirs, 0 side 1 [7]
    t_su_sto: scl+ -> sda+ >= 4us: FAIL, 10 cycles (3120ns) at pc 16 exec set pindirs, 1 side 1 [7]
    t_su_dat: sda -> scl+ >= 250ns: ok, 8 cycles (2496ns) at pc 4
    (passed false)
    |}]
;;

let%expect_test "one more cycle after ACK, and each START and STOP step sent twice, meet \
                 them"
  =
  In_channel.read_all "pico_examples/i2c.pio"
  |> String.substr_replace_first
       ~pattern:"jmp pin do_nack side 0 [2]"
       ~with_:"jmp pin do_nack side 0 [3]"
  |> programs
  |> List.hd_exn
  |> check_i2c ~hold:2;
  [%expect
    {|
    i2c
      0  jmp y-- entry_point               1  12
      1  irq wait 0 rel                   1+  13
      2  set x, 7                          1  -,15..?,59..?,82..?
      3  out pindirs, 1 [7]               8+  -,16..?,21..?,60..?,83..? sda- -,13..?,32..?  sda+ 32..?,36..?
      4  nop side 1 [2]                    3  -,24..?,29..?,68..? scl+ 16..?,24..?
      5  wait 1 pin, 1 [4]                5+  -,27..?,32..?  samples scl (scl+ -,3..?, scl- -,19..?,27..?)  anchor
      6  in pins, 1 [7]                   8+  5              samples sda (sda+ -,16..?, sda- 16..?)
      7  jmp x-- bitloop side 0 [7]        8  13..?          scl- -,16..?
      8  out pindirs, 1 [7]               8+  21..?          sda- 32..?  sda+ 32..?
      9  nop side 1 [7]                    8  29..?          scl+ 16..?
     10  wait 1 pin, 1 [7]                8+  37..?          samples scl (scl+ 8..?, scl- 24..?)  anchor
     11  jmp pin do_nack side 0 [3]        4  8              scl- 16..?  samples sda (sda+ 24..?, sda- 24..?)
     12  out x, 6                         1+  -,12..13,56..?,79..?
     13  out y, 1                         1+  -,13..?,57..?,80..?
     14  jmp !x do_byte                    1  -,14..?,58..?,81..?
     15  out null, 32                     1+  -,15..?,59..?,82..?
     16  out exec, 16                     1+  16..?
     16    exec set pindirs, 0 side 1 [7]    8  -,61..?        sda- -,14..?
     16    exec set pindirs, 0 side 1 [7]    8  -,71..?
     16    exec set pindirs, 0 side 0 [7]    8  -,81..?        scl- -,54..?
     16    exec mov isr, null              1  -,91..?
     16    exec set pindirs, 0 side 0 [7]    8  -,17..?,84..?  sda- 33..?
     16    exec set pindirs, 0 side 1 [7]    8  -,27..?        scl+ 19..?,27..?
     16    exec set pindirs, 0 side 1 [7]    8  -,37..?
     16    exec set pindirs, 1 side 1 [7]    8  -,47..?        sda+ 30..?,67..?
     16    exec set pindirs, 1 side 0 [7]    8  -,17..?,84..?  sda+ 33..?,37..?
     16    exec set pindirs, 1 side 1 [7]    8  -,27..?        scl+ 19..?,27..?
     16    exec set pindirs, 1 side 1 [7]    8  -,37..?
     16    exec set pindirs, 0 side 1 [7]    8  -,47..?        sda- 30..?
     16    exec set pindirs, 0 side 1 [7]    8  -,57..?
     16    exec set pindirs, 0 side 0 [7]    8  -,67..?        scl- 40..?
     16    exec mov isr, null              1  -,77..?
     17  jmp x-- do_exec                   1  25..?
    t_low: scl- -> scl+ >= 4.7us: ok, 16 cycles (5000ns) at pc 4
    t_high: scl+ -> scl- >= 4us: ok, 16 cycles (5000ns) at pc 7
    t_hd_sta: sda- -> scl- >= 4us: ok, 20 cycles (6248ns) at pc 16 exec set pindirs, 0 side 0 [7]
    t_su_sta: scl+ -> sda- >= 4.7us: ok, 20 cycles (6248ns) at pc 16 exec set pindirs, 0 side 1 [7]
    t_su_sto: scl+ -> sda+ >= 4us: ok, 20 cycles (6248ns) at pc 16 exec set pindirs, 1 side 1 [7]
    t_su_dat: sda -> scl+ >= 250ns: ok, 8 cycles (2496ns) at pc 4
    (passed true)
    |}]
;;

let%expect_test "what the analysis cannot follow is an error, not a pass" =
  programs
    {|
.program computed
    out x, 5
    mov pc, x
.program exec
    out exec, 16
|}
  |> List.iter ~f:(check ~config:{ Timing.Config.default with autopull = true });
  [%expect
    {|
    computed
      0  out x, 5                         1+  -
      1  mov pc, x                         1  -
    ERROR pc 1: mov pc
    (passed false)
    exec
      0  out exec, 16                     1+  -
    ERROR pc 0: exec without an exec table
    (passed false)
    |}]
;;
