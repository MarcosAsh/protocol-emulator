open! Core
open Protocol_emulator
open Firmware
open Protocol_models

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
