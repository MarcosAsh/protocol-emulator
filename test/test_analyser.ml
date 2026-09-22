open! Core
open Protocol_emulator
open Firmware

let report ?(config = Program_config.default) ?period ?single_capture_edge source =
  let program = Asm.assemble source |> ok_exn in
  Analyser.analyse
    ?period
    ?single_capture_edge
    ~config:(Asm.Program.configure program config)
    program.instructions
  |> Analyser.to_string ~side_set_count:program.side_set_count
  |> print_endline
;;

let%expect_test "uart tx" =
  report (uart_tx ~period:16);
  [%expect
    {|
     0  set p, 16                    phase ?..?
     1  set pins, 1                  phase ?..?  edge ?..?  jitter ?
     2  wait tx                      phase ?..?
     3  pull                         phase ?..?
     4  set x, 7                     phase ?..?
     5  mov t, now                   phase ?..?
     6  set pins, 0                  phase 1  edge 2
     7  add t, p                     phase 2
     8  wait t+                      phase -13..-12  slack 12..13
     9  out pins, 1                  phase -15  edge -14
    10  jmp x--, 8                   phase -14
    11  wait t+                      phase -12  slack 12
    12  set pins, 1                  phase -15  edge -14
    13  wait t                       phase -14  slack 14
    14  jmp 2                        phase 1
    |}]
;;

let%expect_test "uart rx" =
  report ~config:rx_config ~single_capture_edge:true (uart_rx ~period:16);
  [%expect
    {|
     0  set p, 16                    phase ?..?
     1  set y, 7                     phase ?..?
     2  wait 1 pin 0                 phase ?..?
     3  capture_arm                  phase ?..?
     4  wait 0 pin 0                 phase ?..?
     5  mov t, capture               phase ?..?
     6  add t, y                     phase 2..17
     7  add t, p                     phase -4..11
     8  set x, 7                     phase -19..-4
     9  wait t+                      phase -18..-3  slack 3..18
    10  in pins, 1                   phase -15  sample -15
    11  jmp x--, 9                   phase -14
    12  capture_arm                  phase -12
    13  in null, 8                   phase -11
    14  push                         phase -10
    15  wait t                       phase -9  slack 9
    16  jmp pin, 4                   phase 1
    17  irq                          phase 3
    18  wait 1 pin 0                 phase 4
    19  capture_arm                  phase 5..?
    20  jmp 4                        phase 6..?
    |}]
;;

let%expect_test "spi master" =
  report ~config:spi_config (spi_master ~half_period:8);
  [%expect
    {|
     0  set p, 8 side 0              phase ?..?  side ?..?  jitter ?
     1  wait tx side 0               phase ?..?
     2  pull side 0                  phase ?..?
     3  out null, 8 side 0           phase ?..?
     4  set x, 7 side 0              phase ?..?
     5  mov t, now side 0            phase ?..?
     6  add t, p side 0              phase 1
     7  wait t+ side 0               phase -6  slack 6
     8  out pins, 1 side 0           phase -7  edge -6
     9  wait t+ side 0               phase -6..-4  slack 4..6
    10  in pins, 1 side 1            phase -7  sample -7  side -6
    11  wait t+ side 1               phase -6  slack 6
    12  out pins, 1 side 0           phase -7  edge -6  side -6
    13  jmp x--, 9                   phase -6
    14  push side 0                  phase -4
    15  jmp 1                        phase -3
    |}]
;;

let%expect_test "i2c master" =
  report ~config:i2c_config (i2c_master ~quarter:8);
  [%expect
    {|
     0  set p, 8 side 0              phase ?..?  side ?..?  jitter ?
     1  wait tx side 0               phase ?..?
     2  pull side 0                  phase ?..?
     3  mov t, now side 0            phase ?..?
     4  add t, p side 0              phase 1
     5  add t, p side 0              phase -6
     6  out x, 1 side 0              phase -13
     7  jmp x--, 17                  phase -12
     8  jmp 31                       phase -10
     9  wait tx side 1               phase 0..2
    10  pull side 1                  phase 1..?
    11  mov t, now side 1            phase 2..?
    12  add t, p side 1              phase 1
    13  add t, p side 1              phase -6
    14  out x, 1 side 1              phase -13
    15  jmp x--, 23                  phase -12
    16  jmp 31                       phase -10
    17  wait t+ side 0               phase -10  slack 10
    18  set pindirs, 1 side 0        phase -7  edge -6
    19  wait t+ side 0               phase -6  slack 6
    20  nop side 1                   phase -7  side -6
    21  add t, p side 1              phase -6
    22  jmp 31                       phase -13
    23  set pindirs, 0 side 1        phase -10  edge -9
    24  wait t+ side 1               phase -9  slack 9
    25  nop side 0                   phase -7  side -6
    26  wait t+ side 0               phase -6  slack 6
    27  set pindirs, 1 side 0        phase -7  edge -6
    28  wait t+ side 0               phase -6  slack 6
    29  nop side 1                   phase -7  side -6
    30  add t, p side 1              phase -6
    31  out y, 1 side 1              phase -13..-8  side -7
    32  set x, 7 side 1              phase -12..-7
    33  jmp y--, 53                  phase -11..-6
    34  wait t+ side 1               phase -9..-4  slack 4..9
    35  out y, 1 side 1              phase -7
    36  mov pindirs, !y side 1       phase -6  edge -5
    37  wait t+ side 1               phase -5  slack 5
    38  nop side 0                   phase -7  side -6
    39  wait t+ side 0               phase -6  slack 6
    40  wait t+ side 0               phase -7  slack 7
    41  nop side 1                   phase -7  side -6
    42  jmp x--, 34                  phase -6
    43  wait t+ side 1               phase -4  slack 4
    44  set pindirs, 0 side 1        phase -7  edge -6
    45  wait t+ side 1               phase -6  slack 6
    46  nop side 0                   phase -7  side -6
    47  wait t+ side 0               phase -6  slack 6
    48  in pins, 1 side 0            phase -7  sample -7
    49  wait t+ side 0               phase -6  slack 6
    50  nop side 1                   phase -7  side -6
    51  out x, 1 side 1              phase -6
    52  jmp 72                       phase -5
    53  set pindirs, 0 side 1        phase -9..-4  edge -8..-3  jitter 5
    54  wait t+ side 1               phase -8..-3  slack 3..8
    55  wait t+ side 1               phase -7  slack 7
    56  nop side 0                   phase -7  side -6
    57  wait t+ side 0               phase -6  slack 6
    58  in pins, 1 side 0            phase -7  sample -7
    59  wait t+ side 0               phase -6  slack 6
    60  nop side 1                   phase -7  side -6
    61  jmp x--, 54                  phase -6
    62  out null, 8 side 1           phase -4
    63  out x, 1 side 1              phase -3
    64  wait t+ side 1               phase -2  slack 2
    65  mov pindirs, !x side 1       phase -7  edge -6
    66  wait t+ side 1               phase -6  slack 6
    67  nop side 0                   phase -7  side -6
    68  wait t+ side 0               phase -6  slack 6
    69  wait t+ side 0               phase -7  slack 7
    70  nop side 1                   phase -7  side -6
    71  set pindirs, 0 side 1        phase -6  edge -5
    72  push side 1                  phase -5..-3
    73  jmp x--, 75                  phase -4..-2
    74  jmp 9                        phase -2..0
    75  wait t+ side 1               phase -2..0  slack 0..2
    76  set pindirs, 1 side 1        phase -7  edge -6
    77  wait t+ side 1               phase -6  slack 6
    78  nop side 0                   phase -7  side -6
    79  wait t+ side 0               phase -6  slack 6
    80  set pindirs, 0 side 0        phase -7  edge -6
    81  wait t+ side 0               phase -6  slack 6
    82  jmp 1                        phase -7
    |}]
;;

let%expect_test "a quarter of 5 is too short for the i2c dispatch" =
  report ~config:i2c_config (i2c_master ~quarter:5);
  [%expect
    {|
     0  set p, 5 side 0              phase ?..?  side ?..?  jitter ?
     1  wait tx side 0               phase ?..?
     2  pull side 0                  phase ?..?
     3  mov t, now side 0            phase ?..?
     4  add t, p side 0              phase 1
     5  add t, p side 0              phase -3
     6  out x, 1 side 0              phase -7
     7  jmp x--, 17                  phase -6
     8  jmp 31                       phase -4
     9  wait tx side 1               phase 3..5
    10  pull side 1                  phase 4..?
    11  mov t, now side 1            phase 5..?
    12  add t, p side 1              phase 1
    13  add t, p side 1              phase -3
    14  out x, 1 side 1              phase -7
    15  jmp x--, 23                  phase -6
    16  jmp 31                       phase -4
    17  wait t+ side 0               phase -4  slack 4
    18  set pindirs, 1 side 0        phase -4  edge -3
    19  wait t+ side 0               phase -3  slack 3
    20  nop side 1                   phase -4  side -3
    21  add t, p side 1              phase -3
    22  jmp 31                       phase -7
    23  set pindirs, 0 side 1        phase -4  edge -3
    24  wait t+ side 1               phase -3  slack 3
    25  nop side 0                   phase -4  side -3
    26  wait t+ side 0               phase -3  slack 3
    27  set pindirs, 1 side 0        phase -4  edge -3
    28  wait t+ side 0               phase -3  slack 3
    29  nop side 1                   phase -4  side -3
    30  add t, p side 1              phase -3
    31  out y, 1 side 1              phase -7..-2  side -1
    32  set x, 7 side 1              phase -6..-1
    33  jmp y--, 53                  phase -5..0
    34  wait t+ side 1               phase -3..2  slack -2..3  MAY MISS
    35  out y, 1 side 1              phase -4..-2
    36  mov pindirs, !y side 1       phase -3..-1  edge -2..0  jitter 2
    37  wait t+ side 1               phase -2..0  slack 0..2
    38  nop side 0                   phase -4  side -3
    39  wait t+ side 0               phase -3  slack 3
    40  wait t+ side 0               phase -4  slack 4
    41  nop side 1                   phase -4  side -3
    42  jmp x--, 34                  phase -3
    43  wait t+ side 1               phase -1  slack 1
    44  set pindirs, 0 side 1        phase -4  edge -3
    45  wait t+ side 1               phase -3  slack 3
    46  nop side 0                   phase -4  side -3
    47  wait t+ side 0               phase -3  slack 3
    48  in pins, 1 side 0            phase -4  sample -4
    49  wait t+ side 0               phase -3  slack 3
    50  nop side 1                   phase -4  side -3
    51  out x, 1 side 1              phase -3
    52  jmp 72                       phase -2
    53  set pindirs, 0 side 1        phase -3..2  edge -2..3  jitter 5
    54  wait t+ side 1               phase -2..3  slack -3..2  MAY MISS
    55  wait t+ side 1               phase -4..-1  slack 1..4
    56  nop side 0                   phase -4  side -3
    57  wait t+ side 0               phase -3  slack 3
    58  in pins, 1 side 0            phase -4  sample -4
    59  wait t+ side 0               phase -3  slack 3
    60  nop side 1                   phase -4  side -3
    61  jmp x--, 54                  phase -3
    62  out null, 8 side 1           phase -1
    63  out x, 1 side 1              phase 0
    64  wait t+ side 1               phase 1  slack -1  MAY MISS
    65  mov pindirs, !x side 1       phase -3  edge -2
    66  wait t+ side 1               phase -2  slack 2
    67  nop side 0                   phase -4  side -3
    68  wait t+ side 0               phase -3  slack 3
    69  wait t+ side 0               phase -4  slack 4
    70  nop side 1                   phase -4  side -3
    71  set pindirs, 0 side 1        phase -3  edge -2
    72  push side 1                  phase -2..0
    73  jmp x--, 75                  phase -1..1
    74  jmp 9                        phase 1..3
    75  wait t+ side 1               phase 1..3  slack -3..-1  MAY MISS
    76  set pindirs, 1 side 1        phase -3..-1  edge -2..0  jitter 2
    77  wait t+ side 1               phase -2..0  slack 0..2
    78  nop side 0                   phase -4  side -3
    79  wait t+ side 0               phase -3  slack 3
    80  set pindirs, 0 side 0        phase -4  edge -3
    81  wait t+ side 0               phase -3  slack 3
    82  jmp 1                        phase -4
    |}]
;;

let%expect_test "i2c logger" =
  report ~config:i2c_logger_config i2c_logger;
  [%expect
    {|
     0  mov pins, !null side 0       phase ?..?  edge ?..?  jitter ?  side ?..?  jitter ?
     1  set pindirs, 0 side 0        phase ?..?  edge ?..?  jitter ?
     2  set p, 8 side 0              phase ?..?
     3  mov t, now side 0            phase ?..?
     4  add t, p side 0              phase 1
     5  wait t+ side 0               phase -6  slack 6
     6  set pindirs, 1 side 0        phase -7  edge -6
     7  wait t+ side 0               phase -6  slack 6
     8  nop side 1                   phase -7  side -6
     9  add t, p side 1              phase -6
    10  set x, 20 side 1             phase -13
    11  add x, x side 1              phase -12
    12  add x, x side 1              phase -11
    13  add x, x side 1              phase -10
    14  add x, 1 side 1              phase -9
    15  mov osr, x side 1            phase -8
    16  out null, 8 side 1           phase -7
    17  set x, 7 side 1              phase -6
    18  wait t+ side 1               phase -5..-4  slack 4..5
    19  out y, 1 side 1              phase -7
    20  jmp y--, 23                  phase -6
    21  set pindirs, 1 side 1        phase -4  edge -3
    22  jmp 24                       phase -3
    23  set pindirs, 0 side 1        phase -4  edge -3
    24  wait t+ side 1               phase -3..-1  slack 1..3
    25  nop side 0                   phase -7  side -6
    26  wait t+ side 0               phase -6  slack 6
    27  wait t+ side 0               phase -7  slack 7
    28  nop side 1                   phase -7  side -6
    29  jmp x--, 18                  phase -6
    30  wait t+ side 1               phase -4  slack 4
    31  set pindirs, 0 side 1        phase -7  edge -6
    32  wait t+ side 1               phase -6  slack 6
    33  nop side 0                   phase -7  side -6
    34  wait t+ side 0               phase -6  slack 6
    35  wait t+ side 0               phase -7  slack 7
    36  nop side 1                   phase -7  side -6
    37  set x, 7 side 1              phase -6
    38  mov isr, null side 1         phase -5
    39  wait t+ side 1               phase -4  slack 4
    40  wait t+ side 1               phase -7  slack 7
    41  nop side 0                   phase -7  side -6
    42  wait t+ side 0               phase -6  slack 6
    43  in pins, 1 side 0            phase -7  sample -7
    44  wait t+ side 0               phase -6  slack 6
    45  nop side 1                   phase -7  side -6
    46  jmp x--, 39                  phase -6
    47  wait t+ side 1               phase -4  slack 4
    48  wait t+ side 1               phase -7  slack 7
    49  nop side 0                   phase -7  side -6
    50  wait t+ side 0               phase -6  slack 6
    51  wait t+ side 0               phase -7  slack 7
    52  nop side 1                   phase -7  side -6
    53  wait t+ side 1               phase -6  slack 6
    54  set pindirs, 1 side 1        phase -7  edge -6
    55  wait t+ side 1               phase -6  slack 6
    56  nop side 0                   phase -7  side -6
    57  wait t+ side 0               phase -6  slack 6
    58  set pindirs, 0 side 0        phase -7  edge -6
    59  wait t+ side 0               phase -6  slack 6
    60  set p, 16 side 0             phase -7
    61  mov osr, ::isr side 0        phase -6
    62  set x, 7 side 0              phase -5
    63  mov t, now side 0            phase -4
    64  mov pins, null side 0        phase 1  edge 2
    65  add t, p side 0              phase 2
    66  wait t+ side 0               phase -13..-12  slack 12..13
    67  out pins, 1 side 0           phase -15  edge -14
    68  jmp x--, 66                  phase -14
    69  wait t+ side 0               phase -12  slack 12
    70  mov pins, !null side 0       phase -15  edge -14
    71  wait t side 0                phase -14  slack 14
    72  jmp 2                        phase 1
    |}]
;;

let%expect_test "usb tx" =
  report ~config:usb_config ~period:32 usb_tx;
  [%expect
    {|
     0  pull                         phase ?..?
     1  mov p, osr                   phase ?..?
     2  set pins, 2                  phase ?..?  edge ?..?  jitter ?
     3  wait tx                      phase ?..?
     4  mov t, now                   phase ?..?
     5  add t, p                     phase 1
     6  set y, 1                     phase -30
     7  pull                         phase -29..-23
     8  set x, 7                     phase -28..-22
     9  jmp stuff, 45                phase -27..-21
    10  wait t+                      phase -25..-19  slack 19..25
    11  out pins, 1                  phase -31  edge -30
    12  jmp pin, 14                  phase -30
    13  mov pins, !pins              phase -28  edge -27
    14  jmp x--, 9                   phase -28..-27
    15  jmp y--, 7                   phase -26..-25
    16  crc_init                     phase -24..-23
    17  pull                         phase -23..-22
    18  mov y, osr                   phase -22..-21
    19  pull                         phase -24..-20
    20  set x, 7                     phase -23..-19
    21  jmp stuff, 50                phase -26..-18
    22  wait t+                      phase -24..-16  slack 16..24
    23  out pins, 1                  phase -31  edge -30
    24  jmp pin, 26                  phase -30
    25  mov pins, !pins              phase -28  edge -27
    26  jmp x--, 21                  phase -28..-27
    27  jmp y--, 19                  phase -26..-25
    28  in crc, 16                   phase -24..-23
    29  mov osr, !isr                phase -23..-22
    30  set x, 15                    phase -22..-21
    31  jmp stuff, 55                phase -26..-20
    32  wait t+                      phase -24..-18  slack 18..24
    33  out pins, 1                  phase -31  edge -30
    34  jmp pin, 36                  phase -30
    35  mov pins, !pins              phase -28  edge -27
    36  jmp x--, 31                  phase -28..-27
    37  jmp stuff, 60                phase -26..-25
    38  wait t+                      phase -24..-23  slack 23..24
    39  set pins, 0                  phase -31  edge -30
    40  wait t+                      phase -30  slack 30
    41  wait t+                      phase -31  slack 31
    42  set pins, 2                  phase -31  edge -30
    43  wait t+                      phase -30  slack 30
    44  jmp 3                        phase -31
    45  wait t+                      phase -25..-19  slack 19..25
    46  nop [2]                      phase -31
    47  mov pins, !pins              phase -28  edge -27
    48  stuff_reset                  phase -27
    49  jmp 9                        phase -26
    50  wait t+                      phase -24..-16  slack 16..24
    51  nop [2]                      phase -31
    52  mov pins, !pins              phase -28  edge -27
    53  stuff_reset                  phase -27
    54  jmp 21                       phase -26
    55  wait t+                      phase -24..-18  slack 18..24
    56  nop [2]                      phase -31
    57  mov pins, !pins              phase -28  edge -27
    58  stuff_reset                  phase -27
    59  jmp 31                       phase -26
    60  wait t+                      phase -24..-23  slack 23..24
    61  nop [2]                      phase -31
    62  mov pins, !pins              phase -28  edge -27
    63  stuff_reset                  phase -27
    64  jmp 38                       phase -26
    |}]
;;

let%expect_test "usb rx" =
  report
    ~config:usb_rx_config
    ~period:32
    ~single_capture_edge:true
    (usb_rx ~half_period:16);
  [%expect
    {|
     0  pull                         phase ?..?
     1  mov p, osr                   phase ?..?
     2  set y, 1                     phase ?..?
     3  crc_init                     phase ?..?
     4  stuff_reset                  phase ?..?
     5  capture_arm                  phase ?..?
     6  wait 1 pin 4                 phase ?..?
     7  mov t, capture               phase ?..?
     8  add t, 7                     phase 2..3
     9  add t, 7                     phase -4..-3
    10  add t, 2                     phase -10..-9
    11  jmp stuff, 24                phase -26..-10
    12  wait t+                      phase -24..-8  slack 8..24
    13  mov x, pins                  phase -31  sample -31
    14  jmp x!=y, 18                 phase -30
    15  set x, 1                     phase -28
    16  in x, 1                      phase -27
    17  jmp 11                       phase -26
    18  mov y, x                     phase -28
    19  jmp x--, 22                  phase -27
    20  in crc, 16                   phase -25
    21  jmp 2                        phase -24
    22  in null, 1                   phase -25
    23  jmp 11                       phase -24
    24  wait t+                      phase -24..-8  slack 8..24
    25  mov x, pins                  phase -31  sample -31
    26  mov y, x                     phase -30
    27  stuff_reset                  phase -29
    28  jmp 11                       phase -28
    |}]
;;

let check ?(config = Program_config.default) ?period ?single_capture_edge source =
  let program = Asm.assemble source |> ok_exn in
  match Analyser.check ?period ?single_capture_edge ~config program with
  | Ok verdict -> print_endline (Analyser.Verdict.to_string verdict)
  | Error e -> print_endline (Error.to_string_hum e)
;;

let%expect_test "firmware that can miss a deadline is refused" =
  check ~config:i2c_config (i2c_master ~quarter:8);
  [%expect {| 83 words, 25 deadline waits, worst slack 0 |}];
  check ~config:i2c_config (i2c_master ~quarter:5);
  [%expect
    {|
    4 of 25 deadline waits may be missed
     34  wait t+ side 1               phase -3..2  slack -2..3  MAY MISS
     54  wait t+ side 1               phase -2..3  slack -3..2  MAY MISS
     64  wait t+ side 1               phase 1  slack -1  MAY MISS
     75  wait t+ side 1               phase 1..3  slack -3..-1  MAY MISS
    |}];
  (* a program with no deadline to miss *)
  check ~config:spi_slave_config spi_slave;
  [%expect {| 6 words, 0 deadline waits |}]
;;

let%expect_test "a deadline is only as good as what is assumed about the world" =
  check ~config:rx_config (uart_rx ~period:16);
  [%expect
    {|
    2 of 2 deadline waits may be missed
      9  wait t+                      phase -18..?  slack ?..18  MAY MISS
     15  wait t                       phase -9..?  slack ?..9  MAY MISS
    a bound of ? means none: the way here has a wait for a pin or a fifo, a capture nothing is assumed about, a period the host loads, or a loop that falls further behind on every pass
    |}];
  check ~config:rx_config ~single_capture_edge:true (uart_rx ~period:16);
  [%expect {| 21 words, 2 deadline waits, worst slack 3 |}];
  check usb_tx;
  [%expect
    {|
    11 of 11 deadline waits may be missed
     10  wait t+                      phase ?..?  slack ?..?  MAY MISS
     22  wait t+                      phase ?..?  slack ?..?  MAY MISS
     32  wait t+                      phase ?..?  slack ?..?  MAY MISS
     38  wait t+                      phase ?..?  slack ?..?  MAY MISS
     40  wait t+                      phase ?..?  slack ?..?  MAY MISS
     41  wait t+                      phase ?..?  slack ?..?  MAY MISS
     43  wait t+                      phase ?..?  slack ?..?  MAY MISS
     45  wait t+                      phase ?..?  slack ?..?  MAY MISS
     50  wait t+                      phase ?..?  slack ?..?  MAY MISS
     55  wait t+                      phase ?..?  slack ?..?  MAY MISS
     60  wait t+                      phase ?..?  slack ?..?  MAY MISS
    a bound of ? means none: the way here has a wait for a pin or a fifo, a capture nothing is assumed about, a period the host loads, or a loop that falls further behind on every pass
    |}];
  check ~config:usb_config ~period:32 usb_tx;
  [%expect {| 65 words, 11 deadline waits, worst slack 16 |}];
  (* the same firmware at twelve cycles a bit, which its longest path does not fit *)
  check ~config:usb_config ~period:12 usb_tx;
  [%expect
    {|
    11 of 11 deadline waits may be missed
     10  wait t+                      phase -5..?  slack ?..5  MAY MISS
     22  wait t+                      phase -4..?  slack ?..4  MAY MISS
     32  wait t+                      phase -4..?  slack ?..4  MAY MISS
     38  wait t+                      phase -4..?  slack ?..4  MAY MISS
     40  wait t+                      phase -10..?  slack ?..10  MAY MISS
     41  wait t+                      phase -11..?  slack ?..11  MAY MISS
     43  wait t+                      phase -10..?  slack ?..10  MAY MISS
     45  wait t+                      phase -5..?  slack ?..5  MAY MISS
     50  wait t+                      phase -4..?  slack ?..4  MAY MISS
     55  wait t+                      phase -4..?  slack ?..4  MAY MISS
     60  wait t+                      phase -4..?  slack ?..4  MAY MISS
    a bound of ? means none: the way here has a wait for a pin or a fifo, a capture nothing is assumed about, a period the host loads, or a loop that falls further behind on every pass
    |}]
;;

(* The analyser is only worth anything if its intervals hold on every execution. Random
   pin levels and random host traffic push each firmware well off its happy path, and make
   no assumption about the world true, so the analysis here makes none. *)
let soundness ?period ?preload ~config ~cycles ~seeds words =
  Soundness.check
    ?period
    ?preload
    ~config
    (List.init seeds ~f:(fun n -> Soundness.Stimulus.random ~seed:(n + 1) ~cycles))
    words
;;

let%expect_test "every firmware stays inside its analysis under random stimulus" =
  let corpus =
    [ "uart tx", Program_config.default, uart_tx ~period:16, None, []
    ; "uart tx host rate", Program_config.default, uart_tx_host_rate, Some 434, [ 434 ]
    ; "uart rx", rx_config, uart_rx ~period:16, None, []
    ; "spi master", spi_config, spi_master ~half_period:8, None, []
    ; "spi slave", spi_slave_config, spi_slave, None, []
    ; "i2c master", i2c_config, i2c_master ~quarter:8, None, []
    ; "i2c slave", i2c_slave_config, i2c_slave, None, [ 0x50 lsl 1 ]
    ; "i2c logger", i2c_logger_config, i2c_logger, None, []
    ; "usb tx", usb_config, usb_tx, Some 32, [ 32 ]
    ; "usb rx", usb_rx_config, usb_rx ~half_period:16, Some 32, [ 32 ]
    ; ( "usb device"
      , usb_device_config
      , usb_device ~address:0 ~half_period:16
      , Some 32
      , [ 32 ] )
    ; "edge meter", edge_meter_config, edge_meter ~period:16, None, []
    ; "edge logger", edge_logger_config ~pin:0, edge_logger ~pin:0, None, []
    ; "ws2812", Ws2812.config, Ws2812.firmware ~third:6 ~tail:7, None, []
    ; "1-wire", One_wire.config, One_wire.firmware, Some 8, [ 8 ]
    ; "ps/2", Ps2.config, Ps2.firmware, Some 10, [ 10 ]
    ]
  in
  List.iter corpus ~f:(fun (name, config, source, period, preload) ->
    let words = assemble source in
    let { Soundness.issues; side_edges; reached; violations } =
      soundness ?period ~preload ~config ~cycles:3000 ~seeds:8 words
    in
    let reached = [%string "%{reached#Int}/%{List.length words#Int}"] in
    let violations = List.take violations 3 in
    print_s
      [%message
        name
          (issues : int)
          (reached : string)
          (side_edges : int)
          (violations : (int * int * int * int) list)]);
  [%expect
    {|
    ("uart tx" (issues 4962) (reached 15/15) (side_edges 0) (violations ()))
    ("uart tx host rate" (issues 232) (reached 13/17) (side_edges 0)
     (violations ()))
    ("uart rx" (issues 5756) (reached 21/21) (side_edges 0) (violations ()))
    ("spi master" (issues 8172) (reached 16/16) (side_edges 2598)
     (violations ()))
    ("spi slave" (issues 14940) (reached 6/6) (side_edges 0) (violations ()))
    ("i2c master" (issues 7129) (reached 83/83) (side_edges 1391)
     (violations ()))
    ("i2c slave" (issues 13883) (reached 59/72) (side_edges 0) (violations ()))
    ("i2c logger" (issues 6752) (reached 73/73) (side_edges 1200)
     (violations ()))
    ("usb tx" (issues 4466) (reached 38/65) (side_edges 0) (violations ()))
    ("usb rx" (issues 8302) (reached 24/29) (side_edges 0) (violations ()))
    ("usb device" (issues 5809) (reached 271/470) (side_edges 0) (violations ()))
    ("edge meter" (issues 6016) (reached 12/12) (side_edges 0) (violations ()))
    ("edge logger" (issues 16848) (reached 8/8) (side_edges 0) (violations ()))
    (ws2812 (issues 7128) (reached 31/32) (side_edges 0) (violations ()))
    (1-wire (issues 4929) (reached 48/48) (side_edges 0) (violations ()))
    (ps/2 (issues 6973) (reached 64/65) (side_edges 0) (violations ()))
    |}]
;;

let%expect_test "random programs stay inside their analysis" =
  let random = Splittable_random.of_int 5 in
  let results =
    List.init 32 ~f:(fun _ ->
      let config = Random_program.config random in
      let words = Random_program.program random ~config in
      List.length words, soundness ~config ~cycles:1000 ~seeds:2 words)
  in
  let sum f = List.sum (module Int) results ~f in
  let words = sum fst in
  let issues = sum (fun (_, r) -> r.issues) in
  let reached = sum (fun (_, r) -> r.reached) in
  let side_edges = sum (fun (_, r) -> r.side_edges) in
  let violations = sum (fun (_, r) -> List.length r.violations) in
  print_s
    [%message
      (issues : int) (reached : int) (words : int) (side_edges : int) (violations : int)];
  [%expect
    {| ((issues 3867) (reached 1432) (words 16384) (side_edges 969) (violations 0)) |}]
;;

(* A counter that runs out goes to all ones, and a deadline built on it is that far off. *)
let%expect_test "x-- leaves all ones when it falls through" =
  let source =
    {|
    set p, 10
    set x, 0
    mov t, now
    jmp x--, 0
    add t, x
    add t, p
    wait t
    jmp 0
|}
  in
  report source;
  let { Soundness.issues; violations; _ } =
    soundness ~config:Program_config.default ~cycles:300 ~seeds:1 (assemble source)
  in
  print_s [%message (issues : int) (violations : (int * int * int * int) list)];
  [%expect
    {|
      0  set p, 10                    phase ?..?
      1  set x, 0                     phase ?..?
      2  mov t, now                   phase ?..?
      3  jmp x--, 0                   phase 1
      4  add t, x                     phase 3
      5  add t, p                     phase -65531
      6  wait t                       phase -65540  slack 65540
      7  jmp 0                        phase 1
    ((issues 7) (violations ()))
    |}]
;;

let%expect_test "a jump on registers the analysis knows goes one way" =
  let source =
    {|
    set x, 2
    set y, 2
    jmp x!=y, 7
    set x, 0
    jmp x--, 7
    set pins, 1
    jmp 0
    set pins, 0
    jmp 0
|}
  in
  report source;
  let { Soundness.issues; violations; _ } =
    soundness ~config:Program_config.default ~cycles:100 ~seeds:1 (assemble source)
  in
  print_s [%message (issues : int) (violations : (int * int * int * int) list)];
  [%expect
    {|
      0  set x, 2                     phase ?..?
      1  set y, 2                     phase ?..?
      2  jmp x!=y, 7                  phase ?..?
      3  set x, 0                     phase ?..?
      4  jmp x--, 7                   phase ?..?
      5  set pins, 1                  phase ?..?  edge ?..?  jitter ?
      6  jmp 0                        phase ?..?
    ((issues 70) (violations ()))
    |}]
;;

(* Random programs rarely write a side-set pin any other way, so this one does it on
   purpose: [set pins] and side-set share a pin, the set wins, and the next [side 0] moves
   the pin back. *)
let%expect_test "side-set moves a pin back after a write to it" =
  let config =
    { Program_config.default with
      side_set_count = 1
    ; side_set_base = 5
    ; set_base = 5
    ; set_count = 1
    }
  in
  let source =
    {|
    .side_set 1
    set p, 10 side 0
    mov t, now side 0
    add t, p side 0
loop:
    wait t+ side 0
    set pins, 1 side 0
    nop side 0
    jmp loop
|}
  in
  report ~config source;
  let { Soundness.issues; side_edges; violations; _ } =
    soundness ~config ~cycles:300 ~seeds:1 (assemble source)
  in
  print_s
    [%message
      (issues : int) (side_edges : int) (violations : (int * int * int * int) list)];
  [%expect
    {|
      0  set p, 10 side 0             phase ?..?  side ?..?  jitter ?
      1  mov t, now side 0            phase ?..?
      2  add t, p side 0              phase 1
      3  wait t+ side 0               phase -8..-5  slack 5..8
      4  set pins, 1 side 0           phase -9  edge -8
      5  nop side 0                   phase -8  side -7
      6  jmp 3                        phase -7
    ((issues 120) (side_edges 29) (violations ()))
    |}]
;;

let%expect_test "edge meter" =
  report ~config:edge_meter_config (edge_meter ~period:16);
  [%expect
    {|
     0  set p, 16                    phase ?..?
     1  set pins, 0                  phase ?..?  edge ?..?  jitter ?
     2  mov t, now                   phase ?..?
     3  add t, p                     phase 1
     4  capture_arm                  phase -14..-7
     5  wait t+                      phase -13..-6  slack 6..13
     6  mov pins, !pins              phase -15  edge -14
     7  wait t+                      phase -14  slack 14
     8  mov pins, !pins              phase -15  edge -14
     9  nop [3]                      phase -14
    10  in capture, 16               phase -10
    11  jmp 4                        phase -9
    |}]
;;

let%expect_test "a wrapped loop toggles every two cycles with no jitter" =
  report
    ~config:{ Program_config.default with in_base = 5 }
    {|
    set p, 2
    mov t, now
    add t, p
.wrap_target
    wait t+
    mov pins, !pins
.wrap
|};
  [%expect
    {|
    0  set p, 2                     phase ?..?
    1  mov t, now                   phase ?..?
    2  add t, p                     phase 1
    3  wait t+                      phase 0  slack 0
    4  mov pins, !pins              phase -1  edge 0
    |}]
;;

let%expect_test "usb device" =
  let program = Asm.assemble (usb_device ~address:0 ~half_period:16) |> ok_exn in
  let rows =
    Analyser.analyse
      ~period:32
      ~single_capture_edge:true
      ~config:(Asm.Program.configure program usb_device_config)
      program.instructions
  in
  let report = Analyser.to_string ~side_set_count:0 rows |> String.split_lines in
  let interesting =
    List.filter report ~f:(fun line ->
      List.exists [ "MAY MISS"; "edge"; "?" ] ~f:(fun s ->
        String.is_substring line ~substring:s))
  in
  print_s [%message (List.length report : int)];
  List.iter interesting ~f:print_endline;
  [%expect
    {|
    ("List.length report" 466)
      0  pull                         phase ?..?
      1  mov p, osr                   phase ?..?
      2  set pins, 2                  phase ?..?  edge ?..?  jitter ?
      3  set pindirs, 4               phase ?..?  edge ?..?  jitter ?
      4  mov isr, null                phase ?..?
      5  set y, 0                     phase ?..?
      6  in y, 3                      phase ?..?
      7  set y, 0                     phase ?..?
      8  in y, 3                      phase ?..?
      9  set y, 0                     phase ?..?
     10  in y, 5                      phase ?..?
     11  set y, 8                     phase ?..?
     12  in y, 5                      phase ?..?
     13  mov osr, isr                 phase ?..?
     14  mov isr, null                phase ?..?
     15  stuff_reset                  phase ?..?
     16  capture_arm                  phase ?..?
     17  wait 1 pin 12                phase ?..?
     18  mov t, capture               phase ?..?
    109  set pins, 6                  phase -27  edge -26
    111  set pins, 2                  phase -27  edge -26
    113  set pins, 6                  phase -25  edge -24
    115  set pins, 2                  phase -25  edge -24
    363  mov t, capture               phase -9..?
    379  set pins, 6                  phase -31  edge -30
    380  set pindirs, 7               phase -30  edge -29
    384  mov pins, !pins              phase -28  edge -27
    411  set pins, 2                  phase -31  edge -30
    412  set pindirs, 7               phase -30  edge -29
    417  mov pins, !pins              phase -28  edge -27
    422  set pins, 4                  phase -28  edge -27
    426  set pins, 6                  phase -28  edge -27
    439  mov pins, !pins              phase -28  edge -27
    444  mov pins, !pins              phase -28  edge -27
    451  mov pins, !pins              phase -28  edge -27
    456  mov pins, !pins              phase -28  edge -27
    468  mov pins, !pins              phase -28  edge -27
    |}]
;;
