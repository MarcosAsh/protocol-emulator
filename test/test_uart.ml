open! Core
open Protocol_emulator
open Firmware
open Protocol_models
open Machine_run

let%expect_test "uart tx sends two bytes with exact bit periods" =
  let period = 16 in
  let t =
    Machine.create ~config:Program_config.default ~program:(assemble (uart_tx ~period))
    |> ok_exn
  in
  let t = Machine.write_tx t 0x55 |> ok_exn in
  let t = Machine.write_tx t 0xa3 |> ok_exn in
  let t, levels = run t ~cycles:400 ~inputs:0 in
  print_s [%message (runs levels : (int * int) list)];
  print_s [%message (decode_uart levels ~period : int list)];
  print_s [%message (t.fault : Machine.Fault.t) (t.pc : int) (t.now : int)];
  [%expect
    {|
    ("runs levels"
     ((0 1) (1 5) (0 16) (1 16) (0 16) (1 16) (0 16) (1 16) (0 16) (1 16)
      (0 16) (1 22) (0 16) (1 32) (0 48) (1 16) (0 16) (1 100)))
    ("decode_uart levels ~period" (85 163))
    ((t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 2) (t.now 400))
    |}]
;;

let%expect_test "uart tx at 115200 baud from a 50 MHz clock" =
  let period = 434 in
  let t =
    Machine.create ~config:Program_config.default ~program:(assemble uart_tx_host_rate)
    |> ok_exn
  in
  let t =
    List.fold [ period; 0x55; 0xa3 ] ~init:t ~f:(fun t w ->
      Machine.write_tx t w |> ok_exn)
  in
  let t, levels = run t ~cycles:(24 * period) ~inputs:0 in
  print_s [%message (decode_uart levels ~period : int list) (t.fault : Machine.Fault.t)];
  [%expect
    {|
    (("decode_uart levels ~period" (85 163))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let receive levels ~period =
  let t =
    Machine.create ~config:rx_config ~program:(assemble (uart_rx ~period)) |> ok_exn
  in
  let t, received =
    List.fold levels ~init:(t, []) ~f:(fun (t, received) level ->
      let t = Machine.step t ~inputs:level in
      match Machine.read_rx t with
      | Some (byte, t) -> t, byte :: received
      | None -> t, received)
  in
  let received = List.rev received in
  print_s
    [%message
      (received : int list) (t.fault : Machine.Fault.t) (t.irq : bool) (t.pc : int)]
;;

let%expect_test "uart rx receives bytes sampled mid bit" =
  let period = 16 in
  receive (serial_levels [ 0x55; 0xa3; 0xff; 0x00 ] ~period ~stop:1) ~period;
  [%expect
    {|
    ((received (85 163 255 0))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.irq false) (t.pc 4))
    |}]
;;

let%expect_test "uart rx tolerates the sender being four percent off" =
  List.iter [ 24; 26 ] ~f:(fun sender_period ->
    receive (serial_levels [ 0x55; 0xa3; 0x0f ] ~period:sender_period ~stop:1) ~period:25);
  [%expect
    {|
    ((received (85 163 15))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.irq false) (t.pc 4))
    ((received (85 163 15))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.irq false) (t.pc 4))
    |}]
;;

let%expect_test "a missing stop bit raises the interrupt" =
  let period = 16 in
  receive (serial_levels [ 0x42 ] ~period ~stop:0) ~period;
  [%expect
    {|
    ((received (66))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.irq true) (t.pc 4))
    |}]
;;

let%expect_test "uart tx in lockstep" =
  let program = assemble (uart_tx ~period:16) in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~config:Program_config.default
      ~program
      ~preload:[ 0x55; 0xa3 ]
      ~inputs:(fun _ -> 0)
      ()
  in
  [%expect {| ("lockstep held" (cycles 400)) |}]
;;

let%expect_test "uart tx at 115200 baud in lockstep" =
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:(24 * 434)
      ~config:Program_config.default
      ~program:(assemble uart_tx_host_rate)
      ~preload:[ 434; 0x55; 0xa3 ]
      ~inputs:(fun _ -> 0)
      ()
  in
  [%expect {| ("lockstep held" (cycles 10416)) |}]
;;

let%expect_test "uart rx in lockstep" =
  let period = 16 in
  let levels =
    serial_levels [ 0x55; 0xa3; 0xff; 0x00 ] ~period ~stop:1 |> Array.of_list
  in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:(Array.length levels)
      ~config:rx_config
      ~program:(assemble (uart_rx ~period))
      ~inputs:(fun n -> levels.(n))
      ~host:(fun _ -> { Lockstep.Host.idle with pop_rx = true })
      ()
  in
  [%expect {| ("lockstep held" (cycles 724)) |}]
;;
