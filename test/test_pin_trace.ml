open! Core
open Protocol_emulator
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
    (uart_rx (cycles 10860) (reads ((0055 00a3 00ff) (0000 000f 00f0) (0400))))
    (spi_master (cycles 9404) (reads ((0081 007e) (0400))))
    (i2c_logger (cycles 18310) (reads ((0000))))
    (wrapped_loop (cycles 6666) (reads ((0000))))
    (fifo_poll (cycles 11307)
     (reads
      ((0400) (0800) (0c00) (1234 beef) (0800) (0c00) (1000) (1400)
       (0001 ffff 8000) (7a5c 0ff0) (0000))))
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

(* A program write takes the memory's address for a cycle, which used to make a running
   core fetch the wrong word. The core now ignores the write unless it is halted, so the
   pins of a running core show nothing. *)
let%expect_test "the host writes program memory while the core runs" =
  let loop =
    List.find_exn Pin_scenarios.all ~f:(fun s -> String.equal s.name "wrapped_loop")
  in
  let script =
    List.filter loop.script ~f:(function
      | Run _ | Read _ -> false
      | Write _ | Drive _ -> true)
  in
  let out0 script =
    let lines, (_ : int list list) = Pin_trace.run { loop with script } in
    List.map lines ~f:out0
  in
  let quiet = out0 (script @ [ Run 1000 ]) in
  List.iter (List.range 0 4) ~f:(fun phase ->
    let written =
      out0
        (script
         @ [ Run (20 + phase)
           ; Write (Host_port.Reg.program_addr, [ 100 ])
           ; Write (Host_port.Reg.program, [ 0xa000 ])
           ; Run 100
           ])
    in
    let first_difference =
      List.zip_exn (List.take quiet (List.length written)) written
      |> List.findi ~f:(fun (_ : int) (a, b) -> a <> b)
      |> Option.map ~f:fst
    in
    let around levels =
      Option.map first_difference ~f:(fun n ->
        runs (List.sub levels ~pos:(n - 6) ~len:16))
    in
    print_s
      [%message
        (phase : int)
          (first_difference : int option)
          ~quiet:(around quiet : (int * int) list option)
          ~written:(around written : (int * int) list option)]);
  [%expect
    {|
    ((phase 0) (first_difference ()) (quiet ()) (written ()))
    ((phase 1) (first_difference ()) (quiet ()) (written ()))
    ((phase 2) (first_difference ()) (quiet ()) (written ()))
    ((phase 3) (first_difference ()) (quiet ()) (written ()))
    |}]
;;
