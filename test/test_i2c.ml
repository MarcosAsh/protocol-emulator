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
  [%expect
    {|
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
  [%expect
    {|
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
  [%expect
    {|
    ((received (160 7)) ("I2c_peer.log master" (nack nack ack ack))
     ("I2c_peer.idle master" true)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 4))
    |}]
;;

let%expect_test "one core polls the slave over i2c and logs over uart" =
  let memory = Array.init 16 ~f:(fun i -> 0x10 + (0x11 * i)) in
  let t =
    Machine.create ~config:i2c_logger_config ~program:(assemble i2c_logger) |> ok_exn
  in
  let slave = I2c_slave.create ~address:0x50 ~memory in
  let rec loop (t : Machine.t) slave n levels =
    if n = 0
    then t, slave, List.rev levels
    else (
      let master_sda = 1 - ((t.pin_dir lsr sda) land 1) in
      let bus_sda = if I2c_slave.drive_low slave then 0 else master_sda in
      let bus_scl = 1 - ((t.pin_dir lsr scl) land 1) in
      let t = Machine.step t ~inputs:((bus_sda lsl sda) lor (bus_scl lsl scl)) in
      let slave = I2c_slave.step slave ~sda:bus_sda ~scl:bus_scl in
      loop t slave (n - 1) (((t.pin_out lsr logger_uart_pin) land 1) :: levels))
  in
  let t, slave, levels = loop t slave 3000 [] in
  print_s
    [%message
      (decode_uart levels ~period:16 : int list)
        (I2c_slave.log slave : string list)
        (t.fault : Machine.Fault.t)];
  [%expect
    {|
    (("decode_uart levels ~period:16" (16 33 50))
     ("I2c_slave.log slave"
      (start "address 80 read" nack stop start "address 80 read" nack stop start
       "address 80 read" nack stop start "address 80 read" nack))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "i2c master in lockstep" =
  let memory = Array.create ~len:16 0 in
  let slave = ref (I2c_slave.create ~address:0x50 ~memory) in
  let words =
    [ i2c_word ~start:true 0xa0; i2c_word 3; i2c_word ~stop:true 0xaa ] |> ref
  in
  let bus (m : Machine.t) =
    let master_sda = 1 - ((m.pin_dir lsr sda) land 1) in
    let bus_sda = if I2c_slave.drive_low !slave then 0 else master_sda in
    let bus_scl = 1 - ((m.pin_dir lsr scl) land 1) in
    bus_sda, bus_scl
  in
  let model = ref None in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:1500
      ~config:i2c_config
      ~program:(assemble (i2c_master ~quarter:8))
      ~inputs:(fun _ ->
        match !model with
        | None -> (1 lsl sda) lor (1 lsl scl)
        | Some m ->
          let bus_sda, bus_scl = bus m in
          (bus_sda lsl sda) lor (bus_scl lsl scl))
      ~host:(fun _ ->
        match !words with
        | w :: rest ->
          words := rest;
          { Lockstep.Host.idle with tx = Some w; pop_rx = true }
        | [] -> { Lockstep.Host.idle with pop_rx = true })
      ~react:(fun m ->
        let bus_sda, bus_scl = bus m in
        slave := I2c_slave.step !slave ~sda:bus_sda ~scl:bus_scl;
        model := Some m)
      ()
  in
  let log = I2c_slave.log !slave in
  print_s [%message (log : string list) (memory : int array)];
  [%expect
    {|
    ("lockstep held" (cycles 1500))
    ((log (start "address 80 write" "pointer 3" "write 170" stop))
     (memory (0 0 0 170 0 0 0 0 0 0 0 0 0 0 0 0)))
    |}]
;;

let%expect_test "i2c slave in lockstep" =
  let master =
    ref
      (I2c_peer.create
         ~quarter:8
         [ Start
         ; Write 0xa0
         ; Write 3
         ; Start
         ; Write 0xa1
         ; Read { ack = true }
         ; Read { ack = false }
         ; Stop
         ])
  in
  let bus_sda (m : Machine.t) =
    I2c_peer.sda !master land (1 - ((m.pin_dir lsr sda) land 1))
  in
  let last_sda = ref 1 in
  let model =
    Lockstep.lockstep
      ~cycles:3000
      ~config:i2c_slave_config
      ~program:(assemble i2c_slave)
      ~preload:[ 0x50 lsl 1; 0x12; 0x34 ]
      ~inputs:(fun _ -> (!last_sda lsl sda) lor (I2c_peer.scl !master lsl scl))
      ~react:(fun m ->
        last_sda := bus_sda m;
        master := I2c_peer.step !master ~sda:!last_sda)
      ()
  in
  print_s
    [%message
      (I2c_peer.log !master : string list)
        (List.length model.rx_fifo : int)
        (model.pc : int)];
  [%expect
    {|
    ("lockstep held" (cycles 3000))
    (("I2c_peer.log (!master)" (ack ack ack "read 18" "read 52"))
     ("List.length model.rx_fifo" 3) (model.pc 4))
    |}]
;;

let%expect_test "i2c logger in lockstep" =
  let memory = Array.init 16 ~f:(fun i -> 0x10 + (0x11 * i)) in
  let slave = ref (I2c_slave.create ~address:0x50 ~memory) in
  let levels = ref [] in
  let bus_sda (m : Machine.t) =
    if I2c_slave.drive_low !slave then 0 else 1 - ((m.pin_dir lsr sda) land 1)
  in
  let last_sda = ref 1 in
  let last_scl = ref 1 in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:3000
      ~config:i2c_logger_config
      ~program:(assemble i2c_logger)
      ~inputs:(fun _ -> (!last_sda lsl sda) lor (!last_scl lsl scl))
      ~react:(fun m ->
        last_sda := bus_sda m;
        last_scl := 1 - ((m.pin_dir lsr scl) land 1);
        slave := I2c_slave.step !slave ~sda:!last_sda ~scl:!last_scl;
        levels := ((m.pin_out lsr logger_uart_pin) land 1) :: !levels)
      ()
  in
  let logged = decode_uart (List.rev !levels) ~period:16 in
  print_s [%message (logged : int list) (I2c_slave.log !slave : string list)];
  [%expect
    {|
    ("lockstep held" (cycles 3000))
    ((logged (16 33 50))
     ("I2c_slave.log (!slave)"
      (start "address 80 read" nack stop start "address 80 read" nack stop start
       "address 80 read" nack stop start "address 80 read" nack)))
    |}]
;;

(* The smallest quarter at which the certified master meets UM10204 Fast-mode Plus at 50
   MHz, and its bounds. These are edges at the pins: the master does not wait for SCL
   high, so rise time comes off tHIGH, tSU;STA and tSU;STO, the last two exactly at their
   limits here. A full 120 ns Fm+ rise would need a quarter of 22. *)
let%expect_test "the certified master's pins keep to fast-mode plus at 50 MHz" =
  let clock_mhz = 50 in
  let bounds quarter =
    let program = Asm.assemble (i2c_master ~quarter) |> ok_exn in
    match Analyser.check ~config:(Asm.Program.configure program i2c_config) program with
    | Error _ -> None
    | Ok (_ : Analyser.Verdict.t) ->
      Some
        (I2c_timing.check ~clock_mhz ~config:i2c_config program I2c_timing.fast_mode_plus)
  in
  let failing bounds =
    List.filter_map bounds ~f:(fun ({ timing; cycles; met } : I2c_timing.Bound.t) ->
      Option.some_if
        (not met)
        [%string
          "%{timing.name} %{Option.value_map cycles ~default:\"never\" \
           ~f:Interval.to_string}"])
  in
  List.iter (List.range 10 13) ~f:(fun quarter ->
    printf
      "quarter %d is short: %s\n"
      quarter
      (Option.value_map (bounds quarter) ~default:"refused" ~f:(fun bounds ->
         String.concat ~sep:", " (failing bounds))));
  let quarter, bounds =
    List.find_map_exn (List.range 1 64) ~f:(fun quarter ->
      Option.bind (bounds quarter) ~f:(fun bounds ->
        Option.some_if (List.is_empty (failing bounds)) (quarter, bounds)))
  in
  let certified = Certified.find_exn "i2c_master" in
  print_s
    [%message
      (quarter : int)
        ~certified:(String.equal certified.source (i2c_master ~quarter) : bool)
        ~scl_khz:(clock_mhz * 1000 / (4 * quarter) : int)];
  printf "%-10s %8s  %-9s %s\n" "timing" "Fm+ ns" "cycles" "ns";
  List.iter bounds ~f:(fun { timing; cycles; met } ->
    let ns n = n * 1000 / clock_mhz in
    printf
      "%-10s %8s  %-9s %s%s\n"
      timing.name
      (sprintf ">= %d" timing.min_ns)
      (Option.value_map cycles ~default:"never" ~f:Interval.to_string)
      (Option.value_map cycles ~default:"-" ~f:(fun (c : Interval.t) ->
         Interval.to_string { lo = Option.map c.lo ~f:ns; hi = Option.map c.hi ~f:ns }))
      (if met then "" else "  SHORT"));
  let program = assemble certified.source in
  let t = Machine.create ~config:i2c_config ~program |> ok_exn in
  let t =
    List.fold
      [ i2c_word ~start:true 0xa0
      ; i2c_word 3
      ; i2c_word ~stop:true 0xaa
      ; i2c_word ~start:true 0xa0
      ; i2c_word 3
      ; i2c_word ~start:true 0xa1
      ; i2c_word ~read:true ~stop:true 0
      ]
      ~init:t
      ~f:(fun t word -> Machine.write_tx t word |> ok_exn)
  in
  let slave = ref (I2c_slave.create ~address:0x50 ~memory:(Array.create ~len:16 0)) in
  let bus_scl (m : Machine.t) = 1 - ((m.pin_dir lsr scl) land 1) in
  let bus_sda (m : Machine.t) =
    if I2c_slave.drive_low !slave then 0 else 1 - ((m.pin_dir lsr sda) land 1)
  in
  let t, levels =
    List.fold
      (List.range 0 (320 * quarter))
      ~init:(t, [])
      ~f:(fun (t, levels) _ ->
        let t = Machine.step t ~inputs:((bus_sda t lsl sda) lor (bus_scl t lsl scl)) in
        slave := I2c_slave.step !slave ~sda:(bus_sda t) ~scl:(bus_scl t);
        t, bus_scl t :: levels)
  in
  (* the runs between the first and the last, which are the idle bus *)
  let runs = List.drop (List.drop_last_exn (runs (List.rev levels))) 1 in
  let shortest level =
    List.filter_map runs ~f:(fun (l, n) -> Option.some_if (l = level) n)
    |> List.min_elt ~compare
  in
  print_s
    [%message
      (I2c_slave.log !slave : string list)
        ~shortest_low:(shortest 0 : int option)
        ~shortest_high:(shortest 1 : int option)
        (t.fault : Machine.Fault.t)];
  [%expect
    {|
    quarter 10 is short: SCL period 40..?, tLOW 20..?, tHD;STA 10, tSU;STA 10, tSU;STO 10
    quarter 11 is short: SCL period 44..?, tLOW 22..?, tHD;STA 11, tSU;STA 11, tSU;STO 11
    quarter 12 is short: SCL period 48..?, tLOW 24..?, tHD;STA 12, tSU;STA 12, tSU;STO 12
    ((quarter 13) (certified true) (scl_khz 961))
    timing       Fm+ ns  cycles    ns
    SCL period  >= 1000  52..?     1040..?
    tLOW         >= 500  26..?     520..?
    tHIGH        >= 260  26..?     520..?
    tHD;STA      >= 260  13        260
    tSU;STA      >= 260  13        260
    tHD;DAT        >= 0  1..?      20..?
    tSU;DAT       >= 50  12..33    240..660
    tSU;STO      >= 260  13        260
    tBUF         >= 500  44..?     880..?
    (("I2c_slave.log (!slave)"
      (start "address 80 write" "pointer 3" "write 170" stop start
       "address 80 write" "pointer 3" start "address 80 read" nack stop))
     (shortest_low (26)) (shortest_high (26))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
