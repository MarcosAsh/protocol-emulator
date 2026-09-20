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

(* the slave shifts the next reply out as each byte ends, so the host queues one more
   reply than there are bytes or the last edge pulls from an empty fifo *)
let run_spi_slave ~half_period ?gap ~replies bytes =
  let t =
    Machine.create ~config:spi_slave_config ~program:(assemble spi_slave) |> ok_exn
  in
  let t =
    List.fold replies ~init:t ~f:(fun t reply ->
      Machine.write_tx t (reply lsl 8) |> ok_exn)
  in
  let master = Spi_peer.create ?gap ~half_period bytes in
  let rec loop t master n received =
    if n = 0
    then t, master, List.rev received
    else (
      let inputs =
        (Spi_peer.sck master lsl slave_sck_pin)
        lor (Spi_peer.mosi master lsl slave_mosi_pin)
      in
      let t = Machine.step t ~inputs in
      let master = Spi_peer.step master ~miso:((t.pin_out lsr slave_miso_pin) land 1) in
      let received, t =
        match Machine.read_rx t with
        | Some (byte, t) -> byte :: received, t
        | None -> received, t
      in
      loop t master (n - 1) received)
  in
  let t, master, slave_received = loop t master 400 [] in
  print_s
    [%message
      (slave_received : int list)
        (Spi_peer.received master : int list)
        (Spi_peer.idle master : bool)
        (t.fault : Machine.Fault.t)]
;;

let%expect_test "spi slave exchanges bytes with a mode 0 master" =
  run_spi_slave ~half_period:8 ~replies:[ 0x81; 0x7e; 0x11; 0 ] [ 0xa5; 0x3c; 0xf0 ];
  [%expect
    {|
    ((slave_received (165 60 240)) ("Spi_peer.received master" (129 126 17))
     ("Spi_peer.idle master" true)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "spi slave keeps up with back to back bytes at four cycles a half period" =
  run_spi_slave ~half_period:4 ~replies:[ 0x81; 0x7e; 0x11; 0 ] [ 0xa5; 0x3c; 0xf0 ];
  [%expect
    {|
    ((slave_received (165 60 240)) ("Spi_peer.received master" (129 126 17))
     ("Spi_peer.idle master" true)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "spi slave with gaps between bytes" =
  run_spi_slave
    ~half_period:4
    ~gap:13
    ~replies:[ 0x81; 0x7e; 0x11; 0 ]
    [ 0xa5; 0x3c; 0xf0 ];
  [%expect
    {|
    ((slave_received (165 60 240)) ("Spi_peer.received master" (129 126 17))
     ("Spi_peer.idle master" true)
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

(* P3: the host reaches the pins through the words it sends, never through when it sends
   them. Two runs of one program get the same words in the same order, one whenever the
   fifo has room and one at random, and pop the rx fifo on different schedules. Their pins
   agree every cycle unless the random schedule starved or flooded a fifo, which the fault
   register reports. Programs with [wait tx] or [wait rx] block on the host on purpose and
   are left out. *)
let%expect_test "host timing never reaches the pins" =
  let random = Splittable_random.of_int 3 in
  let int hi = Splittable_random.int random ~lo:0 ~hi in
  let cycles = 2000 in
  let words_pulled = ref 0 in
  let trial () =
    let config = Random_program.config random in
    let program = Random_program.program ~waits:`Input_pins random ~config in
    let inputs = List.init cycles ~f:(fun _ -> int 0xfffff) in
    let words = Array.init (cycles + Machine.fifo_depth) ~f:(fun _ -> int 0xffff) in
    let run ~push ~pop =
      let next = ref 0 in
      let feed (t : Machine.t) =
        if push (List.length t.tx_fifo)
        then (
          let t = Machine.write_tx t words.(!next) |> ok_exn in
          Int.incr next;
          t)
        else t
      in
      let preload (t : Machine.t) =
        if List.length t.tx_fifo < Machine.fifo_depth
        then Machine.write_tx t words.(!next) |> ok_exn
        else t
      in
      let t = Machine.create ~config ~program |> ok_exn in
      let t =
        Fn.apply_n_times
          ~n:Machine.fifo_depth
          (fun t ->
            Int.incr next;
            preload t)
          t
      in
      let t, trace =
        List.fold_map inputs ~init:t ~f:(fun t levels ->
          let t =
            match Machine.read_rx t with
            | Some (_, popped) when pop () -> popped
            | _ -> t
          in
          let t = Machine.step t ~inputs:levels |> feed in
          t, (t.pin_out, t.pin_dir))
      in
      t, trace, !next - Machine.fifo_depth
    in
    let _, eager, pulled =
      run ~push:(fun level -> level < Machine.fifo_depth) ~pop:(fun () -> true)
    in
    words_pulled := !words_pulled + pulled;
    let (t : Machine.t), lazily, _ =
      run
        ~push:(fun level -> level < Machine.fifo_depth && int 3 > 0)
        ~pop:(fun () -> int 1 = 0)
    in
    if t.fault.underflow || t.fault.overflow
    then `Inconclusive
    else if List.equal [%equal: int * int] eager lazily
    then `Agree
    else `Disagree
  in
  let programs = 64 in
  let results = List.init programs ~f:(fun _ -> trial ()) in
  let count outcome = List.count results ~f:(fun r -> Poly.equal r outcome) in
  let agree = count `Agree in
  let disagree = count `Disagree in
  let words_pulled = !words_pulled in
  print_s [%message (programs : int) (words_pulled : int) (agree : int) (disagree : int)];
  [%expect {| ((programs 64) (words_pulled 663) (agree 64) (disagree 0)) |}]
;;
