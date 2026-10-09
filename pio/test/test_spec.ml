open! Core
open Pio

let uart_tx = In_channel.read_all "pico_examples/uart_tx.pio" |> Pioasm.parse |> ok_exn

let check spec =
  match
    let open Or_error.Let_syntax in
    let%bind spec = Spec.of_string spec in
    let%bind programs = Spec.select spec uart_tx in
    let%bind configure = Spec.configure spec in
    List.map programs ~f:(fun program ->
      let%map config = configure program in
      Timing.analyse config program)
    |> Or_error.all
  with
  | Error error -> print_s [%message (error : Error.t)]
  | Ok reports ->
    List.iter reports ~f:(fun report ->
      print_string (Timing.Report.to_string report);
      print_s [%message "" ~passed:(Timing.Report.passed report : bool)])
;;

let%expect_test "one pio_check flag a line, as the command line gives it" =
  check
    {|
# pico-examples uart_tx at 8 cycles a bit
pin tx=out0,side0
init tx=1
fifo-ready
rule bit: tx -> tx >= 8   # a whole bit
|};
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

let%expect_test "unknown flags, missing values and bad numbers name the line" =
  List.iter
    ~f:check
    [ "bogus"; "pin"; "autopull yes"; "cell many"; "program nope"; "init tx=1" ];
  [%expect
    {|
    (error ("unknown flag" (line bogus)))
    (error ("needs a value" (line pin)))
    (error ("takes no value" (line "autopull yes")))
    (error ("not a number" (line "cell many")))
    (error "no program to check")
    (error ("init of no pin" (name tx)))
    |}]
;;

let%expect_test "times need a clock, and numbers stay in range" =
  List.iter
    ~f:check
    [ "rule bit: out0 -> out0 >= 1us"
    ; "sys-hz 125e6\nclkdiv 0.5\nset-count 6"
    ; "sys-hz 125e6\nrule bit: out0 -> out0 >= 1us"
    ];
  [%expect
    {|
    (error "a rule in ns or us needs sys-hz")
    (error ("clkdiv must be in 1..65536" "set-count must be in 0..5"))
    uart_tx
      0  pull side 1 [7]                  8+  -              side0+ -,72
      1  set x, 7 side 0 [7]               8  -              side0- 8..?
      2  out pins, 1                       1  -              out0- -,8,24..?  out0+ -,8,24..?
      3  jmp x-- bitloop [6]               7  -
    bit: out0 -> out0 >= 1us: FAIL, 8 cycles (64ns) at pc 2
    (passed false)
    |}]
;;
