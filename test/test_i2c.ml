open! Core
open Protocol_emulator
open Firmware
open Protocol_models

let run_transaction words ~memory ~cycles =
  let quarter = 8 in
  let t =
    Machine.create ~config:i2c_config ~program:(assemble (i2c_master ~quarter)) |> ok_exn
  in
  let slave = I2c_slave.create ~address:0x50 ~memory in
  let feed (t : Machine.t) pending =
    match pending with
    | w :: rest when List.length t.tx_fifo < Machine.fifo_depth ->
      Machine.write_tx t w |> ok_exn, rest
    | pending -> t, pending
  in
  let rec loop (t : Machine.t) slave pending n replies =
    if n = 0
    then t, slave, List.rev replies
    else (
      let t, pending = feed t pending in
      let master_sda = 1 - ((t.pin_dir lsr sda) land 1) in
      let bus_sda = if I2c_slave.drive_low slave then 0 else master_sda in
      let bus_scl = 1 - ((t.pin_dir lsr scl) land 1) in
      let t = Machine.step t ~inputs:((bus_sda lsl sda) lor (bus_scl lsl scl)) in
      let slave = I2c_slave.step slave ~sda:bus_sda ~scl:bus_scl in
      let replies, t =
        match Machine.read_rx t with
        | Some (r, t) -> r :: replies, t
        | None -> replies, t
      in
      loop t slave pending (n - 1) replies)
  in
  let t, slave, replies = loop t slave words cycles [] in
  print_s
    [%message
      (replies : int list)
        (I2c_slave.log slave : string list)
        (t.fault : Machine.Fault.t)
        (t.pc : int)]
;;

let%expect_test "write a register then read it back" =
  let memory = Array.create ~len:16 0 in
  run_transaction
    [ i2c_word ~start:true 0xa0; i2c_word 3; i2c_word ~stop:true 0xaa ]
    ~memory
    ~cycles:1500;
  [%expect
    {|
    ((replies (0 0 0))
     ("I2c_slave.log slave"
      (start "address 80 write" "pointer 3" "write 170" stop))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 1))
    |}];
  print_s [%message (memory : int array)];
  [%expect {| (memory (0 0 0 170 0 0 0 0 0 0 0 0 0 0 0 0)) |}];
  run_transaction
    [ i2c_word ~start:true 0xa0
    ; i2c_word 3
    ; i2c_word ~start:true 0xa1
    ; i2c_word ~read:true 0
    ; i2c_word ~read:true ~stop:true 0
    ]
    ~memory:(Array.mapi memory ~f:(fun i v -> if i = 4 then 0x5c else v))
    ~cycles:2500;
  [%expect
    {|
    ((replies (0 0 0 170 92))
     ("I2c_slave.log slave"
      (start "address 80 write" "pointer 3" start "address 80 read" nack stop))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 1))
    |}]
;;

let%expect_test "a slave at another address does not answer" =
  run_transaction
    [ i2c_word ~start:true ~stop:true 0xa2 ]
    ~memory:(Array.create ~len:16 0)
    ~cycles:800;
  [%expect
    {|
    ((replies (1))
     ("I2c_slave.log slave" (start "address 81 write ignored" stop))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 1))
    |}]
;;

let run_slave ?(replies = []) ops ~cycles =
  let t =
    Machine.create ~config:i2c_slave_config ~program:(assemble i2c_slave) |> ok_exn
  in
  let t =
    List.fold ((0x50 lsl 1) :: replies) ~init:t ~f:(fun t w ->
      Machine.write_tx t w |> ok_exn)
  in
  let master = I2c_peer.create ~quarter:8 ops in
  let rec loop (t : Machine.t) master n received =
    if n = 0
    then t, master, List.rev received
    else (
      let slave_sda = 1 - ((t.pin_dir lsr sda) land 1) in
      let bus_sda = I2c_peer.sda master land slave_sda in
      let bus_scl = I2c_peer.scl master in
      let t = Machine.step t ~inputs:((bus_sda lsl sda) lor (bus_scl lsl scl)) in
      let master = I2c_peer.step master ~sda:bus_sda in
      let received, t =
        match Machine.read_rx t with
        | Some (r, t) -> r :: received, t
        | None -> received, t
      in
      loop t master (n - 1) received)
  in
  let t, master, received = loop t master cycles [] in
  print_s
    [%message
      (received : int list)
        (I2c_peer.log master : string list)
        (I2c_peer.idle master : bool)
        (t.fault : Machine.Fault.t)
        (t.pc : int)]
;;

let%expect_test "slave takes a write" =
  run_slave [ Start; Write 0xa0; Write 3; Write 0xaa; Stop ] ~cycles:1500;
  [%expect {|
    ((received (160 3 170)) ("I2c_peer.log master" (ack ack ack))
     ("I2c_peer.idle master" true)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 4))
    |}]
;;

let%expect_test "slave answers a read after a repeated start" =
  run_slave
    ~replies:[ 0x12; 0x34 ]
    [ Start
    ; Write 0xa0
    ; Write 3
    ; Start
    ; Write 0xa1
    ; Read { ack = true }
    ; Read { ack = false }
    ; Stop
    ]
    ~cycles:3000;
  [%expect {|
    ((received (160 3 161))
     ("I2c_peer.log master" (ack ack ack "read 18" "read 52"))
     ("I2c_peer.idle master" true)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 4))
    |}]
;;

let%expect_test "slave ignores another address" =
  run_slave
    [ Start; Write 0x42; Write 3; Stop; Start; Write 0xa0; Write 7; Stop ]
    ~cycles:2500;
  [%expect {|
    ((received (160 7)) ("I2c_peer.log master" (nack nack ack ack))
     ("I2c_peer.idle master" true)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 4))
    |}]
;;
