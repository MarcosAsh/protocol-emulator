open! Core
open Protocol_emulator
open Firmware
open Protocol_models

let bit levels pin = (levels lsr pin) land 1

(* The host of the directed runs: it writes [words] as the tx fifo has room and reads
   whatever arrives. *)
let run coverage ?(cycles = 400) ?(words = []) ?(inputs = fun () -> 0) ?(react = ignore) =
  let pending = ref words in
  let level = ref 0 in
  let host _ =
    match !pending with
    | word :: rest when !level < Machine.fifo_depth - 1 ->
      pending := rest;
      { Lockstep.Host.idle with tx = Some word; pop_rx = true }
    | _ -> { Lockstep.Host.idle with pop_rx = true }
  in
  fun ~config program ->
    let (_ : Machine.t), mismatch =
      Lockstep.run
        ~cycles
        ~coverage
        ~config
        ~program:(assemble program)
        ~inputs:(fun _ -> inputs ())
        ~host
        ~react:(fun m ->
          level := List.length m.tx_fifo;
          react m)
        ()
    in
    if Option.is_some mismatch then print_s [%message "MISMATCH" program]
;;

let directed coverage =
  let run = run coverage in
  run ~words:[ 0x55; 0xa3 ] ~config:Program_config.default (uart_tx ~period:16);
  run ~words:[ 16; 0x55 ] ~config:Program_config.default uart_tx_host_rate;
  let levels = ref (serial_levels [ 0x55; 0x00 ] ~period:16 ~stop:1 @ [ 0 ]) in
  let next () =
    match !levels with
    | [ last ] -> last
    | level :: rest ->
      levels := rest;
      level
    | [] -> 0
  in
  run ~cycles:600 ~inputs:next ~config:rx_config (uart_rx ~period:16);
  let slave = ref (Spi_slave.create [ 0x81; 0x7e ]) in
  run
    ~words:[ 0xa5; 0x3c ]
    ~inputs:(fun () -> Spi_slave.miso !slave lsl miso_pin)
    ~react:(fun m ->
      slave
      := Spi_slave.step !slave ~sck:(bit m.pin_out sck_pin) ~mosi:(bit m.pin_out mosi_pin))
    ~config:spi_config
    (spi_master ~half_period:8);
  let master = ref (Spi_peer.create ~half_period:4 [ 0xa5; 0x3c ]) in
  run
    ~words:[ 0x8100; 0x7e00; 0 ]
    ~inputs:(fun () ->
      (Spi_peer.sck !master lsl slave_sck_pin)
      lor (Spi_peer.mosi !master lsl slave_mosi_pin))
    ~react:(fun m -> master := Spi_peer.step !master ~miso:(bit m.pin_out slave_miso_pin))
    ~config:spi_slave_config
    spi_slave;
  let slave = ref (I2c_slave.create ~address:0x50 ~memory:(Array.create ~len:16 0x5a)) in
  let bus = ref ((1 lsl sda) lor (1 lsl scl)) in
  let react (m : Machine.t) =
    let bus_sda = if I2c_slave.drive_low !slave then 0 else 1 - bit m.pin_dir sda in
    let bus_scl = 1 - bit m.pin_dir scl in
    bus := (bus_sda lsl sda) lor (bus_scl lsl scl);
    slave := I2c_slave.step !slave ~sda:bus_sda ~scl:bus_scl
  in
  let words = [ i2c_word ~start:true 0xa0; i2c_word 3; i2c_word ~stop:true 0xaa ] in
  let inputs () = !bus in
  run ~cycles:1500 ~words ~inputs ~react ~config:i2c_config (i2c_master ~quarter:8);
  run ~cycles:3000 ~inputs ~react ~config:i2c_logger_config i2c_logger;
  let master =
    ref (I2c_peer.create ~quarter:8 [ Start; Write 0xa0; Write 3; Start; Write 0xa1 ])
  in
  let bus_sda = ref 1 in
  run
    ~cycles:1500
    ~words:[ 0x50 lsl 1; 0x12 ]
    ~inputs:(fun () -> (!bus_sda lsl sda) lor (I2c_peer.scl !master lsl scl))
    ~react:(fun m ->
      bus_sda := I2c_peer.sda !master land (1 - bit m.pin_dir sda);
      master := I2c_peer.step !master ~sda:!bus_sda)
    ~config:i2c_slave_config
    i2c_slave;
  run ~cycles:3200 ~words:[ 32; 0x80; 0xc3; 0; 0xff ] ~config:usb_config usb_tx;
  let lines =
    List.concat_map
      (Usb_ls.encode [ 0xc3; 0x80; 0x06 ])
      ~f:(fun line ->
        let dp, dm =
          match line with
          | J -> 0, 1
          | K -> 1, 0
          | Se0 -> 0, 0
        in
        List.init 32 ~f:(fun _ -> (dp lsl usb_rx_dp_pin) lor (dm lsl usb_rx_dm_pin)))
  in
  let levels = ref (List.init 40 ~f:(fun _ -> 1 lsl usb_rx_dm_pin) @ lines) in
  let next () =
    match !levels with
    | level :: rest ->
      levels := rest;
      level
    | [] -> 1 lsl usb_rx_dm_pin
  in
  run
    ~cycles:1600
    ~words:[ 32 ]
    ~inputs:next
    ~config:usb_rx_config
    (usb_rx ~half_period:16);
  let out0 = ref 0 in
  run
    ~inputs:(fun () -> !out0)
    ~react:(fun m -> out0 := bit m.pin_out 5)
    ~config:edge_meter_config
    (edge_meter ~period:16)
;;

let%expect_test "what the directed firmwares and the random programs never issue" =
  let coverage = Coverage.create () in
  directed coverage;
  Lockstep.random_programs ~coverage ~programs:16 ~cycles:200 (fun random ~config ->
    Random_program.program random ~config);
  Coverage.print_holes coverage;
  [%expect
    {|
    ((programs 16) (failed ()))
    jmp       19 of  23
        tx_not_empty: untaken
        tx_empty: taken
        rx_not_full: untaken
        rx_full: taken
    wait      14 of  16
        fifo rx: held released
    in         8 of   8
    out        8 of   8
    mov       53 of 192
        pins copy: pins x y isr osr
        pins invert: x y isr osr now capture
        pins reverse: pins x y null osr now capture
        x copy: x osr now capture
        x invert: pins x y isr osr now capture
        x reverse: pins x y null isr osr capture
        y copy: pins now
        y invert: pins x y null osr now capture
        y reverse: pins x y null osr now capture
        pindirs copy: pins x y null osr now capture
        pindirs invert: pins x null isr osr now capture
        pindirs reverse: pins x null isr osr now capture
        isr copy: pins y isr osr now capture
        isr invert: pins y isr capture
        isr reverse: all
        osr copy: pins y null osr now capture
        osr invert: pins y osr now capture
        osr reverse: pins x y osr capture
        p copy: pins x y isr now capture
        p invert: x y null isr osr now capture
        p reverse: y null isr capture
        t copy: x isr osr
        t invert: x null now capture
        t reverse: all
    set        5 of   5
    alu       27 of  72
        x add: y p isr osr
        x sub: x y osr
        x xor: x y p
        y add: x isr osr
        y sub: x y p isr osr
        y xor: x y p isr osr
        p add: y p isr
        p sub: x y p isr osr
        p xor: x y isr osr
        t add: x isr osr
        t sub: y p osr
        t xor: x p isr osr
    sys        7 of   8
        halt
    delay      7 of   7
    side-set   7 of   7
    never, by construction:
        jmp always untaken
    |}]
;;
