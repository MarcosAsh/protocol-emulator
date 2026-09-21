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

let%expect_test "i2c logger" =
  report ~config:i2c_logger_config i2c_logger;
  [%expect
    {|
     0  mov pins, !null side 0       phase ?..?  edge ?..?  jitter ?
     1  set pindirs, 0 side 0        phase ?..?  edge ?..?  jitter ?
     2  set p, 8 side 0              phase ?..?
     3  mov t, now side 0            phase ?..?
     4  add t, p side 0              phase 1
     5  wait t+ side 0               phase -6  slack 6
     6  set pindirs, 1 side 0        phase -7  edge -6
     7  wait t+ side 0               phase -6  slack 6
     8  nop side 1                   phase -7
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
    25  nop side 0                   phase -7
    26  wait t+ side 0               phase -6  slack 6
    27  wait t+ side 0               phase -7  slack 7
    28  nop side 1                   phase -7
    29  jmp x--, 18                  phase -6
    30  wait t+ side 1               phase -4  slack 4
    31  set pindirs, 0 side 1        phase -7  edge -6
    32  wait t+ side 1               phase -6  slack 6
    33  nop side 0                   phase -7
    34  wait t+ side 0               phase -6  slack 6
    35  wait t+ side 0               phase -7  slack 7
    36  nop side 1                   phase -7
    37  set x, 7 side 1              phase -6
    38  mov isr, null side 1         phase -5
    39  wait t+ side 1               phase -4  slack 4
    40  wait t+ side 1               phase -7  slack 7
    41  nop side 0                   phase -7
    42  wait t+ side 0               phase -6  slack 6
    43  in pins, 1 side 0            phase -7  sample -7
    44  wait t+ side 0               phase -6  slack 6
    45  nop side 1                   phase -7
    46  jmp x--, 39                  phase -6
    47  wait t+ side 1               phase -4  slack 4
    48  wait t+ side 1               phase -7  slack 7
    49  nop side 0                   phase -7
    50  wait t+ side 0               phase -6  slack 6
    51  wait t+ side 0               phase -7  slack 7
    52  nop side 1                   phase -7
    53  wait t+ side 1               phase -6  slack 6
    54  set pindirs, 1 side 1        phase -7  edge -6
    55  wait t+ side 1               phase -6  slack 6
    56  nop side 0                   phase -7
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

(* The analyser is only worth anything if its intervals hold on every execution. Random
   pin levels and random host traffic push each firmware well off its happy path; the
   phase at every issue must still fall inside the row's interval, and no issue may land
   on a pc the analyser calls unreachable. Random pins break every assumption about the
   world, so the analysis here makes none. A wait that stalls issues again every cycle,
   and only its first issue counts as an entry. *)
let phase (m : Machine.t) =
  let d = (m.now - m.t) land ((1 lsl Isa.timer_bits) - 1) in
  if d >= 1 lsl (Isa.timer_bits - 1) then d - (1 lsl Isa.timer_bits) else d
;;

let soundness ?period ?(preload = []) ~config ~cycles ~seeds words =
  let instructions =
    List.map words ~f:(fun w ->
      Isa.of_word ~side_set_count:config.Program_config.side_set_count w |> ok_exn)
  in
  let rows = Array.create ~len:(List.length words) None in
  List.iter (Analyser.analyse ?period ~config instructions) ~f:(fun row ->
    rows.(row.pc) <- Some row);
  let issues = ref 0 in
  let violations = ref [] in
  for seed = 1 to seeds do
    let random = Splittable_random.of_int seed in
    let int hi = Splittable_random.int random ~lo:0 ~hi in
    let m = ref (Machine.create ~config ~program:words |> ok_exn) in
    List.iter preload ~f:(fun w -> m := Machine.write_tx !m w |> ok_exn);
    let last = ref None in
    for cycle = 0 to cycles - 1 do
      let t = !m in
      if (not t.halted) && t.stall = 0
      then (
        let entry =
          not (Option.equal [%equal: int * int] !last (Some (cycle - 1, t.pc)))
        in
        last := Some (cycle, t.pc);
        if entry
        then (
          Int.incr issues;
          let ok =
            match rows.(t.pc) with
            | Some row -> Interval.contains row.phase (phase t)
            | None -> false
          in
          if not ok then violations := (seed, cycle, t.pc, phase t) :: !violations));
      if int 3 = 0 && List.length t.tx_fifo < Machine.fifo_depth
      then m := Machine.write_tx t (int 0xffff) |> ok_exn;
      if int 3 = 0
      then (
        match Machine.read_rx !m with
        | Some (_, popped) -> m := popped
        | None -> ());
      m := Machine.step !m ~inputs:(int 0xfffff)
    done
  done;
  !issues, List.rev !violations
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
    ]
  in
  List.iter corpus ~f:(fun (name, config, source, period, preload) ->
    let issues, violations =
      soundness ?period ~preload ~config ~cycles:3000 ~seeds:8 (assemble source)
    in
    let violations = List.take violations 3 in
    print_s [%message name (issues : int) (violations : (int * int * int * int) list)]);
  [%expect
    {|
    ("uart tx" (issues 4962) (violations ()))
    ("uart tx host rate" (issues 224) (violations ()))
    ("uart rx" (issues 5774) (violations ()))
    ("spi master" (issues 8172) (violations ()))
    ("spi slave" (issues 15003) (violations ()))
    ("i2c master" (issues 7109) (violations ()))
    ("i2c slave" (issues 13953) (violations ()))
    ("i2c logger" (issues 6752) (violations ()))
    ("usb tx" (issues 4462) (violations ()))
    ("usb rx" (issues 8270) (violations ()))
    |}]
;;

let%expect_test "random programs stay inside their analysis" =
  let random = Splittable_random.of_int 5 in
  let results =
    List.init 32 ~f:(fun _ ->
      let config = Random_program.config random in
      let words = Random_program.program random ~config in
      soundness ~config ~cycles:1000 ~seeds:2 words)
  in
  let issues = List.sum (module Int) results ~f:fst in
  let violations = List.sum (module Int) results ~f:(fun (_, v) -> List.length v) in
  print_s [%message (issues : int) (violations : int)];
  [%expect {| ((issues 2854) (violations 0)) |}]
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
