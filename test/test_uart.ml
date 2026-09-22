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

(* 48 MHz over 115200 is 416 2/3 cycles a bit: the period is 416 and the fraction two
   thirds of a cycle, which [wait t+] carries into two bits in three. How far each edge of
   a frame lands from n * 416 2/3 cycles after its start edge: with the fraction the error
   stays inside a band narrower than a cycle, which the whole start bit from [add t, p]
   puts two thirds of a cycle early; a whole period drifts a little every bit. *)
let fractional = { Program_config.default with period_fraction = 43691 }

let%expect_test "uart tx at 115200 baud from a 48 MHz clock" =
  let bit = 1250. /. 3. in
  let frame ~config ~period =
    let t = Machine.create ~config ~program:(assemble uart_tx_host_rate) |> ok_exn in
    let t =
      List.fold [ period; 0x55; 0xa3 ] ~init:t ~f:(fun t w ->
        Machine.write_tx t w |> ok_exn)
    in
    let t, levels = run t ~cycles:(24 * 417) ~inputs:0 in
    let lengths = List.take (List.drop (runs levels) 2) 9 |> List.map ~f:snd in
    let edges =
      List.folding_map lengths ~init:0 ~f:(fun at length -> at + length, at + length)
    in
    let error =
      List.map edges ~f:(fun at ->
        let at = Float.of_int at in
        sprintf "%.2f" (at -. (Float.round_nearest (at /. bit) *. bit)))
    in
    print_s
      [%message
        ""
          (period : int)
          ~fraction:(config.period_fraction : int)
          (lengths : int list)
          (error : string list)
          ~decoded:(decode_uart levels ~period:417 : int list)
          (t.fault.missed_deadline : bool)]
  in
  frame ~config:fractional ~period:416;
  frame ~config:Program_config.default ~period:416;
  frame ~config:Program_config.default ~period:417;
  [%expect
    {|
    ((period 416) (fraction 43691)
     (lengths (416 416 417 417 416 417 417 416 417))
     (error (-0.67 -1.33 -1.00 -0.67 -1.33 -1.00 -0.67 -1.33 -1.00))
     (decoded (85 163)) ("(t.fault).missed_deadline" false))
    ((period 416) (fraction 0) (lengths (416 416 416 416 416 416 416 416 416))
     (error (-0.67 -1.33 -2.00 -2.67 -3.33 -4.00 -4.67 -5.33 -6.00))
     (decoded (85 163)) ("(t.fault).missed_deadline" false))
    ((period 417) (fraction 0) (lengths (417 417 417 417 417 417 417 417 417))
     (error (0.33 0.67 1.00 1.33 1.67 2.00 2.33 2.67 3.00)) (decoded (85 163))
     ("(t.fault).missed_deadline" false))
    |}]
;;

let%expect_test "uart tx with a fractional period in lockstep" =
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:(24 * 417)
      ~config:fractional
      ~program:(assemble uart_tx_host_rate)
      ~preload:[ 416; 0x55; 0xa3 ]
      ~inputs:(fun _ -> 0)
      ()
  in
  [%expect {| ("lockstep held" (cycles 10008)) |}]
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
