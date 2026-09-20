open! Core
open Protocol_emulator

let tx_pin = 5

open Firmware
open Protocol_models

let run t ~cycles ~inputs =
  let rec loop t n acc =
    if n = 0
    then t, List.rev acc
    else (
      let t = Machine.step t ~inputs in
      loop t (n - 1) (((t.pin_out lsr tx_pin) land 1) :: acc))
  in
  loop t cycles []
;;

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

let%expect_test "spi master exchanges bytes with a mode 0 slave" =
  let half_period = 8 in
  let t =
    Machine.create ~config:spi_config ~program:(assemble (spi_master ~half_period))
    |> ok_exn
  in
  let t = Machine.write_tx t 0xa5 |> ok_exn in
  let t = Machine.write_tx t 0x3c |> ok_exn in
  let slave = Spi_slave.create [ 0x81; 0x7e ] in
  let rec loop t slave n received sck =
    if n = 0
    then t, slave, List.rev received, List.rev sck
    else (
      let t = Machine.step t ~inputs:(Spi_slave.miso slave lsl miso_pin) in
      let slave =
        Spi_slave.step
          slave
          ~sck:((t.pin_out lsr sck_pin) land 1)
          ~mosi:((t.pin_out lsr mosi_pin) land 1)
      in
      let received, t =
        match Machine.read_rx t with
        | Some (byte, t) -> byte :: received, t
        | None -> received, t
      in
      loop t slave (n - 1) received (((t.pin_out lsr sck_pin) land 1) :: sck))
  in
  let t, slave, master_received, sck = loop t slave 400 [] [] in
  print_s
    [%message
      (master_received : int list)
        (Spi_slave.received slave : int list)
        (runs sck : (int * int) list)
        (t.fault : Machine.Fault.t)];
  [%expect
    {|
    ((master_received (129 126)) ("Spi_slave.received slave" (165 60))
     ("runs sck"
      ((0 22) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8)
       (1 8) (0 8) (1 8) (0 8) (1 8) (0 27) (1 8) (0 8) (1 8) (0 8) (1 8)
       (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 111)))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "a deadline that is already past releases at once and is a fault" =
  let program = assemble {|
    mov t, now
    wait t
    halt
|} in
  let t = Machine.create ~config:Program_config.default ~program |> ok_exn in
  let t, _ = run t ~cycles:6 ~inputs:0 in
  print_s [%message (t.fault : Machine.Fault.t) (t.halted : bool) (t.now : int)];
  [%expect
    {|
    ((t.fault
      ((underflow false) (overflow false) (missed_deadline true) (decode false)))
     (t.halted true) (t.now 6))
    |}]
;;

let%expect_test "pull from an empty fifo faults instead of stalling" =
  let program = assemble {|
    pull
    halt
|} in
  let t = Machine.create ~config:Program_config.default ~program |> ok_exn in
  let t, _ = run t ~cycles:4 ~inputs:0 in
  print_s [%message (t.fault : Machine.Fault.t) (t.halted : bool)];
  [%expect
    {|
    ((t.fault
      ((underflow true) (overflow false) (missed_deadline false) (decode false)))
     (t.halted true))
    |}]
;;

let%expect_test "input capture timestamps a rising edge" =
  let program =
    assemble
      {|
    capture_arm
    wait rise pin 0
    mov x, capture
    mov y, now
    halt
|}
  in
  let t = Machine.create ~config:Program_config.default ~program |> ok_exn in
  let t, _ = run t ~cycles:10 ~inputs:0 in
  let t, _ = run t ~cycles:10 ~inputs:1 in
  print_s [%message (t.x : int) (t.y : int) (t.halted : bool)];
  [%expect {| ((t.x 10) (t.y 12) (t.halted true)) |}]
;;

let%expect_test "a word that does not decode halts with a fault" =
  let t = Machine.create ~config:Program_config.default ~program:[ 0xe0ff ] |> ok_exn in
  let t, _ = run t ~cycles:3 ~inputs:0 in
  print_s [%message (t.fault : Machine.Fault.t) (t.halted : bool) (t.pc : int)];
  [%expect
    {|
    ((t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode true)))
     (t.halted true) (t.pc 0))
    |}]
;;
