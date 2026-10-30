open! Core
open Protocol_emulator

let certify (c : Certified.t) =
  let program = Asm.assemble c.source |> ok_exn in
  let config = Asm.Program.configure program c.config in
  let words = Asm.Program.words program |> ok_exn in
  let single_capture_edge = c.single_capture_edge in
  let verdict =
    Analyser.check ?period:c.period ~single_capture_edge ~config program |> ok_exn
  in
  let table =
    Analyser.analyse ?period:c.period ~single_capture_edge ~config program.instructions
    |> Kernel.Table.of_analyser
  in
  let kernel =
    match Kernel.check ?period:c.period ~single_capture_edge ~config ~words table with
    | Ok () -> "the kernel accepts it"
    | Error _ -> "the kernel REFUSES it"
  in
  let assumes =
    List.filter_opt
      [ Option.map c.period ~f:(sprintf "period %d")
      ; Option.map c.period_floor ~f:(sprintf "a load of %d or more")
      ; Option.some_if c.single_capture_edge "one edge before capture"
      ; Option.some_if c.no_wrap "no wrap"
      ]
  in
  printf
    "%s: %s, %s, assuming %s\n"
    c.name
    (Analyser.Verdict.to_string verdict)
    kernel
    (if List.is_empty assumes then "nothing" else String.concat ~sep:", " assumes)
;;

(* Everything a protocol's file gives, from its record alone, in the order a new protocol
   goes through it: each firmware's certificate, which CI then proves by induction
   ([make -C formal inductive_certificate NAME=...]); the bench copies against their
   datasheet limits; each run at the pins in lockstep at the engine; and what sigrok's
   decoders have to read off its trace, which demo/decode.py checks. *)
let end_to_end (p : Protocol.t) =
  (match p.certified @ p.time_triggered with
   | [] -> print_endline "certificates: none"
   | certified ->
     print_endline "certificates";
     List.iter certified ~f:certify);
  print_endline "\nlimits";
  List.iter (p.bench @ p.loaded_from_hex) ~f:(fun bench ->
    match List.Assoc.find p.unlimited bench.name ~equal:String.equal with
    | Some why -> printf "%s: none, %s\n" bench.name why
    | None ->
      (match Datasheet.check p.limits bench with
       | [] -> printf "%s: no limits, and no reason why\n" bench.name
       | verdicts -> print_endline (Datasheet.to_string bench verdicts)));
  let run ~dir (scenario : Pin_trace.Scenario.t) =
    printf
      "\nlockstep: %s, %s\n"
      scenario.name
      (match Protocol.firmware p scenario with
       | Some c -> c.name
       | None -> "uncertified as loaded");
    let received = Protocol.lockstep scenario in
    print_s [%message (received : Int.Hex.t list)];
    (* what the host reads from rx through the whole chip on the scenario's trace, the
       order the engine received it in, or less *)
    let (_ : Pin_trace.Line.t list), reads = Pin_trace.run scenario in
    let read =
      List.filter_map scenario.script ~f:(fun (step : Pin_trace.Step.t) ->
        match step with
        | Read (register, (_ : int)) -> Some register
        | Write _ | Run _ | Until _ | Drive _ | Certify _ -> None)
      |> List.zip_exn reads
      |> List.concat_map ~f:(fun (words, register) ->
        if register = Host_port.Reg.rx then words else [])
    in
    if not (List.is_prefix received ~prefix:read ~equal:Int.equal)
    then
      raise_s
        [%message
          "the chip's host read other words than the engine received"
            scenario.name
            (read : Int.Hex.t list)
            (received : Int.Hex.t list)];
    Option.iter scenario.sigrok ~f:(fun sigrok ->
      printf "decode: %s/%s.trace, by sigrok's" dir scenario.name;
      List.iter sigrok.decoders ~f:(printf " %s");
      print_endline "";
      List.iter sigrok.expect ~f:(fun (annotations, lines) ->
        printf "  %s: %s\n" annotations (String.concat ~sep:", " lines)))
  in
  List.iter p.scenarios ~f:(run ~dir:"test/traces");
  List.iter p.decoded ~f:(run ~dir:"test/traces/sigrok")
;;

(* A protocol added as a file of its own shows up here with nothing else to write. *)
let%expect_test "every protocol from its file to the decoded trace" =
  List.iter Library.protocols ~f:(fun p ->
    printf "=== %s\n\n" p.name;
    end_to_end p;
    print_endline "");
  [%expect
    {|
    === uart

    certificates
    uart_tx: 15 words, 3 deadline waits, worst slack 4, the kernel accepts it, assuming nothing
    uart_tx16: 15 words, 3 deadline waits, worst slack 12, the kernel accepts it, assuming nothing
    uart_tx_host_rate: 17 words, 3 deadline waits, worst slack 430, the kernel accepts it, assuming period 434, a load of 4 or more, no wrap
    uart_rx: 19 words, 2 deadline waits, worst slack 7, the kernel accepts it, assuming one edge before capture, no wrap
    uart_rx_host_rate: 22 words, 2 deadline waits, worst slack 409, the kernel accepts it, assuming period 208, a load of 4 or more, one edge before capture, no wrap
    uart_tx_stream: 13 words, 3 deadline waits, worst slack 4, the kernel accepts it, assuming nothing

    limits
    uart_tx_9600       bit            >=   102083 ns  kernel 5000 (104166.7 ns) needs 4901       UART at 9600 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_9600       bit            <=   106250 ns  run    5000 (104166.7 ns) needs 5099       UART at 9600 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_19200      bit            >=  51041.7 ns  kernel 2500 (52083.3 ns) needs 2452       UART at 19200 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_19200      bit            <=    53125 ns  run    2500 (52083.3 ns) needs 2549       UART at 19200 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_38400      bit            >=  25520.8 ns  kernel 1250 (26041.7 ns) needs 1226       UART at 38400 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_38400      bit            <=  26562.5 ns  run    1250 (26041.7 ns) needs 1274       UART at 38400 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_57600      bit            >=  17013.9 ns  kernel 833 (17354.2 ns)  needs  818       UART at 57600 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_57600      bit            <=  17708.3 ns  run    833 (17354.2 ns)  needs  848       UART at 57600 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_115200     bit            >=  8506.94 ns  kernel 417 (8687.5 ns)   needs  410       UART at 115200 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_115200     bit            <=  8854.17 ns  run    417 (8687.5 ns)   needs  424       UART at 115200 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_230400     bit            >=  4253.47 ns  kernel 208 (4333.3 ns)   needs  206       UART at 230400 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_tx_230400     bit            <=  4427.08 ns  run    208 (4333.3 ns)   needs  211       UART at 230400 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_log           bit            >=  8506.94 ns  kernel 417 (8687.5 ns)   needs  410       UART at 115200 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_log           bit            <=  8854.17 ns  run    417 (8687.5 ns)   needs  424       UART at 115200 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle

    lockstep: uart_tx, uart_tx16
    ("lockstep held" (cycles 400))
    (received ())
    decode: test/traces/uart_tx.trace, by sigrok's uart:tx=OUT0:baudrate=3000000
      uart=tx-data: uart-1: 55, uart-1: A3

    lockstep: uart_rx, uart_rx
    ("lockstep held" (cycles 1288))
    (received (0x55 0xa3 0xff 0x0 0xf 0xf0 0x5a))
    decode: test/traces/uart_rx.trace, by sigrok's uart:rx=IN0:baudrate=3000000
      uart=rx-data: uart-1: 55, uart-1: A3, uart-1: FF, uart-1: 00, uart-1: 0F, uart-1: F0, uart-1: 5A

    === spi

    certificates
    spi_master: 16 words, 3 deadline waits, worst slack 4, the kernel accepts it, assuming nothing
    spi_slave: 6 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_master_stream: 10 words, 3 deadline waits, worst slack 4, the kernel accepts it, assuming nothing

    limits

    lockstep: spi_master, spi_master
    ("lockstep held" (cycles 600))
    (received (0x81 0x7e 0x42))
    decode: test/traces/spi_master.trace, by sigrok's spi:clk=OUT1:mosi=OUT0:miso=IN0
      spi=mosi-data: spi-1: A5, spi-1: 3C, spi-1: 0F
      spi=miso-data: spi-1: 81, spi-1: 7E, spi-1: 42

    === i2c

    certificates
    i2c_master: 99 words, 31 deadline waits, worst slack 5, the kernel accepts it, assuming no wrap
    i2c_slave: 72 words, 0 deadline waits, the kernel accepts it, assuming nothing
    i2c_logger: 73 words, 25 deadline waits, worst slack 1, the kernel accepts it, assuming nothing
    i2c_master_standard: 113 words, 43 deadline waits, worst slack 113, the kernel accepts it, assuming period 121, a load of 8 or more, no wrap
    i2c_master_fast: 107 words, 37 deadline waits, worst slack 24, the kernel accepts it, assuming period 32, a load of 8 or more, no wrap
    i2c_controller_wire: 87 words, 25 deadline waits, worst slack 113, the kernel accepts it, assuming period 121, a load of 8 or more, no wrap
    i2c_target_wire: 78 words, 0 deadline waits, the kernel accepts it, assuming nothing

    limits
    i2c_master         THIGH          >=      600 ns  kernel 96 (2000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 2; margin 300 ns, TR, param 4
    i2c_master         TLOW           >=     1300 ns  kernel 96 (2000.0 ns)    needs   64       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 3; margin a cycle
    i2c_master         THD:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   30       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 6; margin a cycle
    i2c_master         TSU:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 7; margin 300 ns, TR, param 4
    i2c_master         TSU:DAT        >=      100 ns  kernel 47 (979.2 ns)     needs   20       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 9; margin 300 ns, TR, param 4
    i2c_master         TSU:STO        >=      600 ns  kernel 48 (1000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 10; margin 300 ns, TR, param 4
    i2c_master         TBUF           >=     1300 ns  kernel 149 (3104.2 ns)   needs   77       24LC256, Microchip DS20001203W, Table 1-2 p.5, param 14; margin 300 ns, TR, param 4
    i2c_master_stretch THIGH          >=      600 ns  kernel 96 (2000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 2; margin 300 ns, TR, param 4
    i2c_master_stretch TLOW           >=     1300 ns  kernel 96 (2000.0 ns)    needs   64       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 3; margin a cycle
    i2c_master_stretch THD:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   30       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 6; margin a cycle
    i2c_master_stretch TSU:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 7; margin 300 ns, TR, param 4
    i2c_master_stretch TSU:DAT        >=      100 ns  kernel 47 (979.2 ns)     needs   20       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 9; margin 300 ns, TR, param 4
    i2c_master_stretch TSU:STO        >=      600 ns  kernel 48 (1000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 10; margin 300 ns, TR, param 4
    i2c_master_stretch TBUF           >=     1300 ns  kernel 105 (2187.5 ns)   needs   77       24LC256, Microchip DS20001203W, Table 1-2 p.5, param 14; margin 300 ns, TR, param 4
    start_hold: none, it drives no pin: it listens to Pico B's I2C
    i2c_standard       THIGH          >=     4000 ns  kernel 242 (5041.7 ns)   needs  240       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 1000 ns, tr
    i2c_standard       TLOW           >=     4700 ns  kernel 242 (5041.7 ns)   needs  227       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin a cycle
    i2c_standard       THD:STA        >=     4000 ns  kernel 362 (7541.7 ns)   needs  193       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin a cycle
    i2c_standard       TSU:STA        >=     4700 ns  kernel 363 (7562.5 ns)   needs  274       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 1000 ns, tr
    i2c_standard       TSU:DAT        >=      250 ns  kernel 120 (2500.0 ns)   needs   60       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 1000 ns, tr
    i2c_standard       TSU:STO        >=     4000 ns  kernel 363 (7562.5 ns)   needs  240       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 1000 ns, tr
    i2c_standard       TBUF           >=     4700 ns  kernel 368 (7666.7 ns)   needs  274       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 1000 ns, tr
    i2c_standard       1/fSCL         >=    10000 ns  run    484 (10083.3 ns)  needs  481       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44, fSCL; margin a cycle
    i2c_fast           THIGH          >=      600 ns  kernel 64 (1333.3 ns)    needs   44       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 300 ns, tr
    i2c_fast           TLOW           >=     1300 ns  kernel 64 (1333.3 ns)    needs   64       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin a cycle
    i2c_fast           THD:STA        >=      600 ns  kernel 64 (1333.3 ns)    needs   30       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin a cycle
    i2c_fast           TSU:STA        >=      600 ns  kernel 64 (1333.3 ns)    needs   44       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 300 ns, tr
    i2c_fast           TSU:DAT        >=      100 ns  kernel 31 (645.8 ns)     needs   20       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 300 ns, tr
    i2c_fast           TSU:STO        >=      600 ns  kernel 64 (1333.3 ns)    needs   44       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 300 ns, tr
    i2c_fast           TBUF           >=     1300 ns  kernel 101 (2104.2 ns)   needs   77       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 300 ns, tr
    i2c_fast           1/fSCL         >=     2500 ns  run    128 (2666.7 ns)   needs  121       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44, fSCL; margin a cycle

    lockstep: i2c_logger, i2c_logger
    ("lockstep held" (cycles 3000))
    (received ())
    decode: test/traces/i2c_logger.trace, by sigrok's i2c:scl=IO1:sda=IO0 uart:tx=OUT0:baudrate=3000000
      i2c=start:address-read:ack:data-read:nack:stop: i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 10, i2c-1: NACK, i2c-1: Stop, i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 21, i2c-1: NACK, i2c-1: Stop, i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 32, i2c-1: NACK, i2c-1: Stop, i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 43, i2c-1: NACK, i2c-1: Stop
      uart=tx-data: uart-1: 10, uart-1: 21, uart-1: 32, uart-1: 43

    === usb

    certificates
    usb_tx: 65 words, 11 deadline waits, worst slack 16, the kernel accepts it, assuming period 32
    usb_rx: 92 words, 4 deadline waits, worst slack 5, the kernel accepts it, assuming period 32, one edge before capture, no wrap
    usb_device: 470 words, 54 deadline waits, worst slack 6, the kernel accepts it, assuming period 32, one edge before capture, no wrap

    limits

    lockstep: usb, usb_device
    ("lockstep held" (cycles 344800))
    (received (0x1 0x160 0x80 0x0 0x1000 0xd729 0x0 0x3 0x2 0x0 0x0 0x3))
    decode: test/traces/sigrok/usb.trace, by sigrok's usb_signalling:dp=IO0:dm=IO1:signalling=low-speed,usb_packet:signalling=low-speed,usb_request
      usb_packet=packet-out:packet-in:packet-sof:packet-setup:packet-data0:packet-data1:packet-data2:packet-mdata:packet-ack:packet-nak:packet-stall:packet-nyet:packet-pre:packet-err:packet-split:packet-ping:packet-reserved:packet-invalid: usb_packet-1: SETUP ADDR 0 EP 0, usb_packet-1: DATA0 [ 80 06 00 01 00 00 08 00 ], usb_packet-1: ACK, usb_packet-1: IN ADDR 0 EP 0, usb_packet-1: DATA1 [ 12 01 10 01 00 00 00 08 ], usb_packet-1: ACK, usb_packet-1: OUT ADDR 0 EP 0, usb_packet-1: DATA1 [ ], usb_packet-1: ACK, usb_packet-1: IN ADDR 0 EP 1, usb_packet-1: DATA0 [ 02 00 FF FF ], usb_packet-1: ACK, usb_packet-1: IN ADDR 0 EP 1, usb_packet-1: NAK
      usb_request: usb_request-1: SETUP in: [ 80 06 00 01 00 00 08 00 ][ 12 01 10 01 00 00 00 08 ] : ACK, usb_request-1: BULK in: [ 02 00 FF FF ] : ACK

    === edge_meter

    certificates
    edge_meter: 12 words, 2 deadline waits, worst slack 6, the kernel accepts it, assuming nothing

    limits

    === ws2812

    certificates
    ws2812: 32 words, 4 deadline waits, worst slack 0, the kernel accepts it, assuming no wrap
    ws2812_standard: 32 words, 4 deadline waits, worst slack 9, the kernel accepts it, assuming no wrap

    limits
    sk6812             T0H            >=      250 ns  kernel 17 (354.2 ns)     needs   13       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T0H            <=      400 ns  run    17 (354.2 ns)     needs   18       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T1H            >=      650 ns  run    34 (708.3 ns)     needs   33       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T1H            <=     1000 ns  run    34 (708.3 ns)     needs   47       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T0L            >=      800 ns  run    42 (875.0 ns)     needs   40       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T1L            >=      200 ns  kernel 25 (520.8 ns)     needs   11       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T              >=     1200 ns  run    59 (1229.2 ns)    needs   59       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7, note 2; margin a cycle
    sk6812             reset          >=   200000 ns  run    10907 (227229.2 ns) needs 9601       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle

    lockstep: ws2812, ws2812_standard
    ("lockstep held" (cycles 17840))
    (received ())
    decode: test/traces/sigrok/ws2812.trace, by sigrok's rgb_led_ws281x:din=OUT0
      rgb_led_ws281x=rgb:reset: rgb_led_ws281x-1: #ff0000, rgb_led_ws281x-1: #00ff00, rgb_led_ws281x-1: #0000ff, rgb_led_ws281x-1: RESET, rgb_led_ws281x-1: #123456, rgb_led_ws281x-1: #abcdef, rgb_led_ws281x-1: RESET

    === ethernet

    certificates
    ethernet: 38 words, 1 deadline wait, worst slack 63987, the kernel accepts it, assuming period 64000, no wrap

    limits
    ethernet: none, no demo on the bench: it needs the Icepi's 40 MHz build

    === one_wire

    certificates
    one_wire: 48 words, 15 deadline waits, worst slack 295, the kernel accepts it, assuming period 300, a load of 5 or more

    limits
    one_wire           tLOW1          >=     1000 ns  kernel 288 (6000.0 ns)   needs   49       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tLOW1          <=    15000 ns  run    288 (6000.0 ns)   needs  719       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tLOW0          >=    60000 ns  run    3168 (66000.0 ns) needs 2881       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tLOW0          <=   120000 ns  run    3168 (66000.0 ns) needs 5759       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tREC           >=     1000 ns  kernel 288 (6000.0 ns)   needs   49       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tSLOT + tREC   >=    61000 ns  run    3456 (72000.0 ns) needs 2929       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tRSTL          >=   480000 ns  run    24194 (504041.7 ns) needs 23041       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tRSTH          >=   480000 ns  run    23336 (486166.7 ns) needs 23041       DS18B20, Maxim REV 042208 p.20; margin a cycle

    lockstep: one_wire, one_wire
    ("lockstep held" (cycles 310200))
    (received (0x0 0x33 0x28 0xab 0x89 0x67 0x45 0x23 0x1 0x5a))
    decode: test/traces/sigrok/one_wire.trace, by sigrok's onewire_link:owr=IO0,onewire_network
      onewire_link=reset:presence: onewire_link-1: Reset, onewire_link-1: Presence: true
      onewire_network: onewire_network-1: Reset/presence: true, onewire_network-1: ROM command: 0x33 'Read ROM', onewire_network-1: ROM: 0x5a0123456789ab28

    === ps2

    certificates
    ps2: 65 words, 12 deadline waits, worst slack 992, the kernel accepts it, assuming period 1000, a load of 8 or more

    limits
    ps2                data to CLK fall >=     5000 ns  kernel 957 (19937.5 ns)  needs  241       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T1; margin a cycle
    ps2                CLK rise to data >=     5000 ns  kernel 960 (20000.0 ns)  needs  241       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T2; margin a cycle
    ps2                CLK low        >=    30000 ns  kernel 1920 (40000.0 ns) needs 1441       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T3; margin a cycle
    ps2                CLK low        <=    50000 ns  run    1920 (40000.0 ns) needs 2399       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T3; margin a cycle
    ps2                CLK high       >=    30000 ns  run    1920 (40000.0 ns) needs 1441       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T4; margin a cycle
    ps2                CLK high       <=    50000 ns  run    1920 (40000.0 ns) needs 2399       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T4; margin a cycle

    lockstep: ps2, ps2
    ("lockstep held" (cycles 174000))
    (received ())
    decode: test/traces/sigrok/ps2.trace, by sigrok's ps2:clk=IO1:data=IO0
      ps2=start-bit:word:parity-ok:stop-bit: ps2-1: Start bit, ps2-1: Data: 1c, ps2-1: Parity OK, ps2-1: Stop bit, ps2-1: Start bit, ps2-1: Data: f0, ps2-1: Parity OK, ps2-1: Stop bit, ps2-1: Start bit, ps2-1: Data: 1c, ps2-1: Parity OK, ps2-1: Stop bit
      ps2=bit: ps2-1: 0, ps2-1: 0, ps2-1: 0, ps2-1: 1, ps2-1: 1, ps2-1: 1, ps2-1: 0, ps2-1: 0, ps2-1: 0, ps2-1: 0, ps2-1: 1, ps2-1: 0, ps2-1: 0, ps2-1: 0, ps2-1: 0, ps2-1: 0, ps2-1: 1, ps2-1: 1, ps2-1: 1, ps2-1: 1, ps2-1: 1, ps2-1: 1, ps2-1: 0, ps2-1: 0, ps2-1: 0, ps2-1: 1, ps2-1: 1, ps2-1: 1, ps2-1: 0, ps2-1: 0, ps2-1: 0, ps2-1: 0, ps2-1: 1

    === jtag

    certificates
    jtag: 15 words, 3 deadline waits, worst slack 0, the kernel accepts it, assuming nothing

    limits

    lockstep: jtag, jtag
    ("lockstep held" (cycles 1240))
    (received (0x0 0xee00 0x800 0x4000 0x9700 0x8000 0x0 0x0 0xa000 0x1400))
    decode: test/traces/sigrok/jtag.trace, by sigrok's jtag:tdi=OUT1:tdo=IN0:tck=OUT0:tms=OUT2
      jtag=bitstring-tdi: jtag-1: DR TDI: 00000000000000000000000000000000 (0x0), 32 bits, jtag-1: IR TDI: 0010 (0x2), 4 bits, jtag-1: DR TDI: 10100101 (0xa5), 8 bits, jtag-1: DR TDI: 00111100 (0x3c), 8 bits
      jtag=bitstring-tdo: jtag-1: DR TDO: 01001011101000000000010001110111 (0x4ba00477), 32 bits, jtag-1: IR TDO: 0001 (0x1), 4 bits, jtag-1: DR TDO: 00000000 (0x0), 8 bits, jtag-1: DR TDO: 10100101 (0xa5), 8 bits

    === can

    certificates
    can: 56 words, 10 deadline waits, worst slack 81, the kernel accepts it, assuming period 96, a load of 15 or more, no wrap

    limits
    can                recessive      >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can                dominant       >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can                idle to SOF    >=    22000 ns  run    1165 (24270.8 ns) needs 1057       CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits; margin a cycle
    can_sender         recessive      >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can_sender         dominant       >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can_sender         idle to SOF    >=    22000 ns  run    1165 (24270.8 ns) needs 1057       CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits; margin a cycle
    can_receiver       ACK            >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle

    lockstep: can, can
    ("lockstep held" (cycles 23808))
    (received ())
    decode: test/traces/sigrok/can.trace, by sigrok's can:can_rx=OUT1:nominal_bitrate=500000
      can=sof:id:ide:rtr:dlc:data:crc-sequence:ack-slot:eof: can-1: Start of frame, can-1: Identifier: 291 (0x123), can-1: Identifier extension bit: standard frame, can-1: Remote transmission request: data frame, can-1: Data length code: 2, can-1: Data byte 0: 0xde, can-1: Data byte 1: 0xad, can-1: CRC-15 sequence: 0x0b6e, can-1: ACK slot: NACK, can-1: End of frame, can-1: Start of frame, can-1: Identifier: 1365 (0x555), can-1: Identifier extension bit: standard frame, can-1: Remote transmission request: data frame, can-1: Data length code: 8, can-1: Data byte 0: 0x00, can-1: Data byte 1: 0xff, can-1: Data byte 2: 0x55, can-1: Data byte 3: 0xaa, can-1: Data byte 4: 0x01, can-1: Data byte 5: 0x80, can-1: Data byte 6: 0x7f, can-1: Data byte 7: 0xfe, can-1: CRC-15 sequence: 0x7480, can-1: ACK slot: NACK, can-1: End of frame, can-1: Start of frame, can-1: Identifier: 0 (0x0), can-1: Identifier extension bit: standard frame, can-1: Remote transmission request: data frame, can-1: Data length code: 0, can-1: CRC-15 sequence: 0x0000, can-1: ACK slot: NACK, can-1: End of frame

    lockstep: can_remote, can
    ("lockstep held" (cycles 11808))
    (received ())
    decode: test/traces/sigrok/can_remote.trace, by sigrok's can:can_rx=OUT1:nominal_bitrate=500000
      can=sof:id:ide:rtr:dlc:data:crc-sequence:ack-slot:eof: can-1: Start of frame, can-1: Identifier: 240 (0xf0), can-1: Identifier extension bit: standard frame, can-1: Remote transmission request: remote frame, can-1: Data length code: 4, can-1: CRC-15 sequence: 0x1459, can-1: ACK slot: NACK, can-1: End of frame, can-1: Start of frame, can-1: Identifier: 291 (0x123), can-1: Identifier extension bit: standard frame, can-1: Remote transmission request: data frame, can-1: Data length code: 2, can-1: Data byte 0: 0xde, can-1: Data byte 1: 0xad, can-1: CRC-15 sequence: 0x0b6e, can-1: ACK slot: NACK, can-1: End of frame

    === dshot

    certificates
    dshot600: 21 words, 4 deadline waits, worst slack 14, the kernel accepts it, assuming no wrap

    limits

    === sent

    certificates
    sent: 83 words, 9 deadline waits, worst slack 129, the kernel accepts it, assuming period 150, a load of 21 or more, no wrap

    limits

    === cec

    certificates
    cec: 71 words, 20 deadline waits, worst slack 2493, the kernel accepts it, assuming period 2500, a load of 7 or more, no wrap

    limits
    cec                start low      >=  3.5e+06 ns  run    177600 (3700000.0 ns) needs 168001       HDMI-CEC, HDMI Specification 1.3a, Supplement 1 CEC CEC 5.2.1, CEC Figure 3, p. CEC-8; margin a cycle
    cec                start low      <=  3.9e+06 ns  run    177600 (3700000.0 ns) needs 187199       HDMI-CEC, HDMI Specification 1.3a, Supplement 1 CEC CEC 5.2.1, CEC Figure 3, p. CEC-8; margin a cycle
    cec                start bit      >=  4.3e+06 ns  run    216000 (4500000.0 ns) needs 206401       HDMI-CEC, HDMI Specification 1.3a, Supplement 1 CEC CEC 5.2.1, CEC Figure 3, p. CEC-8; margin a cycle
    cec                start bit      <=  4.7e+06 ns  run    216000 (4500000.0 ns) needs 225599       HDMI-CEC, HDMI Specification 1.3a, Supplement 1 CEC CEC 5.2.1, CEC Figure 3, p. CEC-8; margin a cycle
    cec                one low, T1    >=   400000 ns  run    28800 (600000.0 ns) needs 19201       HDMI-CEC, HDMI Specification 1.3a, Supplement 1 CEC CEC 5.2.2, CEC Figure 4, p. CEC-9; margin a cycle
    cec                one low, T2    <=   800000 ns  run    28800 (600000.0 ns) needs 38399       HDMI-CEC, HDMI Specification 1.3a, Supplement 1 CEC CEC 5.2.2, CEC Figure 4, p. CEC-9; margin a cycle
    cec                zero low, T5   >=  1.3e+06 ns  run    72000 (1500000.0 ns) needs 62401       HDMI-CEC, HDMI Specification 1.3a, Supplement 1 CEC CEC 5.2.2, CEC Figure 4, p. CEC-9; margin a cycle
    cec                zero low, T6   <=  1.7e+06 ns  run    72000 (1500000.0 ns) needs 81599       HDMI-CEC, HDMI Specification 1.3a, Supplement 1 CEC CEC 5.2.2, CEC Figure 4, p. CEC-9; margin a cycle
    cec                bit, T7        >= 2.05e+06 ns  run    115200 (2400000.0 ns) needs 98401       HDMI-CEC, HDMI Specification 1.3a, Supplement 1 CEC CEC 5.2.2, CEC Figure 4, p. CEC-9; margin a cycle
    cec                bit, T8        <= 2.75e+06 ns  run    115200 (2400000.0 ns) needs 131999       HDMI-CEC, HDMI Specification 1.3a, Supplement 1 CEC CEC 5.2.2, CEC Figure 4, p. CEC-9; margin a cycle

    lockstep: cec, cec
    ("lockstep held" (cycles 163600))
    (received (0x0 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0x1 0x1))
    decode: test/traces/sigrok/cec.trace, by sigrok's cec:cec=IO0
      cec=frames: cec-1: 40, cec-1: 40:04, cec-1: 40:47:43:45:43, cec-1: 4f:36
      cec=ack:nack: cec-1: ACK, cec-1: ACK, cec-1: ACK, cec-1: ACK, cec-1: ACK, cec-1: ACK, cec-1: ACK, cec-1: ACK, cec-1: ACK, cec-1: ACK

    === spi_cs

    certificates
    spi_cs_mode0: 43 words, 6 deadline waits, worst slack 1, the kernel accepts it, assuming no wrap
    spi_cs_mode1: 43 words, 6 deadline waits, worst slack 1, the kernel accepts it, assuming no wrap
    spi_cs_mode2: 43 words, 6 deadline waits, worst slack 1, the kernel accepts it, assuming no wrap
    spi_cs_mode3: 43 words, 6 deadline waits, worst slack 1, the kernel accepts it, assuming no wrap
    spi_cs_mode0_default_pins: 43 words, 6 deadline waits, worst slack 1, the kernel accepts it, assuming no wrap
    spi_cs_mode1_default_pins: 43 words, 6 deadline waits, worst slack 1, the kernel accepts it, assuming no wrap
    spi_cs_mode2_default_pins: 43 words, 6 deadline waits, worst slack 1, the kernel accepts it, assuming no wrap
    spi_cs_mode3_default_pins: 43 words, 6 deadline waits, worst slack 1, the kernel accepts it, assuming no wrap

    limits
    spi_cs_mode0       tCLH           >=        9 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode0       tCLL           >=        9 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode0       tSLCH          >=        3 ns  kernel 4 (83.3 ns)       needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode0       tCHSH          >=        3 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode0       tSHSL2         >=       50 ns  kernel 154 (3208.3 ns)   needs    4       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode0       tRES1          >=     3000 ns  kernel 154 (3208.3 ns)   needs  145       W25Q64JV, Winbond Rev. M p.65; margin a cycle
    spi_cs_mode1       tCLH           >=        9 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode1       tCLL           >=        9 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode1       tSLCH          >=        3 ns  kernel 4 (83.3 ns)       needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode1       tCHSH          >=        3 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode1       tSHSL2         >=       50 ns  kernel 154 (3208.3 ns)   needs    4       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode1       tRES1          >=     3000 ns  kernel 154 (3208.3 ns)   needs  145       W25Q64JV, Winbond Rev. M p.65; margin a cycle
    spi_cs_mode2       tCLH           >=        9 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode2       tCLL           >=        9 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode2       tSLCH          >=        3 ns  kernel 4 (83.3 ns)       needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode2       tCHSH          >=        3 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode2       tSHSL2         >=       50 ns  kernel 154 (3208.3 ns)   needs    4       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode2       tRES1          >=     3000 ns  kernel 154 (3208.3 ns)   needs  145       W25Q64JV, Winbond Rev. M p.65; margin a cycle
    spi_cs_mode3       tCLH           >=        9 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode3       tCLL           >=        9 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode3       tSLCH          >=        3 ns  kernel 4 (83.3 ns)       needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode3       tCHSH          >=        3 ns  kernel 8 (166.7 ns)      needs    2       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode3       tSHSL2         >=       50 ns  kernel 154 (3208.3 ns)   needs    4       W25Q64JV, Winbond Rev. M p.64; margin a cycle
    spi_cs_mode3       tRES1          >=     3000 ns  kernel 154 (3208.3 ns)   needs  145       W25Q64JV, Winbond Rev. M p.65; margin a cycle

    lockstep: spi_mode0, spi_cs_mode0
    ("lockstep held" (cycles 1920))
    (received (0x5a 0x60 0xff 0xff 0x5a 0x5a 0xc3))
    decode: test/traces/sigrok/spi_mode0.trace, by sigrok's spi:cs=OUT6:clk=OUT5:mosi=OUT4:miso=IN0:cpol=0:cpha=0
      spi=mosi-transfer: spi-1: 9F 00 00 00, spi-1: A5, spi-1: 3C C3
      spi=miso-transfer: spi-1: 5A 60 FF FF, spi-1: 5A, spi-1: 5A C3

    lockstep: spi_mode1, spi_cs_mode1
    ("lockstep held" (cycles 1920))
    (received (0x5a 0x60 0xff 0xff 0x5a 0x5a 0xc3))
    decode: test/traces/sigrok/spi_mode1.trace, by sigrok's spi:cs=OUT6:clk=OUT5:mosi=OUT4:miso=IN0:cpol=0:cpha=1
      spi=mosi-transfer: spi-1: 9F 00 00 00, spi-1: A5, spi-1: 3C C3
      spi=miso-transfer: spi-1: 5A 60 FF FF, spi-1: 5A, spi-1: 5A C3

    lockstep: spi_mode2, spi_cs_mode2
    ("lockstep held" (cycles 1920))
    (received (0x5a 0x60 0xff 0xff 0x5a 0x5a 0xc3))
    decode: test/traces/sigrok/spi_mode2.trace, by sigrok's spi:cs=OUT6:clk=OUT5:mosi=OUT4:miso=IN0:cpol=1:cpha=0
      spi=mosi-transfer: spi-1: 9F 00 00 00, spi-1: A5, spi-1: 3C C3
      spi=miso-transfer: spi-1: 5A 60 FF FF, spi-1: 5A, spi-1: 5A C3

    lockstep: spi_mode3, spi_cs_mode3
    ("lockstep held" (cycles 1920))
    (received (0x5a 0x60 0xff 0xff 0x5a 0x5a 0xc3))
    decode: test/traces/sigrok/spi_mode3.trace, by sigrok's spi:cs=OUT6:clk=OUT5:mosi=OUT4:miso=IN0:cpol=1:cpha=1
      spi=mosi-transfer: spi-1: 9F 00 00 00, spi-1: A5, spi-1: 3C C3
      spi=miso-transfer: spi-1: 5A 60 FF FF, spi-1: 5A, spi-1: 5A C3

    === spi_target

    certificates
    spi_target_mode0: 38 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_target_mode1: 33 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_target_mode2: 38 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_target_mode3: 33 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_target_fast_mode0: 36 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_target_fast_mode1: 36 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_target_fast_mode2: 37 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_target_fast_mode3: 37 words, 0 deadline waits, the kernel accepts it, assuming nothing

    limits

    === swd

    certificates
    swd: 232 words, 52 deadline waits, worst slack 15, the kernel accepts it, assuming period 25, a load of 10 or more, no wrap

    limits
    swd                SWCLK high     >=  20.8333 ns  kernel 7 (145.8 ns)      needs    2       RP2040, RP2040 datasheet, 2025-02-20 s.2.3.4 p.61; margin a cycle
    swd                SWCLK low      >=  20.8333 ns  kernel 24 (500.0 ns)     needs    2       RP2040, RP2040 datasheet, 2025-02-20 s.2.3.4 p.61; margin a cycle

    lockstep: swd, swd
    ("lockstep held" (cycles 54000))
    (received
     (0x1 0x7 0x2477 0xbc1 0x1 0x1 0x1 0x0 0xf000 0x1 0x1 0x0 0x0 0x1 0x0 0x0 0x2
      0x31 0x477 0x1 0x1))
    decode: test/traces/sigrok/swd.trace, by sigrok's swd:swclk=OUT2:swdio=IO5
      swd=read:write:ack:data: swd-1: IDCODE, swd-1: OK, swd-1: 0x0bc12477, swd-1: W ABORT, swd-1: OK, swd-1: 0x0000001c, swd-1: W CTRL/STAT, swd-1: OK, swd-1: 0x50000000, swd-1: R CTRL/STAT, swd-1: OK, swd-1: 0xf0000000, swd-1: W SELECT, swd-1: OK, swd-1: 0x000000f0, swd-1: R APc, swd-1: OK, swd-1: 0x00000000, swd-1: RDBUFF, swd-1: WAIT, swd-1: RDBUFF, swd-1: OK, swd-1: 0x04770031, swd-1: W SELECT, swd-1: OK, swd-1: 0x00000000

    === tables

    certificates
    table: 112 words, 2 deadline waits, worst slack 0, the kernel accepts it, assuming nothing
    table_open_drain: 112 words, 2 deadline waits, worst slack 0, the kernel accepts it, assuming nothing

    limits

    === nec

    certificates
    nec_tx: 80 words, 22 deadline waits, worst slack 26989, the kernel accepts it, assuming period 27000, a load of 11 or more, no wrap
    nec_rx: 37 words, 4 deadline waits, worst slack 13493, the kernel accepts it, assuming period 13500, one edge before capture, no wrap

    limits
    nec_tx: none, no datasheet at hand; Nec.decode holds each mark and space to 5%
    nec_rx: none, a receiver: it samples, and drives nothing

    lockstep: nec, nec_tx
    ("lockstep held" (cycles 10408))
    (received ())
    decode: test/traces/sigrok/nec.trace, by sigrok's ir_nec:ir=OUT0
      ir_nec=addr:addr-inv:cmd:cmd-inv: ir_nec-1: Address: 0x04, ir_nec-1: Address#: 0xFB, ir_nec-1: Command: 0x08, ir_nec-1: Command#: 0xF7, ir_nec-1: Address: 0x00, ir_nec-1: Address#: 0xFF, ir_nec-1: Command: 0x45, ir_nec-1: Command#: 0xBA
      ir_nec=repeat-code: ir_nec-1: Repeat code

    === snorble

    certificates
    snorble: 84 words, 5 deadline waits, worst slack 0, the kernel accepts it, assuming no wrap

    limits
    snorble            tSYN           >=     7500 ns  run    384 (8000.0 ns)   needs  361       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tSYN           <=     8500 ns  run    384 (8000.0 ns)   needs  407       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tL0            >=     1100 ns  kernel 58 (1208.3 ns)    needs   54       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tL0            <=     1300 ns  run    58 (1208.3 ns)    needs   61       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tL1            >=     2900 ns  run    144 (3000.0 ns)   needs  141       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tL1            <=     3100 ns  run    144 (3000.0 ns)   needs  147       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tH             >=     1800 ns  kernel 96 (2000.0 ns)    needs   88       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1; margin a cycle
    snorble            tH             <=     4000 ns  run    96 (2000.0 ns)    needs  191       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1, and note 1, p.2: inside a frame; margin a cycle
    snorble            tIFG           >=    20000 ns  run    8566 (178458.3 ns) needs  961       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 4, p.1, and note 3, p.2; margin a cycle
    snorble            frame rate     >=   200000 ns  run    10422 (217125.0 ns) needs 9601       Snorble, SNB-1 Snorble Sensor Beacon Rev. C section 1, p.1: about 5 kframes/s at most; margin a cycle

    lockstep: snorble, snorble
    ("lockstep held" (cycles 55000))
    (received ())
    decode: test/traces/snorble.trace, by sigrok's snorble:sig=OUT0
      snorble=byte:parity-ok: snorble-1: A5, snorble-1: Parity OK, snorble-1: 00, snorble-1: Parity OK, snorble-1: FF, snorble-1: Parity OK, snorble-1: 3C, snorble-1: Parity OK

    === plinkoo

    certificates
    plinkoo: 90 words, 15 deadline waits, worst slack 0, the kernel accepts it, assuming no wrap

    limits

    lockstep: plinkoo, plinkoo
    ("lockstep held" (cycles 28800))
    (received (0x0 0x0))
    decode: test/traces/plinkoo.trace, by sigrok's plinkoo:stb=OUT5:dat=IO3
      plinkoo=length:byte:checksum-ok:ack: plinkoo-1: Length 3, plinkoo-1: 12, plinkoo-1: 34, plinkoo-1: 56, plinkoo-1: Checksum OK, plinkoo-1: ACK, plinkoo-1: Length 8, plinkoo-1: 00, plinkoo-1: FF, plinkoo-1: 80, plinkoo-1: 01, plinkoo-1: A5, plinkoo-1: 5A, plinkoo-1: 7E, plinkoo-1: C3, plinkoo-1: Checksum OK, plinkoo-1: ACK

    === frumbleglide

    certificates: none

    limits

    lockstep: frumbleglide, uncertified as loaded
    ("lockstep held" (cycles 12768))
    (received ())

    === microwire

    certificates
    microwire: 69 words, 7 deadline waits, worst slack 13, the kernel accepts it, assuming nothing

    limits
    microwire          SK clock range >=     1600 ns  run    310 (6458.3 ns)   needs   78       DS8908, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Write data DI setup >=      300 ns  kernel 113 (2354.2 ns)   needs   16       DS8908, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Write data DI hold >=      800 ns  kernel 42 (875.0 ns)     needs   40       DS8908, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Chip enable setup >=      300 ns  kernel 312 (6500.0 ns)   needs   16       DS8908, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Chip enable hold >=      800 ns  kernel 155 (3229.2 ns)   needs   40       DS8908, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          SK clock range >=     2000 ns  run    310 (6458.3 ns)   needs   97       MM545X, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Write data DI setup >=      300 ns  kernel 113 (2354.2 ns)   needs   16       MM545X, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Chip enable setup >=      400 ns  kernel 312 (6500.0 ns)   needs   21       MM545X, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          SK clock range >=     4000 ns  run    310 (6458.3 ns)   needs  193       COP472-3, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          SK clock range <=   250000 ns  run    310 (6458.3 ns)   needs 11999       COP472-3, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Write data DI setup >=     1000 ns  kernel 113 (2354.2 ns)   needs   49       COP472-3, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Write data DI hold >=      100 ns  kernel 42 (875.0 ns)     needs    6       COP472-3, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Chip enable setup >=     1000 ns  kernel 312 (6500.0 ns)   needs   49       COP472-3, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Chip enable hold >=     1000 ns  kernel 155 (3229.2 ns)   needs   49       COP472-3, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          SK clock range >=     5000 ns  run    310 (6458.3 ns)   needs  241       COP430 (ADC83X), National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          SK clock range <=   100000 ns  run    310 (6458.3 ns)   needs 4799       COP430 (ADC83X), National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Write data DI setup >=      200 ns  kernel 113 (2354.2 ns)   needs   11       COP430 (ADC83X), National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Write data DI hold >=      200 ns  kernel 42 (875.0 ns)     needs   11       COP430 (ADC83X), National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Chip enable setup >=      200 ns  kernel 312 (6500.0 ns)   needs   11       COP430 (ADC83X), National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Chip enable hold >=      200 ns  kernel 155 (3229.2 ns)   needs   11       COP430 (ADC83X), National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          SK clock range >=     4000 ns  run    310 (6458.3 ns)   needs  193       NM93C06A, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Write data DI setup >=      400 ns  kernel 113 (2354.2 ns)   needs   21       NM93C06A, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Write data DI hold >=      400 ns  kernel 42 (875.0 ns)     needs   21       NM93C06A, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          Chip enable setup >=      200 ns  kernel 312 (6500.0 ns)   needs   11       NM93C06A, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 Table I, p.5; margin a cycle
    microwire          SK clock frequency >=     4000 ns  run    310 (6458.3 ns)   needs  193       NM93C06A, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 p.6, note 1; margin a cycle
    microwire          SK clock high time >=     1000 ns  kernel 155 (3229.2 ns)   needs   49       NM93C06A, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 p.6, note 1 and Figure 9; margin a cycle
    microwire          instruction cycle time >=     4000 ns  run    310 (6458.3 ns)   needs  193       COP420, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 p.6, note 1: the SK period; margin a cycle
    microwire          instruction cycle time <=    10000 ns  run    310 (6458.3 ns)   needs  479       COP420, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 p.6, note 1: the SK period; margin a cycle
    microwire          CS low period following an E/W instruction >=    1e+07 ns  run    1245217 (25942020.8 ns) needs 480001       NM93C06A, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 p.6, note 2; margin a cycle
    microwire          CS low period following an E/W instruction <=    3e+07 ns  run    1245217 (25942020.8 ns) needs 1439999       NM93C06A, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 p.6, note 2; margin a cycle
    microwire          TWE, VPP width >=    2e+07 ns  run    1245217 (25942020.8 ns) needs 960001       COP494, National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992 p.10, listing line 83; margin a cycle

    lockstep: microwire, microwire
    ("lockstep held" (cycles 22000))
    (received (0x1ff 0x5555 0xffff))
    decode: test/traces/microwire.trace, by sigrok's microwire:cs=OUT6:sk=OUT5:si=OUT4:so=IN0
      microwire=start-bit:si-bit: microwire-1: Start bit, microwire-1: SI bit: 1, microwire-1: SI bit: 1, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 1, microwire-1: Start bit, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 1, microwire-1: SI bit: 0, microwire-1: SI bit: 1, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: Start bit, microwire-1: SI bit: 1, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 1, microwire-1: SI bit: 0, microwire-1: SI bit: 1, microwire-1: SI bit: 1, microwire-1: SI bit: 0, microwire-1: SI bit: 1, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 1, microwire-1: SI bit: 0, microwire-1: SI bit: 1, microwire-1: SI bit: 1, microwire-1: SI bit: 1, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 0, microwire-1: SI bit: 1, microwire-1: SI bit: 1
      microwire=so-bit: microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 0, microwire-1: SO bit: 0, microwire-1: SO bit: 1, microwire-1: SO bit: 0, microwire-1: SO bit: 1, microwire-1: SO bit: 0, microwire-1: SO bit: 1, microwire-1: SO bit: 0, microwire-1: SO bit: 1, microwire-1: SO bit: 0, microwire-1: SO bit: 1, microwire-1: SO bit: 0, microwire-1: SO bit: 1, microwire-1: SO bit: 0, microwire-1: SO bit: 1, microwire-1: SO bit: 0, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1, microwire-1: SO bit: 1

    === ir_rc6

    certificates
    ir_rc6: 64 words, 22 deadline waits, worst slack 21325, the kernel accepts it, assuming period 21333, a load of 14 or more, no wrap

    limits
    ir_rc6: none, the spec gives typical times and no minimum or maximum; Ir_rc6.decode holds each mark and space to 5%

    lockstep: ir_rc6, ir_rc6
    ("lockstep held" (cycles 28800))
    (received ())
    decode: test/traces/sigrok/ir_rc6.trace, by sigrok's ir_rc6:ir=OUT0
      ir_rc6=bit:sync:startbit:field:togglebit:address:command: ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: Synchronisation, ir_rc6-1: Startbit, ir_rc6-1: Field: 0, ir_rc6-1: Toggle: 0, ir_rc6-1: Synchronisation, ir_rc6-1: Startbit, ir_rc6-1: Field: 0, ir_rc6-1: Toggle: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: 0, ir_rc6-1: 1, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: 0, ir_rc6-1: 1, ir_rc6-1: 0, ir_rc6-1: 1, ir_rc6-1: Address: 1A, ir_rc6-1: Data: 35, ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 1, ir_rc6-1: Synchronisation, ir_rc6-1: Startbit, ir_rc6-1: Field: 0, ir_rc6-1: Toggle: 1, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 0, ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: 1, ir_rc6-1: Address: 00, ir_rc6-1: Data: FF

    === caliper

    certificates
    caliper: 57 words, 11 deadline waits, worst slack 263, the kernel accepts it, assuming period 270, a load of 16 or more

    limits
    caliper            clock high at 90 kHz >=   5555.5 ns  kernel 270 (5625.0 ns)   needs  268       Chinese digital scale, Chinese Scales web page, no revision Chinese Scale Protocol, page 1, lines 52-54; margin a cycle
    caliper            clock low at 90 kHz >=   5555.5 ns  kernel 270 (5625.0 ns)   needs  268       Chinese digital scale, Chinese Scales web page, no revision Chinese Scale Protocol, page 1, lines 52-54; margin a cycle
    caliper            pause before the first word >=    55000 ns  run    2705 (56354.2 ns) needs 2641       Chinese digital scale, Chinese Scales web page, no revision Chinese Scale Protocol, page 1, lines 82-84; margin a cycle
    caliper            pause between the words >=   110000 ns  run    5400 (112500.0 ns) needs 5281       Chinese digital scale, Chinese Scales web page, no revision Chinese Scale Protocol, page 1, lines 82-84; margin a cycle
    caliper            pause after the last word >=    55000 ns  run    5408 (112666.7 ns) needs 2641       Chinese digital scale, Chinese Scales web page, no revision Chinese Scale Protocol, page 1, lines 82-84; margin a cycle

    lockstep: caliper, caliper
    ("lockstep held" (cycles 45000))
    (received ())
    decode: test/traces/caliper.trace, by sigrok's caliper:clk=OUT0:data=OUT1
      caliper=measurement: caliper-1: 46.6mm, caliper-1: -16.384in

    === xy2_100

    certificates
    xy2_100: 35 words, 10 deadline waits, worst slack 2, the kernel accepts it, assuming nothing

    limits
    xy2_100            tDS            >=       50 ns  kernel 12 (250.0 ns)     needs    4       rhothor X7, Newson XY2-100 I/O configuration, Rev. 0703 Timing specifications table, p.2; margin a cycle
    xy2_100            tDH            >=      100 ns  kernel 12 (250.0 ns)     needs    6       rhothor X7, Newson XY2-100 I/O configuration, Rev. 0703 Timing specifications table, p.2; margin a cycle

    lockstep: xy2_100, xy2_100
    ("lockstep held" (cycles 2800))
    (received ())
    decode: test/traces/xy2_100.trace, by sigrok's xy2-100:clk=OUT0:sync=OUT1:data=OUT2
      xy2-100=type:parity:position: xy2-100-1: 16 bit Position Frame, xy2-100-1: OK, xy2-100-1: -32768, xy2-100-1: 16 bit Position Frame, xy2-100-1: OK, xy2-100-1: 0, xy2-100-1: 16 bit Position Frame, xy2-100-1: OK, xy2-100-1: -1, xy2-100-1: 16 bit Position Frame, xy2-100-1: OK, xy2-100-1: 4660, xy2-100-1: 16 bit Position Frame, xy2-100-1: OK, xy2-100-1: 4660

    === lfast

    certificates
    lfast: 64 words, 27 deadline waits, worst slack 6, the kernel accepts it, assuming nothing

    limits
    lfast              data rate, shortest high bit (3.125 ns) >=    3.125 ns  kernel 10 (208.3 ns)     needs    2       LFAST, NXP AN5134 Rev. 0 p.3, text: rates up to 320 Mb/s; margin a cycle
    lfast              data rate, shortest low bit (3.125 ns) >=    3.125 ns  kernel 10 (208.3 ns)     needs    2       LFAST, NXP AN5134 Rev. 0 p.3, text: rates up to 320 Mb/s; margin a cycle

    lockstep: lfast, lfast
    ("lockstep held" (cycles 760))
    (received ())
    decode: test/traces/lfast.trace, by sigrok's lfast:data=OUT0
      lfast=sync:header_pl_size:header_ch_type:header_cts:payload:sleep: lfast-1: Sync OK, lfast-1: 8 bit, lfast-1: Data Channel A, lfast-1: 1, lfast-1: 55, lfast-1: LVDS sleep mode request, lfast-1: Sync OK, lfast-1: 8 bit, lfast-1: Data Channel A, lfast-1: 1, lfast-1: A3, lfast-1: LVDS sleep mode request

    === usb_fs

    certificates
    usb_fs_device: 251 words, 5 deadline waits, worst slack 0, the kernel accepts it, assuming no wrap

    limits
    |}]
;;

(* the names the formal jobs, python/bench_firmware.py and test/traces go by *)
let%expect_test "every name in the library is its own" =
  let repeated names = List.find_all_dups names ~compare:String.compare in
  let each f = List.concat_map Library.protocols ~f in
  print_s
    [%message
      ""
        ~certified:
          (repeated
             (List.map
                ((Library.stamped :: Library.certified) @ Library.time_triggered)
                ~f:(fun c -> c.name))
           : string list)
        ~bench:
          (repeated
             (List.map (each (fun p -> p.bench @ p.loaded_from_hex)) ~f:(fun b -> b.name))
           : string list)
        ~scenarios:
          (repeated (List.map (Pin_scenarios.all @ Library.decoded) ~f:(fun s -> s.name))
           : string list)];
  [%expect {| ((certified ()) (bench ()) (scenarios ())) |}]
;;

(* each limit, reason for none and sweep decision names the protocol's own firmware *)
let%expect_test "every protocol speaks only of its own firmware" =
  List.iter Library.protocols ~f:(fun p ->
    let names l = String.Set.of_list l in
    let bench = names (List.map (p.bench @ p.loaded_from_hex) ~f:(fun b -> b.name))
    and firmware =
      (* the stamped UART is certified apart, [Library.stamped] *)
      let stamped = if phys_equal p Uart.protocol then [ Uart.stamped ] else [] in
      names (List.map (stamped @ p.certified @ p.time_triggered) ~f:(fun c -> c.name))
    in
    let check own kind firmware_names =
      List.iter firmware_names ~f:(fun name ->
        if not (Set.mem own name) then print_s [%message "not its own" p.name kind name])
    in
    check bench "limit" (List.map p.limits ~f:(fun l -> l.firmware));
    check bench "unlimited" (List.map p.unlimited ~f:fst);
    check firmware "swept" (List.map p.swept ~f:(fun s -> s.name));
    check firmware "not swept" (List.map p.not_swept ~f:fst));
  [%expect {| ("not its own" frumbleglide "not swept" frumbleglide) |}]
;;

(* What a protocol file started by [generate.exe new-protocol] still leaves to do: a
   limit, a reason or a bench copy that says TODO, and a run sigrok judges with no payload
   to read. *)
let%expect_test "no protocol file is left half written" =
  let todo text = String.is_substring text ~substring:"TODO" in
  List.iter Library.protocols ~f:(fun p ->
    let left =
      List.filter_map p.limits ~f:(fun l ->
        Option.some_if
          (todo l.parameter
           || todo l.sheet.part
           || todo l.sheet.document
           || todo l.sheet.page)
          [%string "limit %{l.firmware} %{l.parameter}"])
      @ List.filter_map p.unlimited ~f:(fun (name, why) ->
        Option.some_if (todo why) [%string "unlimited %{name}"])
      @ List.filter_map p.not_swept ~f:(fun (name, why) ->
        Option.some_if (todo why) [%string "not swept %{name}"])
      @ List.filter_map (p.bench @ p.loaded_from_hex) ~f:(fun b ->
        Option.some_if (todo b.what) [%string "bench %{b.name}"])
      @ List.filter_map (p.scenarios @ p.decoded) ~f:(fun s ->
        Option.bind s.sigrok ~f:(fun sigrok ->
          Option.some_if
            (List.is_empty sigrok.expect || List.exists sigrok.decoders ~f:todo)
            [%string "sigrok %{s.name}"]))
    in
    if not (List.is_empty left) then print_s [%message p.name (left : string list)]);
  [%expect {| |}]
;;
