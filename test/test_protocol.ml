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

(* Everything a protocol file provides, from its record alone, in the order a new protocol
   goes through it. First each firmware's certificate, which CI then proves by induction
   ([make -C formal inductive_certificate NAME=...]). Then the bench copies against their
   datasheet limits, each run at the pins in lockstep with the engine, and what sigrok's
   decoders have to read off its trace (demo/decode.py checks that). *)
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
    (* what the host reads from rx through the whole chip on the scenario's trace: the
       words in the order the engine received them, or fewer *)
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

(* A protocol added as its own file shows up here with nothing else to write. *)
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
    i2c_master_standard_asym: 121 words, 43 deadline waits, worst slack 90, the kernel accepts it, assuming period 127, no wrap
    i2c_master_fast_asym: 111 words, 37 deadline waits, worst slack 22, the kernel accepts it, assuming period 32, no wrap
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
    i2c_standard_asym  THIGH          >=     4000 ns  kernel 254 (5291.7 ns)   needs  240       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 1000 ns, tr
    i2c_standard_asym  TLOW           >=     4700 ns  kernel 227 (4729.2 ns)   needs  227       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin a cycle
    i2c_standard_asym  THD:STA        >=     4000 ns  kernel 380 (7916.7 ns)   needs  193       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin a cycle
    i2c_standard_asym  TSU:STA        >=     4700 ns  kernel 381 (7937.5 ns)   needs  274       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 1000 ns, tr
    i2c_standard_asym  TSU:DAT        >=      250 ns  kernel 126 (2625.0 ns)   needs   60       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 1000 ns, tr
    i2c_standard_asym  TSU:STO        >=     4000 ns  kernel 381 (7937.5 ns)   needs  240       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 1000 ns, tr
    i2c_standard_asym  TBUF           >=     4700 ns  kernel 386 (8041.7 ns)   needs  274       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 1000 ns, tr
    i2c_standard_asym  1/fSCL         >=    10000 ns  run    481 (10020.8 ns)  needs  481       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 11, p.44, fSCL; margin a cycle
    i2c_fast_asym      THIGH          >=      600 ns  kernel 57 (1187.5 ns)    needs   44       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 300 ns, tr
    i2c_fast_asym      TLOW           >=     1300 ns  kernel 64 (1333.3 ns)    needs   64       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin a cycle
    i2c_fast_asym      THD:STA        >=      600 ns  kernel 64 (1333.3 ns)    needs   30       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin a cycle
    i2c_fast_asym      TSU:STA        >=      600 ns  kernel 64 (1333.3 ns)    needs   44       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 300 ns, tr
    i2c_fast_asym      TSU:DAT        >=      100 ns  kernel 31 (645.8 ns)     needs   20       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 300 ns, tr
    i2c_fast_asym      TSU:STO        >=      600 ns  kernel 64 (1333.3 ns)    needs   44       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 300 ns, tr
    i2c_fast_asym      TBUF           >=     1300 ns  kernel 101 (2104.2 ns)   needs   77       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44; margin 300 ns, tr
    i2c_fast_asym      1/fSCL         >=     2500 ns  run    121 (2520.8 ns)   needs  121       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 11, p.44, fSCL; margin a cycle

    lockstep: i2c_logger, i2c_logger
    ("lockstep held" (cycles 3000))
    (received ())
    decode: test/traces/i2c_logger.trace, by sigrok's i2c:scl=IO1:sda=IO0 uart:tx=OUT0:baudrate=3000000
      i2c=start:address-read:ack:data-read:nack:stop: i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 10, i2c-1: NACK, i2c-1: Stop, i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 21, i2c-1: NACK, i2c-1: Stop, i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 32, i2c-1: NACK, i2c-1: Stop, i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 43, i2c-1: NACK, i2c-1: Stop
      uart=tx-data: uart-1: 10, uart-1: 21, uart-1: 32, uart-1: 43

    === usb

    certificates
    usb_tx: 67 words, 11 deadline waits, worst slack 16, the kernel accepts it, assuming period 32
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
    spi_target_mode0: 47 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_target_mode1: 35 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_target_mode2: 45 words, 0 deadline waits, the kernel accepts it, assuming nothing
    spi_target_mode3: 34 words, 0 deadline waits, the kernel accepts it, assuming nothing
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

    === tdm_audio

    certificates
    tdm_audio: 117 words, 0 deadline waits, the kernel accepts it, assuming nothing

    limits
    tdm_audio: none, AN301 has no timing table: SCLK 12.288 MHz (p.2) is typical only, the example for 8 x 32-bit blocks at 48 kHz, with no minimum or maximum

    lockstep: tdm_audio, tdm_audio
    ("lockstep held" (cycles 3200))
    (received ())
    decode: test/traces/tdm_audio.trace, by sigrok's tdm_audio:clock=OUT0:frame=OUT1:data=OUT2:bps=32:channels=8
      tdm_audio=ch0:ch1:ch2:ch3:ch4:ch5:ch6:ch7: tdm_audio-1: Channel 1: 80000000, tdm_audio-1: Channel 2: 7fff0000, tdm_audio-1: Channel 3: 12340000, tdm_audio-1: Channel 4: a5a50000, tdm_audio-1: Channel 5: 00010000, tdm_audio-1: Channel 6: ffff0000, tdm_audio-1: Channel 7: 55550000, tdm_audio-1: Channel 8: c3c30000, tdm_audio-1: Channel 1: 00000000, tdm_audio-1: Channel 2: 00000000, tdm_audio-1: Channel 3: 00000000, tdm_audio-1: Channel 4: 00000000, tdm_audio-1: Channel 5: 00000000, tdm_audio-1: Channel 6: 00000000, tdm_audio-1: Channel 7: 00000000, tdm_audio-1: Channel 8: 00000000

    === usb_fs

    certificates
    usb_fs_device: 251 words, 5 deadline waits, worst slack 0, the kernel accepts it, assuming no wrap

    limits

    === dali

    certificates
    dali: 34 words, 8 deadline waits, worst slack 19993, the kernel accepts it, assuming period 20000, a load of 8 or more, no wrap

    limits
    dali               idle after a frame >= 2.45e+06 ns  run    540010 (11250208.3 ns) needs 117601       DALI, Wikipedia, Digital Addressable Lighting Interface, oldid 1363488623 p.1, line 178; margin a cycle
    dali               40 commands a second, forward frames 25 ms apart >=  2.5e+07 ns  run    1220010 (25416875.0 ns) needs 1200001       DALI, Wikipedia, Digital Addressable Lighting Interface, oldid 1363488623 p.1, line 188; margin a cycle

    lockstep: dali, dali
    ("lockstep held" (cycles 12200))
    (received ())
    decode: test/traces/dali.trace, by sigrok's dali:dali=OUT0
      dali=bit:startbit:ybit:address:command:reply:raw: dali-1: 1, dali-1: 0, dali-1: 0, dali-1: 0, dali-1: 0, dali-1: 0, dali-1: 0, dali-1: 1, dali-1: 1, dali-1: 1, dali-1: 0, dali-1: 1, dali-1: 0, dali-1: 0, dali-1: 0, dali-1: 0, dali-1: 0, dali-1: Startbit: 1, dali-1: Startbit: 1, dali-1: Raw data: 03, dali-1: Raw data: A0, dali-1: Command, dali-1: YBit: 0, dali-1: Short address: 1, dali-1: Command: 160 (Query Level), dali-1: 1, dali-1: 1, dali-1: 1, dali-1: 1, dali-1: 1, dali-1: 1, dali-1: 1, dali-1: 1, dali-1: 0, dali-1: Startbit: 1, dali-1: Startbit: 1, dali-1: Reply: FE, dali-1: Reply: 254

    === lin

    certificates
    lin: 60 words, 17 deadline waits, worst slack 1247, the kernel accepts it, assuming period 1250, a load of 16 or more, no wrap

    limits
    lin                break field    >=   677083 ns  run    33750 (703125.0 ns) needs 32501       LIN master, LIN Specification Package Revision 2.2A 2.3.1.1, p. 30; margin a cycle
    lin                break delimiter >=  52083.3 ns  run    3750 (78125.0 ns) needs 2501       LIN master, LIN Specification Package Revision 2.2A 2.3.1.1, p. 30; margin a cycle
    lin                break field length (dominant + delimiter) >=   729167 ns  run    37500 (781250.0 ns) needs 35002       LIN master, LIN Specification Package Revision 2.2A Table 2.3, p. 52; margin a cycle
    lin                THeader_Maximum, 1.4 * THeader_Nominal of 34 TBit <= 2.47917e+06 ns  run    87500 (1822916.7 ns) needs 118999       LIN master, LIN Specification Package Revision 2.2A 2.3.2 eq. (3), p. 32, eq. (6), p. 33; margin a cycle
    lin                FTOL_RES_MASTER, bit >=  51822.9 ns  run    2500 (52083.3 ns) needs 2489       LIN master, LIN Specification Package Revision 2.2A Table 6.1, p. 113; margin a cycle
    lin                FTOL_RES_MASTER, bit <=  52343.8 ns  run    2500 (52083.3 ns) needs 2511       LIN master, LIN Specification Package Revision 2.2A Table 6.1, p. 113; margin a cycle
    lin                bit rate, 20 kbit/s >=    50000 ns  run    2500 (52083.3 ns) needs 2401       LIN master, LIN Specification Package Revision 2.2A 6.3, p. 112; margin a cycle
    lin                bit rate, 1 kbit/s <=    1e+06 ns  run    2500 (52083.3 ns) needs 47999       LIN master, LIN Specification Package Revision 2.2A 6.3, p. 112; margin a cycle

    lockstep: lin, lin
    ("lockstep held" (cycles 2880))
    (received (0x4c 0x49 0x4e 0x45))
    decode: test/traces/lin.trace, by sigrok's uart:rx=IO5:baudrate=19200,lin
      lin=data:control: lin-1: Break condition, lin-1: Sync, lin-1: ID: 16 Parity: 3 (ok), lin-1: Data: 0x4C, lin-1: Data: 0x49, lin-1: Data: 0x4E, lin-1: Checksum: 0x45
      uart=rx-warnings:rx-break: uart-1: Frame error, uart-1: Break condition

    === spdif

    certificates
    spdif: 108 words, 40 deadline waits, worst slack 2, the kernel accepts it, assuming nothing

    limits
    spdif              a block of 192 frames, 44.1 kHz and 1100 ppm >= 4.34896e+06 ns  run    208979 (4353729.2 ns) needs 208751       S/PDIF, IEC 60958 type II, Wikipedia, S/PDIF, revision 1378032122 (2 October 2026) p.1, S/PDIF control word components, byte 3, spec.txt l.222-224; margin a cycle
    spdif              a block of 192 frames, 44.1 kHz less 1100 ppm <= 4.35854e+06 ns  run    208979 (4353729.2 ns) needs 209208       S/PDIF, IEC 60958 type II, Wikipedia, S/PDIF, revision 1378032122 (2 October 2026) p.1, S/PDIF control word components, byte 3, spec.txt l.222-224; margin a cycle
    spdif              a frame, Mode 0's 192 kHz at most >=  5208.33 ns  run    1088 (22666.7 ns) needs  251       S/PDIF, IEC 60958 type II, Wikipedia, S/PDIF, revision 1378032122 (2 October 2026) p.1, text, spec.txt l.180; margin a cycle

    lockstep: spdif, spdif
    ("lockstep held" (cycles 5445))
    (received ())
    decode: test/traces/spdif.trace, by sigrok's spdif:data=OUT0
      spdif=preamble: spdif-1: Preamble W, spdif-1: Preamble M, spdif-1: Preamble W, spdif-1: Preamble M, spdif-1: Preamble W, spdif-1: Preamble M, spdif-1: Preamble W, spdif-1: Preamble M, spdif-1: Preamble W
      spdif=samples: spdif-1: Audio 0xfedc00, spdif-1: Audio 0x800100, spdif-1: Audio 0x7ffe00, spdif-1: Audio 0xff00, spdif-1: Audio 0xa5a500, spdif-1: Audio 0x0, spdif-1: Audio 0x0, spdif-1: Audio 0x0

    === usb_power_delivery

    certificates
    usb_power_delivery: 113 words, 74 deadline waits, worst slack 13, the kernel accepts it, assuming nothing

    limits
    usb_power_delivery fBitRate max 330 kbps: each bit cell >=   3030.3 ns  run    160 (3333.3 ns)   needs  147       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.9, p.110; margin a cycle
    usb_power_delivery fBitRate min 270 kbps: each bit cell <=   3703.7 ns  run    160 (3333.3 ns)   needs  176       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.9, p.110; margin a cycle
    usb_power_delivery tUnitInterval min >=     3030 ns  run    160 (3333.3 ns)   needs  147       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.9, p.110; margin a cycle
    usb_power_delivery tUnitInterval max <=     3700 ns  run    160 (3333.3 ns)   needs  176       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.9, p.110; margin a cycle
    usb_power_delivery pBitRate 0.25 %: 32 bits against the preamble's last 32, of 32 UI at 300 kbps <=  266.667 ns  run    0 (0.0 ns)        needs   11       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.10, p.110, and 5.3.4.8 p.108; 300 kbps nominal, Table 5.9; margin a cycle
    usb_power_delivery tHoldLowBMC: every low >=     1000 ns  kernel 80 (1666.7 ns)    needs   49       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.10, p.110; margin a cycle
    usb_power_delivery tInterFrameGap: each idle low >=    25000 ns  run    1367 (28479.2 ns) needs 1201       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.10, p.110; margin a cycle

    lockstep: usb_power_delivery, usb_power_delivery
    ("lockstep held" (cycles 89540))
    (received ())
    decode: test/traces/usb_power_delivery.trace, by sigrok's usb_power_delivery:cc1=OUT0
      usb_power_delivery=preamble:sop:header:data:crc:eop:sym:warnings:src:payload: usb_power_delivery-1: Preamble, usb_power_delivery-1: SYNC-1, usb_power_delivery-1: SYNC-1, usb_power_delivery-1: SYNC-1, usb_power_delivery-1: SYNC-2, usb_power_delivery-1: SOP, usb_power_delivery-1: 0x1, usb_power_delivery-1: 0xA, usb_power_delivery-1: 0x1, usb_power_delivery-1: 0x1, usb_power_delivery-1: H:11a1, usb_power_delivery-1: (r3) SRC[0]: SOURCE CAP, usb_power_delivery-1: 0xC, usb_power_delivery-1: 0x2, usb_power_delivery-1: 0x1, usb_power_delivery-1: 0x9, usb_power_delivery-1: 0x1, usb_power_delivery-1: 0x0, usb_power_delivery-1: 0x0, usb_power_delivery-1: 0x0, usb_power_delivery-1: [0]0001912c, usb_power_delivery-1: [1] [Fixed] 5V 3A (15W), usb_power_delivery-1: 0xA, usb_power_delivery-1: 0xD, usb_power_delivery-1: 0xE, usb_power_delivery-1: 0x2, usb_power_delivery-1: 0xC, usb_power_delivery-1: 0x2, usb_power_delivery-1: 0x1, usb_power_delivery-1: 0x3, usb_power_delivery-1: CRC:312c2eda, usb_power_delivery-1: EOP, usb_power_delivery-1: EOP

    === dmx512

    certificates
    dmx512: 51 words, 14 deadline waits, worst slack 182, the kernel accepts it, assuming period 192, no wrap

    limits
    dmx512             bit at 250 kbit/s, shortest low >=     4000 ns  kernel 192 (4000.0 ns)   needs  192       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, line 291; margin 0 ns, the rate has no tolerance: a bit is 192 cycles at 48 MHz
    dmx512             bit at 250 kbit/s, shortest high >=     4000 ns  kernel 192 (4000.0 ns)   needs  192       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, line 291; margin 0 ns, the rate has no tolerance: a bit is 192 cycles at 48 MHz
    dmx512             bit at 250 kbit/s, longest channel low <=     4000 ns  run    192 (4000.0 ns)   needs  192       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, line 291; margin 0 ns, the rate has no tolerance: a bit is 192 cycles at 48 MHz
    dmx512             BREAK transmitted >=    92000 ns  run    4800 (100000.0 ns) needs 4417       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, table, lines 303-306; margin a cycle
    dmx512             BREAK receiver recognized >=    88000 ns  run    4800 (100000.0 ns) needs 4225       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, table, lines 303, 308-309; margin a cycle
    dmx512             MAB transmitted >=    12000 ns  run    768 (16000.0 ns)  needs  577       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, table, lines 304-305, 307; margin a cycle
    dmx512             MAB receiver recognized >=     8000 ns  run    768 (16000.0 ns)  needs  385       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, table, lines 304, 308, 310; margin a cycle
    dmx512             MAB since 1990 >=     8000 ns  run    768 (16000.0 ns)  needs  385       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, line 301; margin a cycle
    dmx512             break to break transmitted >= 1.204e+06 ns  run    1092101 (22752104.2 ns) needs 57793       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, line 313; margin a cycle
    dmx512             break to break receivers handle >= 1.196e+06 ns  run    1092101 (22752104.2 ns) needs 57409       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, line 313; margin a cycle
    dmx512             refresh rate of 512 channels, at most 44 Hz >= 2.27273e+07 ns  run    1092101 (22752104.2 ns) needs 1090911       DMX512, Wikipedia, DMX512, oldid 1380777110 page 1, line 312; margin a cycle

    lockstep: dmx512, dmx512
    ("lockstep held" (cycles 1146320))
    (received ())
    decode: test/traces/dmx512.trace, by sigrok's dmx512:dmx=OUT0
      dmx512=break:mab:startcode:channel:interpacket:data: dmx512-1: Break, dmx512-1: MAB, dmx512-1: Start code, dmx512-1: 0 / 0x0, dmx512-1: Channel 1, dmx512-1: 11 / 0xb, dmx512-1: Channel 2, dmx512-1: 48 / 0x30, dmx512-1: Channel 3, dmx512-1: 85 / 0x55, dmx512-1: Channel 4, dmx512-1: 122 / 0x7a, dmx512-1: Channel 5, dmx512-1: 159 / 0x9f, dmx512-1: Channel 6, dmx512-1: 196 / 0xc4, dmx512-1: Channel 7, dmx512-1: 233 / 0xe9, dmx512-1: Channel 8, dmx512-1: 14 / 0xe, dmx512-1: Channel 9, dmx512-1: 51 / 0x33, dmx512-1: Channel 10, dmx512-1: 88 / 0x58, dmx512-1: Channel 11, dmx512-1: 125 / 0x7d, dmx512-1: Channel 12, dmx512-1: 162 / 0xa2, dmx512-1: Channel 13, dmx512-1: 199 / 0xc7, dmx512-1: Channel 14, dmx512-1: 236 / 0xec, dmx512-1: Channel 15, dmx512-1: 17 / 0x11, dmx512-1: Channel 16, dmx512-1: 54 / 0x36, dmx512-1: Channel 17, dmx512-1: 91 / 0x5b, dmx512-1: Channel 18, dmx512-1: 128 / 0x80, dmx512-1: Channel 19, dmx512-1: 165 / 0xa5, dmx512-1: Channel 20, dmx512-1: 202 / 0xca, dmx512-1: Channel 21, dmx512-1: 239 / 0xef, dmx512-1: Channel 22, dmx512-1: 20 / 0x14, dmx512-1: Channel 23, dmx512-1: 57 / 0x39, dmx512-1: Channel 24, dmx512-1: 94 / 0x5e, dmx512-1: Channel 25, dmx512-1: 131 / 0x83, dmx512-1: Channel 26, dmx512-1: 168 / 0xa8, dmx512-1: Channel 27, dmx512-1: 205 / 0xcd, dmx512-1: Channel 28, dmx512-1: 242 / 0xf2, dmx512-1: Channel 29, dmx512-1: 23 / 0x17, dmx512-1: Channel 30, dmx512-1: 60 / 0x3c, dmx512-1: Channel 31, dmx512-1: 97 / 0x61, dmx512-1: Channel 32, dmx512-1: 134 / 0x86, dmx512-1: Channel 33, dmx512-1: 171 / 0xab, dmx512-1: Channel 34, dmx512-1: 208 / 0xd0, dmx512-1: Channel 35, dmx512-1: 245 / 0xf5, dmx512-1: Channel 36, dmx512-1: 26 / 0x1a, dmx512-1: Channel 37, dmx512-1: 63 / 0x3f, dmx512-1: Channel 38, dmx512-1: 100 / 0x64, dmx512-1: Channel 39, dmx512-1: 137 / 0x89, dmx512-1: Channel 40, dmx512-1: 174 / 0xae, dmx512-1: Channel 41, dmx512-1: 211 / 0xd3, dmx512-1: Channel 42, dmx512-1: 248 / 0xf8, dmx512-1: Channel 43, dmx512-1: 29 / 0x1d, dmx512-1: Channel 44, dmx512-1: 66 / 0x42, dmx512-1: Channel 45, dmx512-1: 103 / 0x67, dmx512-1: Channel 46, dmx512-1: 140 / 0x8c, dmx512-1: Channel 47, dmx512-1: 177 / 0xb1, dmx512-1: Channel 48, dmx512-1: 214 / 0xd6, dmx512-1: Channel 49, dmx512-1: 251 / 0xfb, dmx512-1: Channel 50, dmx512-1: 32 / 0x20, dmx512-1: Channel 51, dmx512-1: 69 / 0x45, dmx512-1: Channel 52, dmx512-1: 106 / 0x6a, dmx512-1: Channel 53, dmx512-1: 143 / 0x8f, dmx512-1: Channel 54, dmx512-1: 180 / 0xb4, dmx512-1: Channel 55, dmx512-1: 217 / 0xd9, dmx512-1: Channel 56, dmx512-1: 254 / 0xfe, dmx512-1: Channel 57, dmx512-1: 35 / 0x23, dmx512-1: Channel 58, dmx512-1: 72 / 0x48, dmx512-1: Channel 59, dmx512-1: 109 / 0x6d, dmx512-1: Channel 60, dmx512-1: 146 / 0x92, dmx512-1: Channel 61, dmx512-1: 183 / 0xb7, dmx512-1: Channel 62, dmx512-1: 220 / 0xdc, dmx512-1: Channel 63, dmx512-1: 1 / 0x1, dmx512-1: Channel 64, dmx512-1: 38 / 0x26, dmx512-1: Channel 65, dmx512-1: 75 / 0x4b, dmx512-1: Channel 66, dmx512-1: 112 / 0x70, dmx512-1: Channel 67, dmx512-1: 149 / 0x95, dmx512-1: Channel 68, dmx512-1: 186 / 0xba, dmx512-1: Channel 69, dmx512-1: 223 / 0xdf, dmx512-1: Channel 70, dmx512-1: 4 / 0x4, dmx512-1: Channel 71, dmx512-1: 41 / 0x29, dmx512-1: Channel 72, dmx512-1: 78 / 0x4e, dmx512-1: Channel 73, dmx512-1: 115 / 0x73, dmx512-1: Channel 74, dmx512-1: 152 / 0x98, dmx512-1: Channel 75, dmx512-1: 189 / 0xbd, dmx512-1: Channel 76, dmx512-1: 226 / 0xe2, dmx512-1: Channel 77, dmx512-1: 7 / 0x7, dmx512-1: Channel 78, dmx512-1: 44 / 0x2c, dmx512-1: Channel 79, dmx512-1: 81 / 0x51, dmx512-1: Channel 80, dmx512-1: 118 / 0x76, dmx512-1: Channel 81, dmx512-1: 155 / 0x9b, dmx512-1: Channel 82, dmx512-1: 192 / 0xc0, dmx512-1: Channel 83, dmx512-1: 229 / 0xe5, dmx512-1: Channel 84, dmx512-1: 10 / 0xa, dmx512-1: Channel 85, dmx512-1: 47 / 0x2f, dmx512-1: Channel 86, dmx512-1: 84 / 0x54, dmx512-1: Channel 87, dmx512-1: 121 / 0x79, dmx512-1: Channel 88, dmx512-1: 158 / 0x9e, dmx512-1: Channel 89, dmx512-1: 195 / 0xc3, dmx512-1: Channel 90, dmx512-1: 232 / 0xe8, dmx512-1: Channel 91, dmx512-1: 13 / 0xd, dmx512-1: Channel 92, dmx512-1: 50 / 0x32, dmx512-1: Channel 93, dmx512-1: 87 / 0x57, dmx512-1: Channel 94, dmx512-1: 124 / 0x7c, dmx512-1: Channel 95, dmx512-1: 161 / 0xa1, dmx512-1: Channel 96, dmx512-1: 198 / 0xc6, dmx512-1: Channel 97, dmx512-1: 235 / 0xeb, dmx512-1: Channel 98, dmx512-1: 16 / 0x10, dmx512-1: Channel 99, dmx512-1: 53 / 0x35, dmx512-1: Channel 100, dmx512-1: 90 / 0x5a, dmx512-1: Channel 101, dmx512-1: 127 / 0x7f, dmx512-1: Channel 102, dmx512-1: 164 / 0xa4, dmx512-1: Channel 103, dmx512-1: 201 / 0xc9, dmx512-1: Channel 104, dmx512-1: 238 / 0xee, dmx512-1: Channel 105, dmx512-1: 19 / 0x13, dmx512-1: Channel 106, dmx512-1: 56 / 0x38, dmx512-1: Channel 107, dmx512-1: 93 / 0x5d, dmx512-1: Channel 108, dmx512-1: 130 / 0x82, dmx512-1: Channel 109, dmx512-1: 167 / 0xa7, dmx512-1: Channel 110, dmx512-1: 204 / 0xcc, dmx512-1: Channel 111, dmx512-1: 241 / 0xf1, dmx512-1: Channel 112, dmx512-1: 22 / 0x16, dmx512-1: Channel 113, dmx512-1: 59 / 0x3b, dmx512-1: Channel 114, dmx512-1: 96 / 0x60, dmx512-1: Channel 115, dmx512-1: 133 / 0x85, dmx512-1: Channel 116, dmx512-1: 170 / 0xaa, dmx512-1: Channel 117, dmx512-1: 207 / 0xcf, dmx512-1: Channel 118, dmx512-1: 244 / 0xf4, dmx512-1: Channel 119, dmx512-1: 25 / 0x19, dmx512-1: Channel 120, dmx512-1: 62 / 0x3e, dmx512-1: Channel 121, dmx512-1: 99 / 0x63, dmx512-1: Channel 122, dmx512-1: 136 / 0x88, dmx512-1: Channel 123, dmx512-1: 173 / 0xad, dmx512-1: Channel 124, dmx512-1: 210 / 0xd2, dmx512-1: Channel 125, dmx512-1: 247 / 0xf7, dmx512-1: Channel 126, dmx512-1: 28 / 0x1c, dmx512-1: Channel 127, dmx512-1: 65 / 0x41, dmx512-1: Channel 128, dmx512-1: 102 / 0x66, dmx512-1: Channel 129, dmx512-1: 139 / 0x8b, dmx512-1: Channel 130, dmx512-1: 176 / 0xb0, dmx512-1: Channel 131, dmx512-1: 213 / 0xd5, dmx512-1: Channel 132, dmx512-1: 250 / 0xfa, dmx512-1: Channel 133, dmx512-1: 31 / 0x1f, dmx512-1: Channel 134, dmx512-1: 68 / 0x44, dmx512-1: Channel 135, dmx512-1: 105 / 0x69, dmx512-1: Channel 136, dmx512-1: 142 / 0x8e, dmx512-1: Channel 137, dmx512-1: 179 / 0xb3, dmx512-1: Channel 138, dmx512-1: 216 / 0xd8, dmx512-1: Channel 139, dmx512-1: 253 / 0xfd, dmx512-1: Channel 140, dmx512-1: 34 / 0x22, dmx512-1: Channel 141, dmx512-1: 71 / 0x47, dmx512-1: Channel 142, dmx512-1: 108 / 0x6c, dmx512-1: Channel 143, dmx512-1: 145 / 0x91, dmx512-1: Channel 144, dmx512-1: 182 / 0xb6, dmx512-1: Channel 145, dmx512-1: 219 / 0xdb, dmx512-1: Channel 146, dmx512-1: 0 / 0x0, dmx512-1: Channel 147, dmx512-1: 37 / 0x25, dmx512-1: Channel 148, dmx512-1: 74 / 0x4a, dmx512-1: Channel 149, dmx512-1: 111 / 0x6f, dmx512-1: Channel 150, dmx512-1: 148 / 0x94, dmx512-1: Channel 151, dmx512-1: 185 / 0xb9, dmx512-1: Channel 152, dmx512-1: 222 / 0xde, dmx512-1: Channel 153, dmx512-1: 3 / 0x3, dmx512-1: Channel 154, dmx512-1: 40 / 0x28, dmx512-1: Channel 155, dmx512-1: 77 / 0x4d, dmx512-1: Channel 156, dmx512-1: 114 / 0x72, dmx512-1: Channel 157, dmx512-1: 151 / 0x97, dmx512-1: Channel 158, dmx512-1: 188 / 0xbc, dmx512-1: Channel 159, dmx512-1: 225 / 0xe1, dmx512-1: Channel 160, dmx512-1: 6 / 0x6, dmx512-1: Channel 161, dmx512-1: 43 / 0x2b, dmx512-1: Channel 162, dmx512-1: 80 / 0x50, dmx512-1: Channel 163, dmx512-1: 117 / 0x75, dmx512-1: Channel 164, dmx512-1: 154 / 0x9a, dmx512-1: Channel 165, dmx512-1: 191 / 0xbf, dmx512-1: Channel 166, dmx512-1: 228 / 0xe4, dmx512-1: Channel 167, dmx512-1: 9 / 0x9, dmx512-1: Channel 168, dmx512-1: 46 / 0x2e, dmx512-1: Channel 169, dmx512-1: 83 / 0x53, dmx512-1: Channel 170, dmx512-1: 120 / 0x78, dmx512-1: Channel 171, dmx512-1: 157 / 0x9d, dmx512-1: Channel 172, dmx512-1: 194 / 0xc2, dmx512-1: Channel 173, dmx512-1: 231 / 0xe7, dmx512-1: Channel 174, dmx512-1: 12 / 0xc, dmx512-1: Channel 175, dmx512-1: 49 / 0x31, dmx512-1: Channel 176, dmx512-1: 86 / 0x56, dmx512-1: Channel 177, dmx512-1: 123 / 0x7b, dmx512-1: Channel 178, dmx512-1: 160 / 0xa0, dmx512-1: Channel 179, dmx512-1: 197 / 0xc5, dmx512-1: Channel 180, dmx512-1: 234 / 0xea, dmx512-1: Channel 181, dmx512-1: 15 / 0xf, dmx512-1: Channel 182, dmx512-1: 52 / 0x34, dmx512-1: Channel 183, dmx512-1: 89 / 0x59, dmx512-1: Channel 184, dmx512-1: 126 / 0x7e, dmx512-1: Channel 185, dmx512-1: 163 / 0xa3, dmx512-1: Channel 186, dmx512-1: 200 / 0xc8, dmx512-1: Channel 187, dmx512-1: 237 / 0xed, dmx512-1: Channel 188, dmx512-1: 18 / 0x12, dmx512-1: Channel 189, dmx512-1: 55 / 0x37, dmx512-1: Channel 190, dmx512-1: 92 / 0x5c, dmx512-1: Channel 191, dmx512-1: 129 / 0x81, dmx512-1: Channel 192, dmx512-1: 166 / 0xa6, dmx512-1: Channel 193, dmx512-1: 203 / 0xcb, dmx512-1: Channel 194, dmx512-1: 240 / 0xf0, dmx512-1: Channel 195, dmx512-1: 21 / 0x15, dmx512-1: Channel 196, dmx512-1: 58 / 0x3a, dmx512-1: Channel 197, dmx512-1: 95 / 0x5f, dmx512-1: Channel 198, dmx512-1: 132 / 0x84, dmx512-1: Channel 199, dmx512-1: 169 / 0xa9, dmx512-1: Channel 200, dmx512-1: 206 / 0xce, dmx512-1: Channel 201, dmx512-1: 243 / 0xf3, dmx512-1: Channel 202, dmx512-1: 24 / 0x18, dmx512-1: Channel 203, dmx512-1: 61 / 0x3d, dmx512-1: Channel 204, dmx512-1: 98 / 0x62, dmx512-1: Channel 205, dmx512-1: 135 / 0x87, dmx512-1: Channel 206, dmx512-1: 172 / 0xac, dmx512-1: Channel 207, dmx512-1: 209 / 0xd1, dmx512-1: Channel 208, dmx512-1: 246 / 0xf6, dmx512-1: Channel 209, dmx512-1: 27 / 0x1b, dmx512-1: Channel 210, dmx512-1: 64 / 0x40, dmx512-1: Channel 211, dmx512-1: 101 / 0x65, dmx512-1: Channel 212, dmx512-1: 138 / 0x8a, dmx512-1: Channel 213, dmx512-1: 175 / 0xaf, dmx512-1: Channel 214, dmx512-1: 212 / 0xd4, dmx512-1: Channel 215, dmx512-1: 249 / 0xf9, dmx512-1: Channel 216, dmx512-1: 30 / 0x1e, dmx512-1: Channel 217, dmx512-1: 67 / 0x43, dmx512-1: Channel 218, dmx512-1: 104 / 0x68, dmx512-1: Channel 219, dmx512-1: 141 / 0x8d, dmx512-1: Channel 220, dmx512-1: 178 / 0xb2, dmx512-1: Channel 221, dmx512-1: 215 / 0xd7, dmx512-1: Channel 222, dmx512-1: 252 / 0xfc, dmx512-1: Channel 223, dmx512-1: 33 / 0x21, dmx512-1: Channel 224, dmx512-1: 70 / 0x46, dmx512-1: Channel 225, dmx512-1: 107 / 0x6b, dmx512-1: Channel 226, dmx512-1: 144 / 0x90, dmx512-1: Channel 227, dmx512-1: 181 / 0xb5, dmx512-1: Channel 228, dmx512-1: 218 / 0xda, dmx512-1: Channel 229, dmx512-1: 255 / 0xff, dmx512-1: Channel 230, dmx512-1: 36 / 0x24, dmx512-1: Channel 231, dmx512-1: 73 / 0x49, dmx512-1: Channel 232, dmx512-1: 110 / 0x6e, dmx512-1: Channel 233, dmx512-1: 147 / 0x93, dmx512-1: Channel 234, dmx512-1: 184 / 0xb8, dmx512-1: Channel 235, dmx512-1: 221 / 0xdd, dmx512-1: Channel 236, dmx512-1: 2 / 0x2, dmx512-1: Channel 237, dmx512-1: 39 / 0x27, dmx512-1: Channel 238, dmx512-1: 76 / 0x4c, dmx512-1: Channel 239, dmx512-1: 113 / 0x71, dmx512-1: Channel 240, dmx512-1: 150 / 0x96, dmx512-1: Channel 241, dmx512-1: 187 / 0xbb, dmx512-1: Channel 242, dmx512-1: 224 / 0xe0, dmx512-1: Channel 243, dmx512-1: 5 / 0x5, dmx512-1: Channel 244, dmx512-1: 42 / 0x2a, dmx512-1: Channel 245, dmx512-1: 79 / 0x4f, dmx512-1: Channel 246, dmx512-1: 116 / 0x74, dmx512-1: Channel 247, dmx512-1: 153 / 0x99, dmx512-1: Channel 248, dmx512-1: 190 / 0xbe, dmx512-1: Channel 249, dmx512-1: 227 / 0xe3, dmx512-1: Channel 250, dmx512-1: 8 / 0x8, dmx512-1: Channel 251, dmx512-1: 45 / 0x2d, dmx512-1: Channel 252, dmx512-1: 82 / 0x52, dmx512-1: Channel 253, dmx512-1: 119 / 0x77, dmx512-1: Channel 254, dmx512-1: 156 / 0x9c, dmx512-1: Channel 255, dmx512-1: 193 / 0xc1, dmx512-1: Channel 256, dmx512-1: 230 / 0xe6, dmx512-1: Channel 257, dmx512-1: 11 / 0xb, dmx512-1: Channel 258, dmx512-1: 48 / 0x30, dmx512-1: Channel 259, dmx512-1: 85 / 0x55, dmx512-1: Channel 260, dmx512-1: 122 / 0x7a, dmx512-1: Channel 261, dmx512-1: 159 / 0x9f, dmx512-1: Channel 262, dmx512-1: 196 / 0xc4, dmx512-1: Channel 263, dmx512-1: 233 / 0xe9, dmx512-1: Channel 264, dmx512-1: 14 / 0xe, dmx512-1: Channel 265, dmx512-1: 51 / 0x33, dmx512-1: Channel 266, dmx512-1: 88 / 0x58, dmx512-1: Channel 267, dmx512-1: 125 / 0x7d, dmx512-1: Channel 268, dmx512-1: 162 / 0xa2, dmx512-1: Channel 269, dmx512-1: 199 / 0xc7, dmx512-1: Channel 270, dmx512-1: 236 / 0xec, dmx512-1: Channel 271, dmx512-1: 17 / 0x11, dmx512-1: Channel 272, dmx512-1: 54 / 0x36, dmx512-1: Channel 273, dmx512-1: 91 / 0x5b, dmx512-1: Channel 274, dmx512-1: 128 / 0x80, dmx512-1: Channel 275, dmx512-1: 165 / 0xa5, dmx512-1: Channel 276, dmx512-1: 202 / 0xca, dmx512-1: Channel 277, dmx512-1: 239 / 0xef, dmx512-1: Channel 278, dmx512-1: 20 / 0x14, dmx512-1: Channel 279, dmx512-1: 57 / 0x39, dmx512-1: Channel 280, dmx512-1: 94 / 0x5e, dmx512-1: Channel 281, dmx512-1: 131 / 0x83, dmx512-1: Channel 282, dmx512-1: 168 / 0xa8, dmx512-1: Channel 283, dmx512-1: 205 / 0xcd, dmx512-1: Channel 284, dmx512-1: 242 / 0xf2, dmx512-1: Channel 285, dmx512-1: 23 / 0x17, dmx512-1: Channel 286, dmx512-1: 60 / 0x3c, dmx512-1: Channel 287, dmx512-1: 97 / 0x61, dmx512-1: Channel 288, dmx512-1: 134 / 0x86, dmx512-1: Channel 289, dmx512-1: 171 / 0xab, dmx512-1: Channel 290, dmx512-1: 208 / 0xd0, dmx512-1: Channel 291, dmx512-1: 245 / 0xf5, dmx512-1: Channel 292, dmx512-1: 26 / 0x1a, dmx512-1: Channel 293, dmx512-1: 63 / 0x3f, dmx512-1: Channel 294, dmx512-1: 100 / 0x64, dmx512-1: Channel 295, dmx512-1: 137 / 0x89, dmx512-1: Channel 296, dmx512-1: 174 / 0xae, dmx512-1: Channel 297, dmx512-1: 211 / 0xd3, dmx512-1: Channel 298, dmx512-1: 248 / 0xf8, dmx512-1: Channel 299, dmx512-1: 29 / 0x1d, dmx512-1: Channel 300, dmx512-1: 66 / 0x42, dmx512-1: Channel 301, dmx512-1: 103 / 0x67, dmx512-1: Channel 302, dmx512-1: 140 / 0x8c, dmx512-1: Channel 303, dmx512-1: 177 / 0xb1, dmx512-1: Channel 304, dmx512-1: 214 / 0xd6, dmx512-1: Channel 305, dmx512-1: 251 / 0xfb, dmx512-1: Channel 306, dmx512-1: 32 / 0x20, dmx512-1: Channel 307, dmx512-1: 69 / 0x45, dmx512-1: Channel 308, dmx512-1: 106 / 0x6a, dmx512-1: Channel 309, dmx512-1: 143 / 0x8f, dmx512-1: Channel 310, dmx512-1: 180 / 0xb4, dmx512-1: Channel 311, dmx512-1: 217 / 0xd9, dmx512-1: Channel 312, dmx512-1: 254 / 0xfe, dmx512-1: Channel 313, dmx512-1: 35 / 0x23, dmx512-1: Channel 314, dmx512-1: 72 / 0x48, dmx512-1: Channel 315, dmx512-1: 109 / 0x6d, dmx512-1: Channel 316, dmx512-1: 146 / 0x92, dmx512-1: Channel 317, dmx512-1: 183 / 0xb7, dmx512-1: Channel 318, dmx512-1: 220 / 0xdc, dmx512-1: Channel 319, dmx512-1: 1 / 0x1, dmx512-1: Channel 320, dmx512-1: 38 / 0x26, dmx512-1: Channel 321, dmx512-1: 75 / 0x4b, dmx512-1: Channel 322, dmx512-1: 112 / 0x70, dmx512-1: Channel 323, dmx512-1: 149 / 0x95, dmx512-1: Channel 324, dmx512-1: 186 / 0xba, dmx512-1: Channel 325, dmx512-1: 223 / 0xdf, dmx512-1: Channel 326, dmx512-1: 4 / 0x4, dmx512-1: Channel 327, dmx512-1: 41 / 0x29, dmx512-1: Channel 328, dmx512-1: 78 / 0x4e, dmx512-1: Channel 329, dmx512-1: 115 / 0x73, dmx512-1: Channel 330, dmx512-1: 152 / 0x98, dmx512-1: Channel 331, dmx512-1: 189 / 0xbd, dmx512-1: Channel 332, dmx512-1: 226 / 0xe2, dmx512-1: Channel 333, dmx512-1: 7 / 0x7, dmx512-1: Channel 334, dmx512-1: 44 / 0x2c, dmx512-1: Channel 335, dmx512-1: 81 / 0x51, dmx512-1: Channel 336, dmx512-1: 118 / 0x76, dmx512-1: Channel 337, dmx512-1: 155 / 0x9b, dmx512-1: Channel 338, dmx512-1: 192 / 0xc0, dmx512-1: Channel 339, dmx512-1: 229 / 0xe5, dmx512-1: Channel 340, dmx512-1: 10 / 0xa, dmx512-1: Channel 341, dmx512-1: 47 / 0x2f, dmx512-1: Channel 342, dmx512-1: 84 / 0x54, dmx512-1: Channel 343, dmx512-1: 121 / 0x79, dmx512-1: Channel 344, dmx512-1: 158 / 0x9e, dmx512-1: Channel 345, dmx512-1: 195 / 0xc3, dmx512-1: Channel 346, dmx512-1: 232 / 0xe8, dmx512-1: Channel 347, dmx512-1: 13 / 0xd, dmx512-1: Channel 348, dmx512-1: 50 / 0x32, dmx512-1: Channel 349, dmx512-1: 87 / 0x57, dmx512-1: Channel 350, dmx512-1: 124 / 0x7c, dmx512-1: Channel 351, dmx512-1: 161 / 0xa1, dmx512-1: Channel 352, dmx512-1: 198 / 0xc6, dmx512-1: Channel 353, dmx512-1: 235 / 0xeb, dmx512-1: Channel 354, dmx512-1: 16 / 0x10, dmx512-1: Channel 355, dmx512-1: 53 / 0x35, dmx512-1: Channel 356, dmx512-1: 90 / 0x5a, dmx512-1: Channel 357, dmx512-1: 127 / 0x7f, dmx512-1: Channel 358, dmx512-1: 164 / 0xa4, dmx512-1: Channel 359, dmx512-1: 201 / 0xc9, dmx512-1: Channel 360, dmx512-1: 238 / 0xee, dmx512-1: Channel 361, dmx512-1: 19 / 0x13, dmx512-1: Channel 362, dmx512-1: 56 / 0x38, dmx512-1: Channel 363, dmx512-1: 93 / 0x5d, dmx512-1: Channel 364, dmx512-1: 130 / 0x82, dmx512-1: Channel 365, dmx512-1: 167 / 0xa7, dmx512-1: Channel 366, dmx512-1: 204 / 0xcc, dmx512-1: Channel 367, dmx512-1: 241 / 0xf1, dmx512-1: Channel 368, dmx512-1: 22 / 0x16, dmx512-1: Channel 369, dmx512-1: 59 / 0x3b, dmx512-1: Channel 370, dmx512-1: 96 / 0x60, dmx512-1: Channel 371, dmx512-1: 133 / 0x85, dmx512-1: Channel 372, dmx512-1: 170 / 0xaa, dmx512-1: Channel 373, dmx512-1: 207 / 0xcf, dmx512-1: Channel 374, dmx512-1: 244 / 0xf4, dmx512-1: Channel 375, dmx512-1: 25 / 0x19, dmx512-1: Channel 376, dmx512-1: 62 / 0x3e, dmx512-1: Channel 377, dmx512-1: 99 / 0x63, dmx512-1: Channel 378, dmx512-1: 136 / 0x88, dmx512-1: Channel 379, dmx512-1: 173 / 0xad, dmx512-1: Channel 380, dmx512-1: 210 / 0xd2, dmx512-1: Channel 381, dmx512-1: 247 / 0xf7, dmx512-1: Channel 382, dmx512-1: 28 / 0x1c, dmx512-1: Channel 383, dmx512-1: 65 / 0x41, dmx512-1: Channel 384, dmx512-1: 102 / 0x66, dmx512-1: Channel 385, dmx512-1: 139 / 0x8b, dmx512-1: Channel 386, dmx512-1: 176 / 0xb0, dmx512-1: Channel 387, dmx512-1: 213 / 0xd5, dmx512-1: Channel 388, dmx512-1: 250 / 0xfa, dmx512-1: Channel 389, dmx512-1: 31 / 0x1f, dmx512-1: Channel 390, dmx512-1: 68 / 0x44, dmx512-1: Channel 391, dmx512-1: 105 / 0x69, dmx512-1: Channel 392, dmx512-1: 142 / 0x8e, dmx512-1: Channel 393, dmx512-1: 179 / 0xb3, dmx512-1: Channel 394, dmx512-1: 216 / 0xd8, dmx512-1: Channel 395, dmx512-1: 253 / 0xfd, dmx512-1: Channel 396, dmx512-1: 34 / 0x22, dmx512-1: Channel 397, dmx512-1: 71 / 0x47, dmx512-1: Channel 398, dmx512-1: 108 / 0x6c, dmx512-1: Channel 399, dmx512-1: 145 / 0x91, dmx512-1: Channel 400, dmx512-1: 182 / 0xb6, dmx512-1: Channel 401, dmx512-1: 219 / 0xdb, dmx512-1: Channel 402, dmx512-1: 0 / 0x0, dmx512-1: Channel 403, dmx512-1: 37 / 0x25, dmx512-1: Channel 404, dmx512-1: 74 / 0x4a, dmx512-1: Channel 405, dmx512-1: 111 / 0x6f, dmx512-1: Channel 406, dmx512-1: 148 / 0x94, dmx512-1: Channel 407, dmx512-1: 185 / 0xb9, dmx512-1: Channel 408, dmx512-1: 222 / 0xde, dmx512-1: Channel 409, dmx512-1: 3 / 0x3, dmx512-1: Channel 410, dmx512-1: 40 / 0x28, dmx512-1: Channel 411, dmx512-1: 77 / 0x4d, dmx512-1: Channel 412, dmx512-1: 114 / 0x72, dmx512-1: Channel 413, dmx512-1: 151 / 0x97, dmx512-1: Channel 414, dmx512-1: 188 / 0xbc, dmx512-1: Channel 415, dmx512-1: 225 / 0xe1, dmx512-1: Channel 416, dmx512-1: 6 / 0x6, dmx512-1: Channel 417, dmx512-1: 43 / 0x2b, dmx512-1: Channel 418, dmx512-1: 80 / 0x50, dmx512-1: Channel 419, dmx512-1: 117 / 0x75, dmx512-1: Channel 420, dmx512-1: 154 / 0x9a, dmx512-1: Channel 421, dmx512-1: 191 / 0xbf, dmx512-1: Channel 422, dmx512-1: 228 / 0xe4, dmx512-1: Channel 423, dmx512-1: 9 / 0x9, dmx512-1: Channel 424, dmx512-1: 46 / 0x2e, dmx512-1: Channel 425, dmx512-1: 83 / 0x53, dmx512-1: Channel 426, dmx512-1: 120 / 0x78, dmx512-1: Channel 427, dmx512-1: 157 / 0x9d, dmx512-1: Channel 428, dmx512-1: 194 / 0xc2, dmx512-1: Channel 429, dmx512-1: 231 / 0xe7, dmx512-1: Channel 430, dmx512-1: 12 / 0xc, dmx512-1: Channel 431, dmx512-1: 49 / 0x31, dmx512-1: Channel 432, dmx512-1: 86 / 0x56, dmx512-1: Channel 433, dmx512-1: 123 / 0x7b, dmx512-1: Channel 434, dmx512-1: 160 / 0xa0, dmx512-1: Channel 435, dmx512-1: 197 / 0xc5, dmx512-1: Channel 436, dmx512-1: 234 / 0xea, dmx512-1: Channel 437, dmx512-1: 15 / 0xf, dmx512-1: Channel 438, dmx512-1: 52 / 0x34, dmx512-1: Channel 439, dmx512-1: 89 / 0x59, dmx512-1: Channel 440, dmx512-1: 126 / 0x7e, dmx512-1: Channel 441, dmx512-1: 163 / 0xa3, dmx512-1: Channel 442, dmx512-1: 200 / 0xc8, dmx512-1: Channel 443, dmx512-1: 237 / 0xed, dmx512-1: Channel 444, dmx512-1: 18 / 0x12, dmx512-1: Channel 445, dmx512-1: 55 / 0x37, dmx512-1: Channel 446, dmx512-1: 92 / 0x5c, dmx512-1: Channel 447, dmx512-1: 129 / 0x81, dmx512-1: Channel 448, dmx512-1: 166 / 0xa6, dmx512-1: Channel 449, dmx512-1: 203 / 0xcb, dmx512-1: Channel 450, dmx512-1: 240 / 0xf0, dmx512-1: Channel 451, dmx512-1: 21 / 0x15, dmx512-1: Channel 452, dmx512-1: 58 / 0x3a, dmx512-1: Channel 453, dmx512-1: 95 / 0x5f, dmx512-1: Channel 454, dmx512-1: 132 / 0x84, dmx512-1: Channel 455, dmx512-1: 169 / 0xa9, dmx512-1: Channel 456, dmx512-1: 206 / 0xce, dmx512-1: Channel 457, dmx512-1: 243 / 0xf3, dmx512-1: Channel 458, dmx512-1: 24 / 0x18, dmx512-1: Channel 459, dmx512-1: 61 / 0x3d, dmx512-1: Channel 460, dmx512-1: 98 / 0x62, dmx512-1: Channel 461, dmx512-1: 135 / 0x87, dmx512-1: Channel 462, dmx512-1: 172 / 0xac, dmx512-1: Channel 463, dmx512-1: 209 / 0xd1, dmx512-1: Channel 464, dmx512-1: 246 / 0xf6, dmx512-1: Channel 465, dmx512-1: 27 / 0x1b, dmx512-1: Channel 466, dmx512-1: 64 / 0x40, dmx512-1: Channel 467, dmx512-1: 101 / 0x65, dmx512-1: Channel 468, dmx512-1: 138 / 0x8a, dmx512-1: Channel 469, dmx512-1: 175 / 0xaf, dmx512-1: Channel 470, dmx512-1: 212 / 0xd4, dmx512-1: Channel 471, dmx512-1: 249 / 0xf9, dmx512-1: Channel 472, dmx512-1: 30 / 0x1e, dmx512-1: Channel 473, dmx512-1: 67 / 0x43, dmx512-1: Channel 474, dmx512-1: 104 / 0x68, dmx512-1: Channel 475, dmx512-1: 141 / 0x8d, dmx512-1: Channel 476, dmx512-1: 178 / 0xb2, dmx512-1: Channel 477, dmx512-1: 215 / 0xd7, dmx512-1: Channel 478, dmx512-1: 252 / 0xfc, dmx512-1: Channel 479, dmx512-1: 33 / 0x21, dmx512-1: Channel 480, dmx512-1: 70 / 0x46, dmx512-1: Channel 481, dmx512-1: 107 / 0x6b, dmx512-1: Channel 482, dmx512-1: 144 / 0x90, dmx512-1: Channel 483, dmx512-1: 181 / 0xb5, dmx512-1: Channel 484, dmx512-1: 218 / 0xda, dmx512-1: Channel 485, dmx512-1: 255 / 0xff, dmx512-1: Channel 486, dmx512-1: 36 / 0x24, dmx512-1: Channel 487, dmx512-1: 73 / 0x49, dmx512-1: Channel 488, dmx512-1: 110 / 0x6e, dmx512-1: Channel 489, dmx512-1: 147 / 0x93, dmx512-1: Channel 490, dmx512-1: 184 / 0xb8, dmx512-1: Channel 491, dmx512-1: 221 / 0xdd, dmx512-1: Channel 492, dmx512-1: 2 / 0x2, dmx512-1: Channel 493, dmx512-1: 39 / 0x27, dmx512-1: Channel 494, dmx512-1: 76 / 0x4c, dmx512-1: Channel 495, dmx512-1: 113 / 0x71, dmx512-1: Channel 496, dmx512-1: 150 / 0x96, dmx512-1: Channel 497, dmx512-1: 187 / 0xbb, dmx512-1: Channel 498, dmx512-1: 224 / 0xe0, dmx512-1: Channel 499, dmx512-1: 5 / 0x5, dmx512-1: Channel 500, dmx512-1: 42 / 0x2a, dmx512-1: Channel 501, dmx512-1: 79 / 0x4f, dmx512-1: Channel 502, dmx512-1: 116 / 0x74, dmx512-1: Channel 503, dmx512-1: 153 / 0x99, dmx512-1: Channel 504, dmx512-1: 190 / 0xbe, dmx512-1: Channel 505, dmx512-1: 227 / 0xe3, dmx512-1: Channel 506, dmx512-1: 8 / 0x8, dmx512-1: Channel 507, dmx512-1: 45 / 0x2d, dmx512-1: Channel 508, dmx512-1: 82 / 0x52, dmx512-1: Channel 509, dmx512-1: 119 / 0x77, dmx512-1: Channel 510, dmx512-1: 156 / 0x9c, dmx512-1: Channel 511, dmx512-1: 193 / 0xc1, dmx512-1: Channel 512, dmx512-1: 230 / 0xe6, dmx512-1: Interpacket, dmx512-1: Break, dmx512-1: MAB, dmx512-1: Start code, dmx512-1: 0 / 0x0

    === wiegand

    certificates
    wiegand: 32 words, 4 deadline waits, worst slack 2389, the kernel accepts it, assuming period 2400, a load of 16 or more

    limits
    wiegand: none, the spec, Wikipedia's Wiegand interface page, gives no pulse width, interval or any other timing

    lockstep: wiegand, wiegand
    ("lockstep held" (cycles 672000))
    (received ())
    decode: test/traces/wiegand.trace, by sigrok's wiegand:d0=OUT0:d1=OUT1:bitwidth_ms=1
      wiegand=state: wiegand-1: 26 bits 00010101000010010001101001

    === swd_blind

    certificates
    swd_blind: 22 words, 2 deadline waits, worst slack 13, the kernel accepts it, assuming period 24, a load of 12 or more

    limits
    swd_blind          Trn            >=     1000 ns  kernel 50 (1041.7 ns)    needs   49       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 Table 2-10, p.2-52; margin a cycle
    swd_blind          line reset     >=    50000 ns  run    2910 (60625.0 ns) needs 2401       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 4.4.3, p.4-104; margin a cycle
    swd_blind          idle cycles    >=     2000 ns  run    394 (8208.3 ns)   needs   97       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 4.4.3, p.4-104; margin a cycle
    swd_blind          JTAG-to-SWD    >=    50000 ns  run    2758 (57458.3 ns) needs 2401       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 5.2.1, p.5-111; margin a cycle
    swd_blind          JTAG-to-DS     >=     5000 ns  run    548 (11416.7 ns)  needs  241       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 5.3.2, p.5-115; margin a cycle
    swd_blind          SWD-to-DS      >=    50000 ns  run    2758 (57458.3 ns) needs 2401       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 5.3.3, p.5-116; margin a cycle
    swd_blind          DS-to-SWD      >=    50000 ns  run    2758 (57458.3 ns) needs 2401       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 5.3.4, p.5-117; margin a cycle

    lockstep: swd_blind, swd_blind
    ("lockstep held" (cycles 9600))
    (received
     (0xff00 0xff00 0xff00 0xff00 0xff00 0xff00 0xff00 0x0 0xa500 0xb900 0x2300
      0x900 0x5e00 0x1000 0x8700 0x100 0x0 0x0 0x0 0x1000 0x0))
    decode: test/traces/swd_blind.trace, by sigrok's swd:swclk=OUT2:swdio=IO5
      swd=reset:read:ack:data: swd-1: LINERESET, swd-1: IDCODE, swd-1: OK, swd-1: 0x0bc12477, swd-1: R AP0, swd-1: OK, swd-1: 0x00000000

    === ir_nec

    certificates
    ir_nec: 107 words, 34 deadline waits, worst slack 409, the kernel accepts it, assuming period 422, a load of 16 or more

    limits
    ir_nec             Carrier frequency, as its period >=  26315.8 ns  run    1266 (26375.0 ns) needs 1265       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 17; margin a cycle
    ir_nec             Bit time, logical 0 >= 1.125e+06 ns  run    54438 (1134125.0 ns) needs 54001       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 18; margin a cycle
    ir_nec             Bit time, logical 1 >= 2.25e+06 ns  run    108454 (2259458.3 ns) needs 108001       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 18; margin a cycle
    ir_nec             Carrier burst length >=   560000 ns  run    27008 (562666.7 ns) needs 26881       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 21; margin a cycle
    ir_nec             AGC burst, message start >=    9e+06 ns  run    433394 (9029041.7 ns) needs 432001       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 28; margin a cycle
    ir_nec             Space after AGC burst, message start >=  4.5e+06 ns  run    216486 (4510125.0 ns) needs 216001       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 29; margin a cycle
    ir_nec             Extra burst at end of message >=   560000 ns  run    27008 (562666.7 ns) needs 26881       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 34; margin a cycle
    ir_nec             AGC pulse, repeat code >=    9e+06 ns  run    433394 (9029041.7 ns) needs 432001       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 37; margin a cycle
    ir_nec             Space after AGC pulse, repeat code >= 2.25e+06 ns  run    108454 (2259458.3 ns) needs 108001       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 37; margin a cycle
    ir_nec             Burst, repeat code >=   560000 ns  run    27008 (562666.7 ns) needs 26881       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 37; margin a cycle
    ir_nec             Repeat code space >= 2.25e+06 ns  run    108454 (2259458.3 ns) needs 108001       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 37; margin a cycle
    ir_nec             Repeat code burst >=   560000 ns  run    27008 (562666.7 ns) needs 26881       NEC infrared remote, SB-Projects, NEC Protocol, updated 17 July 2025 page 1, line 37; margin a cycle

    lockstep: ir_nec, ir_nec
    ("lockstep held" (cycles 243840))
    (received ())
    decode: test/traces/ir_nec.trace, by sigrok's ir_nec:ir=OUT0:polarity=active-high:cd_freq=38000
      ir_nec=bit:agc-pulse:longpause:shortpause:stop-bit:leader-code:addr:addr-inv:cmd:cmd-inv:repeat-code:remote: ir_nec-1: AGC pulse, ir_nec-1: Long pause, ir_nec-1: Leader code, ir_nec-1: 1, ir_nec-1: 0, ir_nec-1: 0, ir_nec-1: 1, ir_nec-1: 1, ir_nec-1: 0, ir_nec-1: 1, ir_nec-1: 0, ir_nec-1: Address: 0x59, ir_nec-1: 0, ir_nec-1: 1, ir_nec-1: 1, ir_nec-1: 0, ir_nec-1: 0, ir_nec-1: 1, ir_nec-1: 0, ir_nec-1: 1, ir_nec-1: Address#: 0xA6, ir_nec-1: 0, ir_nec-1: 1, ir_nec-1: 1, ir_nec-1: 0, ir_nec-1: 1, ir_nec-1: 0, ir_nec-1: 0, ir_nec-1: 0, ir_nec-1: Command: 0x16, ir_nec-1: 1, ir_nec-1: 0, ir_nec-1: 0, ir_nec-1: 1, ir_nec-1: 0, ir_nec-1: 1, ir_nec-1: 1, ir_nec-1: 1, ir_nec-1: Command#: 0xE9, ir_nec-1: Stop bit, ir_nec-1: Unknown device: Unknown, ir_nec-1: AGC pulse, ir_nec-1: Short pause, ir_nec-1: Stop bit, ir_nec-1: Repeat code

    === tlc5620

    certificates
    tlc5620: 27 words, 7 deadline waits, worst slack 16, the kernel accepts it, assuming no wrap

    limits
    tlc5620            CLK frequency, at most 1 MHz >=     1000 ns  run    60 (1250.0 ns)    needs   49       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Setup time, data input, tsu(DATA-CLK) >=       50 ns  kernel 40 (833.3 ns)     needs    4       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Valid time, data input valid after CLK falls, tv(DATA-CLK) >=       50 ns  kernel 20 (416.7 ns)     needs    4       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Setup time, CLK eleventh falling edge to LOAD, tsu(CLK-LOAD) >=       50 ns  kernel 20 (416.7 ns)     needs    4       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Setup time, LOAD rises to CLK falls, tsu(LOAD-CLK) >=       50 ns  kernel 69 (1437.5 ns)    needs    4       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Pulse duration, LOAD, tw(LOAD) >=      250 ns  kernel 20 (416.7 ns)     needs   13       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Pulse duration, LDAC, tw(LDAC) >=      250 ns  kernel 20 (416.7 ns)     needs   13       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle

    lockstep: tlc5620, tlc5620
    ("lockstep held" (cycles 4000))
    (received ())
    decode: test/traces/tlc5620.trace, by sigrok's tlc5620:clk=OUT0:data=OUT3:load=OUT1:ldac=OUT2
      tlc5620=dac-select:gain:value:bit:data-latch:reg-write:voltage-update-all: tlc5620-1: DAC select: DACA, tlc5620-1: Gain: x1, tlc5620-1: DAC value: 128, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 1, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: Falling edge on LOAD, tlc5620-1: Setting DACA register value to 1.65V, tlc5620-1: DAC select: DACB, tlc5620-1: Gain: x2, tlc5620-1: DAC value: 64, tlc5620-1: 0, tlc5620-1: 1, tlc5620-1: 1, tlc5620-1: 0, tlc5620-1: 1, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: Falling edge on LOAD, tlc5620-1: Setting DACB register value to 1.65V, tlc5620-1: DAC select: DACC, tlc5620-1: Gain: x1, tlc5620-1: DAC value: 255, tlc5620-1: 1, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 1, tlc5620-1: 1, tlc5620-1: 1, tlc5620-1: 1, tlc5620-1: 1, tlc5620-1: 1, tlc5620-1: 1, tlc5620-1: 1, tlc5620-1: Falling edge on LOAD, tlc5620-1: Setting DACC register value to 3.29V, tlc5620-1: DAC select: DACD, tlc5620-1: Gain: x1, tlc5620-1: DAC value: 1, tlc5620-1: 1, tlc5620-1: 1, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 0, tlc5620-1: 1, tlc5620-1: Falling edge on LOAD, tlc5620-1: Setting DACD register value to 0.01V, tlc5620-1: Updating voltages: DACA=1.65V DACB=1.65V DACC=3.29V DACD=0.01V

    === modbus_rtu

    certificates
    modbus_rtu: 28 words, 6 deadline waits, worst slack 2496, the kernel accepts it, assuming period 2500, no wrap

    limits
    modbus_rtu         silent interval between frames, t3,5 >= 2.00521e+06 ns  run    97511 (2031479.2 ns) needs 96251       MODBUS RTU, Modbus.org, MODBUS over Serial Line Specification and Implementation Guide V1.02, 20 December 2006 2.5.1.1, p.13; margin a cycle
    modbus_rtu         silent interval between characters of a frame, t1,5 <=   859375 ns  run    5 (104.2 ns)      needs 41249       MODBUS RTU, Modbus.org, MODBUS over Serial Line Specification and Implementation Guide V1.02, 20 December 2006 2.5.1.1, p.13; margin a cycle

    lockstep: modbus_rtu, modbus_rtu
    ("lockstep held" (cycles 660000))
    (received ())
    decode: test/traces/modbus_rtu.trace, by sigrok's uart:tx=OUT0:baudrate=19200:parity=even,modbus
      uart=tx-data: uart-1: 01, uart-1: 03, uart-1: 00, uart-1: 00, uart-1: 00, uart-1: 0A, uart-1: C5, uart-1: CD, uart-1: 11, uart-1: 06, uart-1: 00, uart-1: 01, uart-1: 00, uart-1: 03, uart-1: 9A, uart-1: 9B
      modbus=cs-server-id:cs-function:cs-crc:cs-address:cs-data:cs-length: modbus-1: Slave ID: 1, modbus-1: Function 3: Read Holding Registers, modbus-1: Start at address 0x0 / 30001, modbus-1: Read 10 units of data, modbus-1: CRC correct, modbus-1: Slave ID: 17, modbus-1: Function 6: Write Single Register, modbus-1: Address 0x1 / 30001, modbus-1: Register Value 0x3 / 3, modbus-1: CRC correct

    === avr_isp

    certificates
    avr_isp: 47 words, 3 deadline waits, worst slack 16, the kernel accepts it, assuming no wrap

    limits
    avr_isp            SCK high, more than 2 CPU clock cycles >=     2000 ns  kernel 149 (3104.2 ns)   needs   97       ATmega48/88/168, shipped at 1 MHz, Atmel, ATmega48/V / 88/V / 168/V datasheet complete, Atmel-2545W, November 2016 section 32.8, p.378; margin a cycle
    avr_isp            SCK low, more than 2 CPU clock cycles >=     2000 ns  kernel 151 (3145.8 ns)   needs   97       ATmega48/88/168, shipped at 1 MHz, Atmel, ATmega48/V / 88/V / 168/V datasheet complete, Atmel-2545W, November 2016 section 32.8, p.378; margin a cycle
    avr_isp            wait after power-up, RESET and SCK low, before programming enable >=    2e+07 ns  run    983230 (20483958.3 ns) needs 960001       ATmega48/88/168, shipped at 1 MHz, Atmel, ATmega48/V / 88/V / 168/V datasheet complete, Atmel-2545W, November 2016 section 32.8.2 step 2, p.379; margin a cycle

    lockstep: avr_isp, avr_isp
    ("lockstep held" (cycles 1100000))
    (received (0x5300 0x1e 0x93 0xa 0x62))
    decode: test/traces/avr_isp.trace, by sigrok's spi:clk=OUT0:mosi=OUT3:miso=IN0,avr_isp
      spi=mosi-data: spi-1: AC, spi-1: 53, spi-1: 00, spi-1: 00, spi-1: 30, spi-1: 00, spi-1: 00, spi-1: 00, spi-1: 30, spi-1: 00, spi-1: 01, spi-1: 00, spi-1: 30, spi-1: 00, spi-1: 02, spi-1: 00, spi-1: 50, spi-1: 00, spi-1: 00, spi-1: 00
      spi=miso-data: spi-1: 00, spi-1: AC, spi-1: 53, spi-1: 00, spi-1: 00, spi-1: 30, spi-1: 00, spi-1: 1E, spi-1: 00, spi-1: 30, spi-1: 00, spi-1: 93, spi-1: 00, spi-1: 30, spi-1: 00, spi-1: 0A, spi-1: 00, spi-1: 50, spi-1: 00, spi-1: 62
      avr_isp=pe:rsb0:rsb1:rsb2:rfb:dev: avr_isp-1: Programming enable, avr_isp-1: Vendor code: 0x1e (Atmel), avr_isp-1: Part family / memory size: 0x93, avr_isp-1: Part number: 0x0a, avr_isp-1: Device: Atmel ATmega88, avr_isp-1: Read fuse bits: 0x62

    === midi

    certificates
    midi: 17 words, 3 deadline waits, worst slack 1532, the kernel accepts it, assuming period 1536, no wrap

    limits
    midi               bit at 31.25 kbaud +1% >=  31683.2 ns  kernel 1536 (32000.0 ns) needs 1522       MIDI 1.0, MMA, CA-033 MIDI 1.0 Electrical Specification Update, issued 1 August 2014 page 2, Hardware; margin a cycle
    midi               bit at 31.25 kbaud -1% <=  32323.2 ns  run    1536 (32000.0 ns) needs 1550       MIDI 1.0, MMA, CA-033 MIDI 1.0 Electrical Specification Update, issued 1 August 2014 page 2, Hardware; margin a cycle

    lockstep: midi, midi
    ("lockstep held" (cycles 215040))
    (received ())
    decode: test/traces/midi.trace, by sigrok's uart:tx=OUT0:baudrate=31250,midi
      uart=tx-data: uart-1: 90, uart-1: 3C, uart-1: 40, uart-1: 3E, uart-1: 40, uart-1: 80, uart-1: 3C, uart-1: 00, uart-1: C0, uart-1: 05, uart-1: B0, uart-1: 07, uart-1: 64
      midi=text-verbose: midi-1: Channel 1: note on (note = 60 'C4', velocity = 64), midi-1: Channel 1: note on (note = 62 'D4', velocity = 64), midi-1: Channel 1: note off (note = 60 'C4', velocity = 0), midi-1: Channel 1: program change to instrument 6 (assuming Electric Piano 2), midi-1: Channel 1: control change 'channel volume MSB (formerly main volume)' (param = 0x64)
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

(* each limit, reason for no limit and sweep decision must name the protocol's own
   firmware *)
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
   limit, reason or bench copy that says TODO, and a run sigrok judges with no payload to
   read. *)
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
