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
  List.iter p.scenarios ~f:(fun (scenario : Pin_trace.Scenario.t) ->
    printf "\nlockstep: %s, %s\n" scenario.name (Protocol.firmware p scenario).name;
    let received = Protocol.lockstep p scenario in
    print_s [%message (received : Int.Hex.t list)];
    Option.iter scenario.sigrok ~f:(fun sigrok ->
      printf "decode: test/traces/%s.trace, by sigrok's" scenario.name;
      List.iter sigrok.decoders ~f:(printf " %s");
      print_endline "";
      List.iter sigrok.expect ~f:(fun (annotations, lines) ->
        printf "  %s: %s\n" annotations (String.concat ~sep:", " lines))))
;;

(* A protocol added as a file of its own shows up here with nothing else to write. *)
let%expect_test "every protocol from its file to the decoded trace" =
  List.iter Library.protocols ~f:(fun p ->
    if not (phys_equal p Library.rest)
    then (
      printf "=== %s\n\n" p.name;
      end_to_end p;
      print_endline ""));
  [%expect
    {|
    === uart

    certificates
    uart_tx: 15 words, 3 deadline waits, worst slack 4, the kernel accepts it, assuming nothing
    uart_tx16: 15 words, 3 deadline waits, worst slack 12, the kernel accepts it, assuming nothing
    uart_tx_host_rate: 17 words, 3 deadline waits, worst slack 430, the kernel accepts it, assuming period 434, a load of 4 or more, no wrap
    uart_rx: 19 words, 2 deadline waits, worst slack 7, the kernel accepts it, assuming one edge before capture, no wrap
    uart_tx_stream: 13 words, 3 deadline waits, worst slack 4, the kernel accepts it, assuming nothing

    limits
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
    spi_master: none, no demo loads it

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

    limits
    i2c_master         THIGH          >=      600 ns  kernel 96 (2000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 2; margin 300 ns, TR, param 4
    i2c_master         TLOW           >=     1300 ns  kernel 96 (2000.0 ns)    needs   64       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 3; margin a cycle
    i2c_master         THD:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   30       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 6; margin a cycle
    i2c_master         TSU:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 7; margin 300 ns, TR, param 4
    i2c_master         TSU:DAT        >=      100 ns  kernel 47 (979.2 ns)     needs   20       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 9; margin 300 ns, TR, param 4
    i2c_master         TSU:STO        >=      600 ns  kernel 48 (1000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 10; margin 300 ns, TR, param 4
    i2c_master         TBUF           >=     1300 ns  kernel 149 (3104.2 ns)   needs   77       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 14; margin 300 ns, TR, param 4
    i2c_master_stretch THIGH          >=      600 ns  kernel 96 (2000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 2; margin 300 ns, TR, param 4
    i2c_master_stretch TLOW           >=     1300 ns  kernel 96 (2000.0 ns)    needs   64       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 3; margin a cycle
    i2c_master_stretch THD:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   30       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 6; margin a cycle
    i2c_master_stretch TSU:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 7; margin 300 ns, TR, param 4
    i2c_master_stretch TSU:DAT        >=      100 ns  kernel 47 (979.2 ns)     needs   20       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 9; margin 300 ns, TR, param 4
    i2c_master_stretch TSU:STO        >=      600 ns  kernel 48 (1000.0 ns)    needs   44       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 10; margin 300 ns, TR, param 4
    i2c_master_stretch TBUF           >=     1300 ns  kernel 105 (2187.5 ns)   needs   77       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 14; margin 300 ns, TR, param 4

    lockstep: i2c_logger, i2c_logger
    ("lockstep held" (cycles 3000))
    (received ())
    decode: test/traces/i2c_logger.trace, by sigrok's i2c:scl=IO1:sda=IO0 uart:tx=OUT0:baudrate=3000000
      i2c=start:address-read:ack:data-read:nack:stop: i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 10, i2c-1: NACK, i2c-1: Stop, i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 21, i2c-1: NACK, i2c-1: Stop, i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 32, i2c-1: NACK, i2c-1: Stop, i2c-1: Start, i2c-1: Read, i2c-1: Address read: 50, i2c-1: ACK, i2c-1: Data read: 43, i2c-1: NACK, i2c-1: Stop
      uart=tx-data: uart-1: 10, uart-1: 21, uart-1: 32, uart-1: 43

    === spi_cs

    certificates: none

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
          (repeated
             (List.map (Pin_scenarios.all @ Sigrok_scenarios.all) ~f:(fun s -> s.name))
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
  [%expect {| |}]
;;
