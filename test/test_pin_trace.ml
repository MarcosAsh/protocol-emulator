open! Core
open Protocol_models

let out0 (line : Pin_trace.Line.t) = (line.uo_out lsr 1) land 1

let%expect_test "what the host reads back in every scenario" =
  List.iter Pin_scenarios.all ~f:(fun scenario ->
    let lines, reads = Pin_trace.run scenario in
    let reads = List.map reads ~f:(List.map ~f:(sprintf "%04x")) in
    print_s
      [%message
        scenario.name ~cycles:(List.length lines : int) (reads : string list list)]);
  [%expect
    {|
    (uart_tx (cycles 8617) (reads ((0000))))
    (uart_rx (cycles 11063)
     (reads ((0055 00a3 00ff) (0000 000f 00f0) (005a) (0000))))
    (spi_master (cycles 9076) (reads ((0081 007e) (0000))))
    (i2c_logger (cycles 18310) (reads ((0000))))
    (wrapped_loop (cycles 6666) (reads ((0000))))
    (fifo_poll (cycles 11435)
     (reads
      ((0200) (0400) (0600) (1234 beef) (0400) (0600) (0800) (0800)
       (0001 ffff 8000 7a5c) (0001 0002) (0001))))
    |}]
;;

let%expect_test "the uart bytes are on OUT0 of the traces" =
  List.iter [ "uart_tx"; "i2c_logger" ] ~f:(fun name ->
    let scenario =
      List.find_exn Pin_scenarios.all ~f:(fun s -> String.equal s.name name)
    in
    let lines, (_ : int list list) = Pin_trace.run scenario in
    let levels = List.map lines ~f:out0 |> List.drop_while ~f:(fun level -> level = 0) in
    let bytes = decode_uart levels ~period:16 in
    print_s [%message name (bytes : int list)]);
  [%expect
    {|
    (uart_tx (bytes (85 163)))
    (i2c_logger (bytes (16 33 50 67)))
    |}]
;;

let%expect_test "the head of a trace file" =
  let scenario = List.hd_exn Pin_scenarios.all in
  let lines, (_ : int list list) = Pin_trace.run scenario in
  Pin_trace.to_string scenario lines
  |> String.split_lines
  |> Fn.flip List.take 12
  |> List.iter ~f:print_endline;
  [%expect
    {|
    # uart_tx, from test/pin_trace.ml: do not edit
    # cycles ui_in uio_in uo_out uio_out uio_oe; cycle 0 is the first rising edge
    # after rst_n rises, outputs are the values after the edge
    4 04 00 00 00 00
    4 00 00 00 00 00
    4 02 00 00 00 00
    4 03 00 00 00 00
    4 00 00 00 00 00
    4 01 00 00 00 00
    4 00 00 00 00 00
    4 01 00 00 00 00
    4 02 00 00 00 00
    |}]
;;
