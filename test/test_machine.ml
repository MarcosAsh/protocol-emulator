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
  [%expect {| ((programs 64) (words_pulled 622) (agree 64) (disagree 0)) |}]
;;

(* the check values of CRC-16/USB and CRC-5/USB over "123456789" are 0xb4c8 and 0x19, both
   after the final inversion the firmware does with [mov] *)
let crc_of_bytes ~config bytes =
  let program =
    assemble
      {|
byte:
    wait tx
    pull
    set x, 7
bit:
    out pins, 1
    jmp x--, bit
    jmp byte
|}
  in
  let t = Machine.create ~config ~program |> ok_exn in
  let feed t bytes =
    match bytes with
    | b :: rest when List.length t.Machine.tx_fifo < Machine.fifo_depth ->
      Machine.write_tx t b |> ok_exn, rest
    | bytes -> t, bytes
  in
  let rec loop t bytes n =
    if n = 0
    then t
    else (
      let t, bytes = feed t bytes in
      loop (Machine.step t ~inputs:0) bytes (n - 1))
  in
  let t = loop t bytes (50 * List.length bytes) in
  t.crc, t.fault
;;

let check_bytes = String.to_list "123456789" |> List.map ~f:Char.to_int

let%expect_test "crc-16/usb over the check string" =
  let crc, fault = crc_of_bytes ~config:Program_config.default check_bytes in
  print_s [%message (crc lxor 0xffff : Int.Hex.t) (fault : Machine.Fault.t)];
  [%expect
    {|
    (("crc lxor 0xffff" 0xb4c8)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "crc-5/usb over the check string" =
  let config =
    { Program_config.default with crc_width = 5; crc_poly = 0x14; crc_init = 0x1f }
  in
  let crc, fault = crc_of_bytes ~config check_bytes in
  print_s [%message (crc lxor 0x1f : Int.Hex.t) (fault : Machine.Fault.t)];
  [%expect
    {|
    (("crc lxor 0x1f" 0x19)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "crc-16/xmodem shifts the other way" =
  let config =
    { Program_config.default with
      out_shift = Left
    ; crc_poly = 0x1021
    ; crc_init = 0
    ; crc_reflect = false
    }
  in
  let crc, fault = crc_of_bytes ~config (List.map check_bytes ~f:(fun b -> b lsl 8)) in
  print_s [%message (crc : Int.Hex.t) (fault : Machine.Fault.t)];
  [%expect
    {|
    ((crc 0x31c3)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "a stuffed zero follows every six ones" =
  let config = { Program_config.default with stuff_threshold = 6 } in
  let program =
    assemble
      {|
    pull
    set x, 15
bit:
    out pins, 1
    jmp stuff, stuff
    jmp x--, bit
    halt
stuff:
    set pins, 0
    stuff_reset
    jmp x--, bit
    halt
|}
  in
  let t = Machine.create ~config ~program |> ok_exn in
  let t = Machine.write_tx t 0xffff |> ok_exn in
  let t, levels = run t ~cycles:120 ~inputs:0 in
  print_s
    [%message (runs levels : (int * int) list) (t.halted : bool) (t.crc : Int.Hex.t)];
  [%expect
    {|
    (("runs levels" ((0 2) (1 28) (0 4) (1 28) (0 4) (1 54))) (t.halted true)
     (t.crc 0x0))
    |}]
;;

let%expect_test "usb low speed packets survive the wire" =
  (* the SETUP token to address 0, endpoint 0, and a DATA0 packet with its crc *)
  let setup = [ 0x2d; 0x00; 0x10 ] in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes data) in
  let data0 = (0xc3 :: data) @ [ crc land 0xff; crc lsr 8 ] in
  let token_crc = Usb_ls.crc5 (List.take (Usb_ls.bits_of_bytes [ 0x00; 0x10 ]) 11) in
  let bit_period = 32 in
  let sniffer =
    List.fold
      [ setup; data0 ]
      ~init:(Usb_ls.Sniffer.create ~bit_period)
      ~f:(fun sniffer packet ->
        let idle = List.init 3 ~f:(fun _ -> Usb_ls.Line.J) in
        List.fold
          (Usb_ls.encode packet @ idle)
          ~init:sniffer
          ~f:(fun sniffer line ->
            let dp, dm =
              match line with
              | J -> 0, 1
              | K -> 1, 0
              | Se0 -> 0, 0
            in
            Fn.apply_n_times
              ~n:bit_period
              (fun s -> Usb_ls.Sniffer.step s ~dp ~dm)
              sniffer))
  in
  print_s
    [%message
      (token_crc : Int.Hex.t)
        (crc : Int.Hex.t)
        (Usb_ls.Sniffer.packets sniffer : int list list)];
  [%expect
    {|
    ((token_crc 0x2) (crc 0x94dd)
     ("Usb_ls.Sniffer.packets sniffer"
      ((45 0 16) (195 128 6 0 1 0 0 64 0 221 148))))
    |}]
;;

let%expect_test "usb tx builds the crc and stuffs the get descriptor packet" =
  let bit_period = 32 in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let words =
    (bit_period :: 0x80 :: 0xc3 :: (List.length data - 1) :: data)
    @ [ 0x80; 0xc3; 0; 0xff ]
  in
  let t = Machine.create ~config:usb_config ~program:(assemble usb_tx) |> ok_exn in
  let feed (t : Machine.t) words =
    match words with
    | w :: rest when List.length t.tx_fifo < Machine.fifo_depth ->
      Machine.write_tx t w |> ok_exn, rest
    | words -> t, words
  in
  let rec loop (t : Machine.t) words sniffer n =
    if n = 0
    then t, sniffer
    else (
      let t, words = feed t words in
      let t = Machine.step t ~inputs:0 in
      let pin p = (t.pin_out lsr p) land 1 in
      let sniffer =
        Usb_ls.Sniffer.step sniffer ~dp:(pin usb_dp_pin) ~dm:(pin usb_dm_pin)
      in
      loop t words sniffer (n - 1))
  in
  let t, sniffer = loop t words (Usb_ls.Sniffer.create ~bit_period) (bit_period * 200) in
  print_s
    [%message
      (Usb_ls.Sniffer.packets sniffer : int list list) (t.fault : Machine.Fault.t)];
  [%expect
    {|
    (("Usb_ls.Sniffer.packets sniffer"
      ((195 128 6 0 1 0 0 64 0 221 148) (195 255 0 255)))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "usb rx decodes, unstuffs and checks two packets" =
  let bit_period = 32 in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes data) in
  let data0 = (0xc3 :: data) @ [ crc land 0xff; crc lsr 8 ] in
  let ones = [ 0xc3; 0xff; 0x00; 0xff ] in
  let line_levels packet =
    List.concat_map
      (Usb_ls.encode packet @ List.init 4 ~f:(fun _ -> Usb_ls.Line.J))
      ~f:(fun line ->
        let dp, dm =
          match line with
          | J -> 0, 1
          | K -> 1, 0
          | Se0 -> 0, 0
        in
        List.init bit_period ~f:(fun _ ->
          (dp lsl usb_rx_dp_pin) lor (dm lsl usb_rx_dm_pin)))
  in
  let levels =
    List.init 40 ~f:(fun _ -> 1 lsl usb_rx_dm_pin) @ line_levels data0 @ line_levels ones
  in
  let t =
    Machine.create
      ~config:usb_rx_config
      ~program:(assemble (usb_rx ~half_period:(bit_period / 2)))
    |> ok_exn
  in
  let t = Machine.write_tx t bit_period |> ok_exn in
  let t, words =
    List.fold levels ~init:(t, []) ~f:(fun (t, words) inputs ->
      let t = Machine.step t ~inputs in
      match Machine.read_rx t with
      | Some (w, t) -> t, w :: words
      | None -> t, words)
  in
  let words = List.rev words in
  let bytes = List.map words ~f:(fun w -> w lsr 8) in
  let residuals =
    List.filteri words ~f:(fun i _ ->
      i = List.length data0 + 1 || i = List.length words - 1)
  in
  let expected = List.map [ data0; ones ] ~f:Usb_ls.residual in
  print_s
    [%message
      (bytes : int list)
        (residuals : Int.Hex.t list)
        (expected : Int.Hex.t list)
        (t.fault : Machine.Fault.t)];
  [%expect
    {|
    ((bytes (128 195 128 6 0 1 0 0 64 0 221 148 140 128 195 255 0 255 234))
     (residuals (0x8ce4 0xea69)) (expected (0x8ce4 0xea69))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
