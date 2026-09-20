open! Core
open Protocol_emulator
open Firmware

let report ?(config = Program_config.default) source =
  let program = Asm.assemble source |> ok_exn in
  Analyser.analyse ~config program.instructions
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
  report ~config:rx_config (uart_rx ~period:16);
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
     0  set p, 8 side 0              phase ?..?
     1  wait tx side 0               phase ?..?
     2  pull side 0                  phase ?..?
     3  out null, 8 side 0           phase ?..?
     4  set x, 7 side 0              phase ?..?
     5  mov t, now side 0            phase ?..?
     6  add t, p side 0              phase 1
     7  wait t+ side 0               phase -6  slack 6
     8  out pins, 1 side 0           phase -7  edge -6
     9  wait t+ side 0               phase -6..-4  slack 4..6
    10  in pins, 1 side 1            phase -7  sample -7
    11  wait t+ side 1               phase -6  slack 6
    12  out pins, 1 side 0           phase -7  edge -6
    13  jmp x--, 9                   phase -6
    14  push side 0                  phase -4
    15  jmp 1                        phase -3
    |}]
;;

let%expect_test "i2c master" =
  report ~config:i2c_config (i2c_master ~quarter:8);
  [%expect
    {|
     0  set p, 8 side 0              phase ?..?
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
    20  nop side 1                   phase -7
    21  add t, p side 1              phase -6
    22  jmp 31                       phase -13
    23  set pindirs, 0 side 1        phase -10  edge -9
    24  wait t+ side 1               phase -9  slack 9
    25  nop side 0                   phase -7
    26  wait t+ side 0               phase -6  slack 6
    27  set pindirs, 1 side 0        phase -7  edge -6
    28  wait t+ side 0               phase -6  slack 6
    29  nop side 1                   phase -7
    30  add t, p side 1              phase -6
    31  out y, 1 side 1              phase -13..-8
    32  set x, 7 side 1              phase -12..-7
    33  jmp y--, 53                  phase -11..-6
    34  wait t+ side 1               phase -9..-4  slack 4..9
    35  out y, 1 side 1              phase -7
    36  mov pindirs, !y side 1       phase -6  edge -5
    37  wait t+ side 1               phase -5  slack 5
    38  nop side 0                   phase -7
    39  wait t+ side 0               phase -6  slack 6
    40  wait t+ side 0               phase -7  slack 7
    41  nop side 1                   phase -7
    42  jmp x--, 34                  phase -6
    43  wait t+ side 1               phase -4  slack 4
    44  set pindirs, 0 side 1        phase -7  edge -6
    45  wait t+ side 1               phase -6  slack 6
    46  nop side 0                   phase -7
    47  wait t+ side 0               phase -6  slack 6
    48  in pins, 1 side 0            phase -7  sample -7
    49  wait t+ side 0               phase -6  slack 6
    50  nop side 1                   phase -7
    51  out x, 1 side 1              phase -6
    52  jmp 72                       phase -5
    53  set pindirs, 0 side 1        phase -9..-4  edge -8..-3  jitter 5
    54  wait t+ side 1               phase -8..-3  slack 3..8
    55  wait t+ side 1               phase -7  slack 7
    56  nop side 0                   phase -7
    57  wait t+ side 0               phase -6  slack 6
    58  in pins, 1 side 0            phase -7  sample -7
    59  wait t+ side 0               phase -6  slack 6
    60  nop side 1                   phase -7
    61  jmp x--, 54                  phase -6
    62  out null, 8 side 1           phase -4
    63  out x, 1 side 1              phase -3
    64  wait t+ side 1               phase -2  slack 2
    65  mov pindirs, !x side 1       phase -7  edge -6
    66  wait t+ side 1               phase -6  slack 6
    67  nop side 0                   phase -7
    68  wait t+ side 0               phase -6  slack 6
    69  wait t+ side 0               phase -7  slack 7
    70  nop side 1                   phase -7
    71  set pindirs, 0 side 1        phase -6  edge -5
    72  push side 1                  phase -5..-3
    73  jmp x--, 75                  phase -4..-2
    74  jmp 9                        phase -2..0
    75  wait t+ side 1               phase -2..0  slack 0..2
    76  set pindirs, 1 side 1        phase -7  edge -6
    77  wait t+ side 1               phase -6  slack 6
    78  nop side 0                   phase -7
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
     0  set p, 5 side 0              phase ?..?
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
    20  nop side 1                   phase -4
    21  add t, p side 1              phase -3
    22  jmp 31                       phase -7
    23  set pindirs, 0 side 1        phase -4  edge -3
    24  wait t+ side 1               phase -3  slack 3
    25  nop side 0                   phase -4
    26  wait t+ side 0               phase -3  slack 3
    27  set pindirs, 1 side 0        phase -4  edge -3
    28  wait t+ side 0               phase -3  slack 3
    29  nop side 1                   phase -4
    30  add t, p side 1              phase -3
    31  out y, 1 side 1              phase -7..-2
    32  set x, 7 side 1              phase -6..-1
    33  jmp y--, 53                  phase -5..0
    34  wait t+ side 1               phase -3..2  slack -2..3  MAY MISS
    35  out y, 1 side 1              phase -4..-2
    36  mov pindirs, !y side 1       phase -3..-1  edge -2..0  jitter 2
    37  wait t+ side 1               phase -2..0  slack 0..2
    38  nop side 0                   phase -4
    39  wait t+ side 0               phase -3  slack 3
    40  wait t+ side 0               phase -4  slack 4
    41  nop side 1                   phase -4
    42  jmp x--, 34                  phase -3
    43  wait t+ side 1               phase -1  slack 1
    44  set pindirs, 0 side 1        phase -4  edge -3
    45  wait t+ side 1               phase -3  slack 3
    46  nop side 0                   phase -4
    47  wait t+ side 0               phase -3  slack 3
    48  in pins, 1 side 0            phase -4  sample -4
    49  wait t+ side 0               phase -3  slack 3
    50  nop side 1                   phase -4
    51  out x, 1 side 1              phase -3
    52  jmp 72                       phase -2
    53  set pindirs, 0 side 1        phase -3..2  edge -2..3  jitter 5
    54  wait t+ side 1               phase -2..3  slack -3..2  MAY MISS
    55  wait t+ side 1               phase -4..-1  slack 1..4
    56  nop side 0                   phase -4
    57  wait t+ side 0               phase -3  slack 3
    58  in pins, 1 side 0            phase -4  sample -4
    59  wait t+ side 0               phase -3  slack 3
    60  nop side 1                   phase -4
    61  jmp x--, 54                  phase -3
    62  out null, 8 side 1           phase -1
    63  out x, 1 side 1              phase 0
    64  wait t+ side 1               phase 1  slack -1  MAY MISS
    65  mov pindirs, !x side 1       phase -3  edge -2
    66  wait t+ side 1               phase -2  slack 2
    67  nop side 0                   phase -4
    68  wait t+ side 0               phase -3  slack 3
    69  wait t+ side 0               phase -4  slack 4
    70  nop side 1                   phase -4
    71  set pindirs, 0 side 1        phase -3  edge -2
    72  push side 1                  phase -2..0
    73  jmp x--, 75                  phase -1..1
    74  jmp 9                        phase 1..3
    75  wait t+ side 1               phase 1..3  slack -3..-1  MAY MISS
    76  set pindirs, 1 side 1        phase -3..-1  edge -2..0  jitter 2
    77  wait t+ side 1               phase -2..0  slack 0..2
    78  nop side 0                   phase -4
    79  wait t+ side 0               phase -3  slack 3
    80  set pindirs, 0 side 0        phase -4  edge -3
    81  wait t+ side 0               phase -3  slack 3
    82  jmp 1                        phase -4
    |}]
;;
