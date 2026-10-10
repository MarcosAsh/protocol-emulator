open! Core
open Protocol_emulator

let fails (bench : Bench.t) =
  let verdicts =
    Datasheet.check Library.limits bench
    |> List.filter ~f:(fun (_, (v : Datasheet.Verdict.t)) -> not v.ok)
  in
  print_endline (Datasheet.to_string bench verdicts)
;;

(* Each kernel bound is the most cycles the kernel accepts, so one more is refused. *)
let%expect_test "the bench firmware against its datasheet limits" =
  List.iter (Library.bench @ [ Uart.log ]) ~f:(fun bench ->
    match Datasheet.check Library.limits bench with
    | [] -> ()
    | verdicts -> print_endline (Datasheet.to_string bench verdicts));
  [%expect
    {|
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
    i2c_standard       THIGH          >=     4000 ns  kernel 242 (5041.7 ns)   needs  240       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; margin 1000 ns, tr
    i2c_standard       TLOW           >=     4700 ns  kernel 242 (5041.7 ns)   needs  227       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; margin a cycle
    i2c_standard       THD:STA        >=     4000 ns  kernel 362 (7541.7 ns)   needs  193       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; margin a cycle
    i2c_standard       TSU:STA        >=     4700 ns  kernel 363 (7562.5 ns)   needs  274       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; margin 1000 ns, tr
    i2c_standard       TSU:DAT        >=      250 ns  kernel 120 (2500.0 ns)   needs   60       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; margin 1000 ns, tr
    i2c_standard       TSU:STO        >=     4000 ns  kernel 363 (7562.5 ns)   needs  240       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; margin 1000 ns, tr
    i2c_standard       TBUF           >=     4700 ns  kernel 368 (7666.7 ns)   needs  274       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; margin 1000 ns, tr
    i2c_standard       1/fSCL         >=    10000 ns  run    484 (10083.3 ns)  needs  481       I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10, fSCL; margin a cycle
    i2c_fast           THIGH          >=      600 ns  kernel 64 (1333.3 ns)    needs   44       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 10; margin 300 ns, tr
    i2c_fast           TLOW           >=     1300 ns  kernel 64 (1333.3 ns)    needs   64       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 10; margin a cycle
    i2c_fast           THD:STA        >=      600 ns  kernel 64 (1333.3 ns)    needs   30       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 10; margin a cycle
    i2c_fast           TSU:STA        >=      600 ns  kernel 64 (1333.3 ns)    needs   44       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 10; margin 300 ns, tr
    i2c_fast           TSU:DAT        >=      100 ns  kernel 31 (645.8 ns)     needs   20       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 10; margin 300 ns, tr
    i2c_fast           TSU:STO        >=      600 ns  kernel 64 (1333.3 ns)    needs   44       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 10; margin 300 ns, tr
    i2c_fast           TBUF           >=     1300 ns  kernel 101 (2104.2 ns)   needs   77       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 10; margin 300 ns, tr
    i2c_fast           1/fSCL         >=     2500 ns  run    128 (2666.7 ns)   needs  121       I2C Fast-mode, NXP UM10204 Rev. 7.0 Table 10, fSCL; margin a cycle
    sk6812             T0H            >=      200 ns  kernel 17 (354.2 ns)     needs   11       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; margin a cycle
    sk6812             T0H            <=      400 ns  run    17 (354.2 ns)     needs   18       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; margin a cycle
    sk6812             T1H            >=      600 ns  run    34 (708.3 ns)     needs   30       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; margin a cycle
    sk6812             T1H            <=      750 ns  run    34 (708.3 ns)     needs   35       SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15; margin a cycle
    sk6812             T0L            >=      800 ns  run    42 (875.0 ns)     needs   40       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; margin a cycle
    sk6812             T0L            <=     1050 ns  run    42 (875.0 ns)     needs   49       SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15; margin a cycle
    sk6812             T1L            >=      450 ns  kernel 25 (520.8 ns)     needs   23       SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15; margin a cycle
    sk6812             T1L            <=      750 ns  run    25 (520.8 ns)     needs   35       SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15; margin a cycle
    sk6812             T              >=     1200 ns  run    59 (1229.2 ns)    needs   59       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7, note 2; margin a cycle
    sk6812             reset          >=   200000 ns  run    10907 (227229.2 ns) needs 9601       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; margin a cycle
    one_wire           tLOW1          >=     1000 ns  kernel 288 (6000.0 ns)   needs   49       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tLOW1          <=    15000 ns  run    288 (6000.0 ns)   needs  719       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tLOW0          >=    60000 ns  run    3168 (66000.0 ns) needs 2881       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tLOW0          <=   120000 ns  run    3168 (66000.0 ns) needs 5759       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tREC           >=     1000 ns  kernel 288 (6000.0 ns)   needs   49       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tSLOT + tREC   >=    61000 ns  run    3456 (72000.0 ns) needs 2929       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tRSTL          >=   480000 ns  run    24194 (504041.7 ns) needs 23041       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tRSTH          >=   480000 ns  run    23336 (486166.7 ns) needs 23041       DS18B20, Maxim REV 042208 p.20; margin a cycle
    can                recessive      >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can                dominant       >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can                idle to SOF    >=    22000 ns  run    1165 (24270.8 ns) needs 1057       CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits; margin a cycle
    can_sender         recessive      >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can_sender         dominant       >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can_sender         idle to SOF    >=    22000 ns  run    1165 (24270.8 ns) needs 1057       CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits; margin a cycle
    can_receiver       ACK            >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
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
    swd                SWCLK high     >=  20.8333 ns  kernel 7 (145.8 ns)      needs    2       RP2040, RP2040 datasheet, 2025-02-20 s.2.3.4 p.61; margin a cycle
    swd                SWCLK low      >=  20.8333 ns  kernel 24 (500.0 ns)     needs    2       RP2040, RP2040 datasheet, 2025-02-20 s.2.3.4 p.61; margin a cycle
    uart_log           bit            >=  8506.94 ns  kernel 417 (8687.5 ns)   needs  410       UART at 115200 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_log           bit            <=  8854.17 ns  run    417 (8687.5 ns)   needs  424       UART at 115200 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    |}]
;;

let%expect_test "every bench firmware has its limits, or a reason it has none" =
  let names =
    List.map (Uart.log :: Library.bench) ~f:(fun bench -> bench.name)
    |> String.Set.of_list
  in
  let limited = List.map Library.limits ~f:(fun t -> t.firmware) |> String.Set.of_list in
  let exempt = List.map Library.exempt ~f:fst |> String.Set.of_list in
  print_s
    [%message
      ""
        ~missing:(Set.diff names (Set.union limited exempt) : String.Set.t)
        ~unknown:(Set.diff (Set.union limited exempt) names : String.Set.t)
        ~both:(Set.inter limited exempt : String.Set.t)];
  [%expect {| ((missing ()) (unknown ()) (both ())) |}];
  (* the tooth: a new demo's firmware with no limits does not build *)
  let unlimited = { (Library.find_bench_exn "sk6812") with name = "new_demo" } in
  print_s
    [%sexp
      (Or_error.try_with (fun () ->
         Datasheet.check_exn Library.limits ~exempt:Library.exempt unlimited)
       : unit Or_error.t)];
  [%expect {| (Error ("no datasheet limits, and no reason why" new_demo)) |}]
;;

let before name ~source = { (Library.find_bench_exn name) with source }

let undo (bench : Bench.t) ~fix ~was =
  let source = bench.source in
  if not (String.is_substring source ~substring:fix)
  then raise_s [%message "BUG: the fix has moved" bench.name];
  { bench with source = String.substr_replace_first source ~pattern:fix ~with_:was }
;;

(* The teeth: the firmware each fix replaced fails its limits, the DS18B20's zero for
   sitting exactly on 60 us, the SK6812's T0L for missing 800 ns by less than a cycle. *)
let%expect_test "the firmware before each fix fails" =
  List.iter
    ~f:fails
    [ before "sk6812" ~source:(Ws2812.firmware ~third:16 ~tail:7)
    ; undo
        (Library.find_bench_exn "one_wire")
        ~fix:"    set y, 7\nhold:"
        ~was:"    set y, 6\nhold:"
    ; before "can" ~source:(Timed_program.source Can.firmware)
    ; before "can_sender" ~source:(Timed_program.source Can_node.Sender.firmware)
    ; before
        "spi_cs_mode0"
        ~source:
          (Spi_cs.master
             ~mode:(Spi_cs.Mode.of_int 0)
             ~half_period:8
             ~setup:4
             ~hold:8
             ~deselect:0)
    ; List.fold
        [ "                ; a quarter, for an SCL let go after the last poll\n"; "\n" ]
        ~init:(Library.find_bench_exn "i2c_master_stretch")
        ~f:(fun bench comment ->
          undo
            bench
            ~fix:
              ("    mov t, now side 0\n    add t, p side 0\n    wait t side 0" ^ comment)
            ~was:"")
    ];
  [%expect
    {|
    sk6812             T0L            >=      800 ns  run    39 (812.5 ns)     needs   40 FAIL  SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; margin a cycle
    sk6812             T              >=     1200 ns  run    55 (1145.8 ns)    needs   59 FAIL  SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7, note 2; margin a cycle
    sk6812             reset          >=   200000 ns  run    2584 (53833.3 ns) needs 9601 FAIL  SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; margin a cycle
    one_wire           tLOW0          >=    60000 ns  run    2880 (60000.0 ns) needs 2881 FAIL  DS18B20, Maxim REV 042208 p.20; margin a cycle
    can                idle to SOF    >=    22000 ns  run    103 (2145.8 ns)   needs 1057 FAIL  CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits; margin a cycle
    can_sender         idle to SOF    >=    22000 ns  run    103 (2145.8 ns)   needs 1057 FAIL  CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits; margin a cycle
    spi_cs_mode0       tRES1          >=     3000 ns  kernel 9 (187.5 ns)      needs  145 FAIL  W25Q64JV, Winbond Rev. M p.65; margin a cycle
    i2c_master_stretch TSU:STO        >=      600 ns  kernel 7 (145.8 ns)      needs   44 FAIL  24LC256, Microchip DS20001203W, Table 1-2 p.3, param 10; margin 300 ns, TR, param 4
    |}]
;;

(* The tooth: 434 cycles, the bit at 115200 baud from the chip's rated 50 MHz, is outside
   a receiver's 2% at the 48 MHz the firmware runs at, as the label from the clock says. *)
let%expect_test "a rate comes from the clock it runs at" =
  let fifty_mhz = { Uart.log with load = Some (50_000_000 / 115_200) } in
  print_endline (Datasheet.to_string fifty_mhz (Datasheet.check Library.limits fifty_mhz));
  print_endline (Bench.rate ~unit:"baud" 434);
  [%expect {|
    uart_log           bit            >=  8506.94 ns  kernel 434 (9041.7 ns)   needs  410       UART at 115200 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    uart_log           bit            <=  8854.17 ns  run    434 (9041.7 ns)   needs  424 FAIL  UART at 115200 baud, Maxim AN2141 p.4, +-3/152, 2%; margin a cycle
    110.6 kbaud
    |}]
;;

(* The clock the limits are checked at is the one both boards run the chip at. *)
let%expect_test "the bench's clock is the boards'" =
  let find file pattern =
    Re.Group.get (Re.exec (Re.Perl.compile_pat pattern) (In_channel.read_all file)) 1
    |> Int.of_string
  in
  print_s
    [%message
      ""
        ~bench:(Uart.log.clock_hz : int)
        ~demo_board:(find "../python/demo_board.py" {|clock_hz=([0-9_]+)|} : int)
        ~icepi:(find "../icepi/Makefile" {|MHZ \?= ([0-9]+)|} * 1_000_000 : int)];
  [%expect {| ((bench 48000000) (demo_board 48000000) (icepi 48000000)) |}]
;;
