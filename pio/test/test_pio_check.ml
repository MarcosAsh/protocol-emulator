open! Core

(* Exit 0 when every check passes, 1 on a usage error, 2 on any FAIL or ERROR. *)
let run args =
  let command =
    String.concat
      ~sep:" "
      (("../bin/pio_check.exe" :: List.map args ~f:Filename.quote) @ [ ">/dev/null 2>&1" ])
  in
  printf "%d  %s\n" (Sys_unix.command command) (String.concat ~sep:" " args)
;;

let%expect_test "exit codes tell a failed check from a usage error" =
  let uart = [ "pico_examples/uart_tx.pio"; "-fifo-ready" ] in
  List.iter
    ~f:run
    [ uart @ [ "-pin"; "tx=out0,side0"; "-init"; "tx=1"; "-rule"; "bit: tx -> tx >= 8" ]
    ; uart @ [ "-rule"; "bit: out0 -> out0 >= 9" ]
    ; uart @ [ "-rule"; "bit: out0 -> nowhere >= 1" ]
    ; [ "pico_examples/i2c.pio"; "-program"; "i2c"; "-autopull" ]
    ; uart @ [ "-bogus" ]
    ; uart @ [ "-pin"; "tx=zz" ]
    ; uart @ [ "-program"; "nope" ]
    ; uart @ [ "-init"; "zz=1" ]
    ; [ "pico_examples/missing.pio" ]
    ];
  [%expect
    {|
    0  pico_examples/uart_tx.pio -fifo-ready -pin tx=out0,side0 -init tx=1 -rule bit: tx -> tx >= 8
    2  pico_examples/uart_tx.pio -fifo-ready -rule bit: out0 -> out0 >= 9
    2  pico_examples/uart_tx.pio -fifo-ready -rule bit: out0 -> nowhere >= 1
    2  pico_examples/i2c.pio -program i2c -autopull
    1  pico_examples/uart_tx.pio -fifo-ready -bogus
    1  pico_examples/uart_tx.pio -fifo-ready -pin tx=zz
    1  pico_examples/uart_tx.pio -fifo-ready -program nope
    1  pico_examples/uart_tx.pio -fifo-ready -init zz=1
    1  pico_examples/missing.pio
    |}]
;;

let%expect_test "numbers out of range, and a time with no clock, are usage errors" =
  let uart = [ "pico_examples/uart_tx.pio"; "-fifo-ready" ] in
  List.iter
    ~f:run
    [ uart @ [ "-sys-hz"; "0" ]
    ; uart @ [ "-sys-hz"; "125e6"; "-clkdiv"; "0.5" ]
    ; uart @ [ "-cell"; "0" ]
    ; uart @ [ "-set-count"; "6" ]
    ; uart @ [ "-out-count"; "33" ]
    ; uart @ [ "-rule"; "bit: out0 -> out0 >= 1us" ]
    ; uart @ [ "-sys-hz"; "125e6"; "-rule"; "bit: out0 -> out0 >= 1us" ]
    ];
  [%expect
    {|
    1  pico_examples/uart_tx.pio -fifo-ready -sys-hz 0
    1  pico_examples/uart_tx.pio -fifo-ready -sys-hz 125e6 -clkdiv 0.5
    1  pico_examples/uart_tx.pio -fifo-ready -cell 0
    1  pico_examples/uart_tx.pio -fifo-ready -set-count 6
    1  pico_examples/uart_tx.pio -fifo-ready -out-count 33
    1  pico_examples/uart_tx.pio -fifo-ready -rule bit: out0 -> out0 >= 1us
    2  pico_examples/uart_tx.pio -fifo-ready -sys-hz 125e6 -rule bit: out0 -> out0 >= 1us
    |}]
;;
