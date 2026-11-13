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
    sk6812             T0H            >=      250 ns  kernel 17 (354.2 ns)     needs   13       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T0H            <=      400 ns  run    17 (354.2 ns)     needs   18       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T1H            >=      650 ns  run    34 (708.3 ns)     needs   33       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T1H            <=     1000 ns  run    34 (708.3 ns)     needs   47       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T0L            >=      800 ns  run    42 (875.0 ns)     needs   40       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T1L            >=      200 ns  kernel 25 (520.8 ns)     needs   11       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T              >=     1200 ns  run    59 (1229.2 ns)    needs   59       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7, note 2; margin a cycle
    sk6812             reset          >=   200000 ns  run    10907 (227229.2 ns) needs 9601       SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    one_wire           tLOW1          >=     1000 ns  kernel 288 (6000.0 ns)   needs   49       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tLOW1          <=    15000 ns  run    288 (6000.0 ns)   needs  719       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tLOW0          >=    60000 ns  run    3168 (66000.0 ns) needs 2881       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tLOW0          <=   120000 ns  run    3168 (66000.0 ns) needs 5759       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tREC           >=     1000 ns  kernel 288 (6000.0 ns)   needs   49       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tSLOT + tREC   >=    61000 ns  run    3456 (72000.0 ns) needs 2929       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tRSTL          >=   480000 ns  run    24194 (504041.7 ns) needs 23041       DS18B20, Maxim REV 042208 p.20; margin a cycle
    one_wire           tRSTH          >=   480000 ns  run    23336 (486166.7 ns) needs 23041       DS18B20, Maxim REV 042208 p.20; margin a cycle
    ps2                data to CLK fall >=     5000 ns  kernel 957 (19937.5 ns)  needs  241       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T1; margin a cycle
    ps2                CLK rise to data >=     5000 ns  kernel 960 (20000.0 ns)  needs  241       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T2; margin a cycle
    ps2                CLK low        >=    30000 ns  kernel 1920 (40000.0 ns) needs 1441       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T3; margin a cycle
    ps2                CLK low        <=    50000 ns  run    1920 (40000.0 ns) needs 2399       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T3; margin a cycle
    ps2                CLK high       >=    30000 ns  run    1920 (40000.0 ns) needs 1441       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T4; margin a cycle
    ps2                CLK high       <=    50000 ns  run    1920 (40000.0 ns) needs 2399       PS/2 keyboard and auxiliary device, IBM Personal System/2 Hardware Interface Technical Reference, May 1988 Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T4; margin a cycle
    can                recessive      >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can                dominant       >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can                idle to SOF    >=    22000 ns  run    1165 (24270.8 ns) needs 1057       CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits; margin a cycle
    can_sender         recessive      >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can_sender         dominant       >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
    can_sender         idle to SOF    >=    22000 ns  run    1165 (24270.8 ns) needs 1057       CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits; margin a cycle
    can_receiver       ACK            >=     1000 ns  kernel 96 (2000.0 ns)    needs   49       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps; margin a cycle
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
    caliper            clock high at 90 kHz >=   5555.5 ns  kernel 270 (5625.0 ns)   needs  268       Chinese digital scale, Chinese Scales web page, no revision Chinese Scale Protocol, page 1, lines 52-54; margin a cycle
    caliper            clock low at 90 kHz >=   5555.5 ns  kernel 270 (5625.0 ns)   needs  268       Chinese digital scale, Chinese Scales web page, no revision Chinese Scale Protocol, page 1, lines 52-54; margin a cycle
    caliper            pause before the first word >=    55000 ns  run    2705 (56354.2 ns) needs 2641       Chinese digital scale, Chinese Scales web page, no revision Chinese Scale Protocol, page 1, lines 82-84; margin a cycle
    caliper            pause between the words >=   110000 ns  run    5400 (112500.0 ns) needs 5281       Chinese digital scale, Chinese Scales web page, no revision Chinese Scale Protocol, page 1, lines 82-84; margin a cycle
    caliper            pause after the last word >=    55000 ns  run    5408 (112666.7 ns) needs 2641       Chinese digital scale, Chinese Scales web page, no revision Chinese Scale Protocol, page 1, lines 82-84; margin a cycle
    xy2_100            tDS            >=       50 ns  kernel 12 (250.0 ns)     needs    4       rhothor X7, Newson XY2-100 I/O configuration, Rev. 0703 Timing specifications table, p.2; margin a cycle
    xy2_100            tDH            >=      100 ns  kernel 12 (250.0 ns)     needs    6       rhothor X7, Newson XY2-100 I/O configuration, Rev. 0703 Timing specifications table, p.2; margin a cycle
    lfast              data rate, shortest high bit (3.125 ns) >=    3.125 ns  kernel 10 (208.3 ns)     needs    2       LFAST, NXP AN5134 Rev. 0 p.3, text: rates up to 320 Mb/s; margin a cycle
    lfast              data rate, shortest low bit (3.125 ns) >=    3.125 ns  kernel 10 (208.3 ns)     needs    2       LFAST, NXP AN5134 Rev. 0 p.3, text: rates up to 320 Mb/s; margin a cycle
    dali               idle after a frame >= 2.45e+06 ns  run    540010 (11250208.3 ns) needs 117601       DALI, Wikipedia, Digital Addressable Lighting Interface, oldid 1363488623 p.1, line 178; margin a cycle
    dali               40 commands a second, forward frames 25 ms apart >=  2.5e+07 ns  run    1220010 (25416875.0 ns) needs 1200001       DALI, Wikipedia, Digital Addressable Lighting Interface, oldid 1363488623 p.1, line 188; margin a cycle
    lin                break field    >=   677083 ns  run    33750 (703125.0 ns) needs 32501       LIN master, LIN Specification Package Revision 2.2A 2.3.1.1, p. 30; margin a cycle
    lin                break delimiter >=  52083.3 ns  run    3750 (78125.0 ns) needs 2501       LIN master, LIN Specification Package Revision 2.2A 2.3.1.1, p. 30; margin a cycle
    lin                break field length (dominant + delimiter) >=   729167 ns  run    37500 (781250.0 ns) needs 35002       LIN master, LIN Specification Package Revision 2.2A Table 2.3, p. 52; margin a cycle
    lin                THeader_Maximum, 1.4 * THeader_Nominal of 34 TBit <= 2.47917e+06 ns  run    87500 (1822916.7 ns) needs 118999       LIN master, LIN Specification Package Revision 2.2A 2.3.2 eq. (3), p. 32, eq. (6), p. 33; margin a cycle
    lin                FTOL_RES_MASTER, bit >=  51822.9 ns  run    2500 (52083.3 ns) needs 2489       LIN master, LIN Specification Package Revision 2.2A Table 6.1, p. 113; margin a cycle
    lin                FTOL_RES_MASTER, bit <=  52343.8 ns  run    2500 (52083.3 ns) needs 2511       LIN master, LIN Specification Package Revision 2.2A Table 6.1, p. 113; margin a cycle
    lin                bit rate, 20 kbit/s >=    50000 ns  run    2500 (52083.3 ns) needs 2401       LIN master, LIN Specification Package Revision 2.2A 6.3, p. 112; margin a cycle
    lin                bit rate, 1 kbit/s <=    1e+06 ns  run    2500 (52083.3 ns) needs 47999       LIN master, LIN Specification Package Revision 2.2A 6.3, p. 112; margin a cycle
    spdif              a block of 192 frames, 44.1 kHz and 1100 ppm >= 4.34896e+06 ns  run    208979 (4353729.2 ns) needs 208751       S/PDIF, IEC 60958 type II, Wikipedia, S/PDIF, revision 1378032122 (2 October 2026) p.1, S/PDIF control word components, byte 3, spec.txt l.222-224; margin a cycle
    spdif              a block of 192 frames, 44.1 kHz less 1100 ppm <= 4.35854e+06 ns  run    208979 (4353729.2 ns) needs 209208       S/PDIF, IEC 60958 type II, Wikipedia, S/PDIF, revision 1378032122 (2 October 2026) p.1, S/PDIF control word components, byte 3, spec.txt l.222-224; margin a cycle
    spdif              a frame, Mode 0's 192 kHz at most >=  5208.33 ns  run    1088 (22666.7 ns) needs  251       S/PDIF, IEC 60958 type II, Wikipedia, S/PDIF, revision 1378032122 (2 October 2026) p.1, text, spec.txt l.180; margin a cycle
    usb_power_delivery fBitRate max 330 kbps: each bit cell >=   3030.3 ns  run    160 (3333.3 ns)   needs  147       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.9, p.110; margin a cycle
    usb_power_delivery fBitRate min 270 kbps: each bit cell <=   3703.7 ns  run    160 (3333.3 ns)   needs  176       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.9, p.110; margin a cycle
    usb_power_delivery tUnitInterval min >=     3030 ns  run    160 (3333.3 ns)   needs  147       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.9, p.110; margin a cycle
    usb_power_delivery tUnitInterval max <=     3700 ns  run    160 (3333.3 ns)   needs  176       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.9, p.110; margin a cycle
    usb_power_delivery pBitRate 0.25 %: 32 bits against the preamble's last 32, of 32 UI at 300 kbps <=  266.667 ns  run    0 (0.0 ns)        needs   11       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.10, p.110, and 5.3.4.8 p.108; 300 kbps nominal, Table 5.9; margin a cycle
    usb_power_delivery tHoldLowBMC: every low >=     1000 ns  kernel 80 (1666.7 ns)    needs   49       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.10, p.110; margin a cycle
    usb_power_delivery tInterFrameGap: each idle low >=    25000 ns  run    1367 (28479.2 ns) needs 1201       USB PD BMC transmitter, USB Power Delivery Specification r3.2 v1.2, Aug 2026 Table 5.10, p.110; margin a cycle
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
    swd_blind          Trn            >=     1000 ns  kernel 50 (1041.7 ns)    needs   49       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 Table 2-10, p.2-52; margin a cycle
    swd_blind          line reset     >=    50000 ns  run    2910 (60625.0 ns) needs 2401       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 4.4.3, p.4-104; margin a cycle
    swd_blind          idle cycles    >=     2000 ns  run    394 (8208.3 ns)   needs   97       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 4.4.3, p.4-104; margin a cycle
    swd_blind          JTAG-to-SWD    >=    50000 ns  run    2758 (57458.3 ns) needs 2401       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 5.2.1, p.5-111; margin a cycle
    swd_blind          JTAG-to-DS     >=     5000 ns  run    548 (11416.7 ns)  needs  241       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 5.3.2, p.5-115; margin a cycle
    swd_blind          SWD-to-DS      >=    50000 ns  run    2758 (57458.3 ns) needs 2401       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 5.3.3, p.5-116; margin a cycle
    swd_blind          DS-to-SWD      >=    50000 ns  run    2758 (57458.3 ns) needs 2401       SW-DP, ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813 5.3.4, p.5-117; margin a cycle
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
    tlc5620            CLK frequency, at most 1 MHz >=     1000 ns  run    60 (1250.0 ns)    needs   49       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Setup time, data input, tsu(DATA-CLK) >=       50 ns  kernel 40 (833.3 ns)     needs    4       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Valid time, data input valid after CLK falls, tv(DATA-CLK) >=       50 ns  kernel 20 (416.7 ns)     needs    4       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Setup time, CLK eleventh falling edge to LOAD, tsu(CLK-LOAD) >=       50 ns  kernel 20 (416.7 ns)     needs    4       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Setup time, LOAD rises to CLK falls, tsu(LOAD-CLK) >=       50 ns  kernel 69 (1437.5 ns)    needs    4       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Pulse duration, LOAD, tw(LOAD) >=      250 ns  kernel 20 (416.7 ns)     needs   13       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    tlc5620            Pulse duration, LDAC, tw(LDAC) >=      250 ns  kernel 20 (416.7 ns)     needs   13       TLC5620C, TLC5620I, Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog Converters, SLAS081E, November 2001 p.6, recommended operating conditions; margin a cycle
    modbus_rtu         silent interval between frames, t3,5 >= 2.00521e+06 ns  run    97511 (2031479.2 ns) needs 96251       MODBUS RTU, Modbus.org, MODBUS over Serial Line Specification and Implementation Guide V1.02, 20 December 2006 2.5.1.1, p.13; margin a cycle
    modbus_rtu         silent interval between characters of a frame, t1,5 <=   859375 ns  run    5 (104.2 ns)      needs 41249       MODBUS RTU, Modbus.org, MODBUS over Serial Line Specification and Implementation Guide V1.02, 20 December 2006 2.5.1.1, p.13; margin a cycle
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

(* A certificate is only as strong as the limits it is held to. Each firmware's tightest
   limit on each side, as a share of its bound: under a half means it could run twice as
   fast, or half as fast, and still pass. *)
let%expect_test "firmware its limits do not hold within a factor of two" =
  let share (v : Datasheet.Verdict.t) =
    Option.map v.bound ~f:(fun bound ->
      match v.limit with
      | At_least _ -> Float.of_int v.needed /. Float.of_int bound
      | At_most _ -> Float.of_int bound /. Float.of_int v.needed)
  in
  let side (v : Datasheet.Verdict.t) =
    match v.limit with
    | At_least _ -> "faster"
    | At_most _ -> "slower"
  in
  List.iter (Uart.log :: Library.bench) ~f:(fun bench ->
    let rows =
      Datasheet.check Library.limits bench
      |> List.filter_map ~f:(fun ((t : Datasheet.t), v) ->
        Option.map (share v) ~f:(fun share -> share, t, v))
    in
    match rows with
    | [] ->
      printf
        "%-18s none   %s\n"
        bench.name
        (List.Assoc.find Library.exempt bench.name ~equal:String.equal
         |> Option.value ~default:"")
    | rows ->
      List.iter [ "faster"; "slower" ] ~f:(fun way ->
        let tightest =
          List.filter rows ~f:(fun (_, _, v) -> String.equal (side v) way)
          |> List.max_elt ~compare:(fun (a, _, _) (b, _, _) -> Float.compare a b)
        in
        match tightest with
        | Some (share, _, _) when Float.( >= ) share 0.5 -> ()
        | Some (share, t, v) ->
          printf
            "%-18s %s loose  %-24s needs %d of %d cycles (%.0f%%)\n"
            bench.name
            way
            t.parameter
            v.needed
            (Option.value_exn v.bound)
            (100. *. share)
        | None -> printf "%-18s %s unbounded\n" bench.name way));
  [%expect
    {|
    i2c_master         slower unbounded
    i2c_master_stretch slower unbounded
    start_hold         none   it drives no pin: it listens to Pico B's I2C
    i2c_standard       slower unbounded
    i2c_fast           slower unbounded
    i2c_standard_asym  slower unbounded
    i2c_fast_asym      slower unbounded
    ethernet           none   no demo on the bench: it needs the Icepi's 40 MHz build
    can                slower unbounded
    can_sender         slower unbounded
    can_receiver       slower unbounded
    spi_cs_mode0       slower unbounded
    spi_cs_mode1       slower unbounded
    spi_cs_mode2       slower unbounded
    spi_cs_mode3       slower unbounded
    swd                faster loose  SWCLK high               needs 2 of 7 cycles (29%)
    swd                slower unbounded
    nec_tx             none   no datasheet at hand; Nec.decode holds each mark and space to 5%
    nec_rx             none   a receiver: it samples, and drives nothing
    ir_rc6             none   the spec gives typical times and no minimum or maximum; Ir_rc6.decode holds each mark and space to 5%
    caliper            slower unbounded
    xy2_100            slower unbounded
    lfast              faster loose  data rate, shortest high bit (3.125 ns) needs 2 of 10 cycles (20%)
    lfast              slower unbounded
    tdm_audio          none   AN301 has no timing table: SCLK 12.288 MHz (p.2) is typical only, the example for 8 x 32-bit blocks at 48 kHz, with no minimum or maximum
    dali               slower unbounded
    wiegand            none   the spec, Wikipedia's Wiegand interface page, gives no pulse width, interval or any other timing
    swd_blind          slower unbounded
    ir_nec             slower unbounded
    tlc5620            slower unbounded
    modbus_rtu         slower loose  silent interval between characters of a frame, t1,5 needs 41249 of 5 cycles (0%)
    |}]
;;

let before name ~source = { (Library.find_bench_exn name) with source }

let undo (bench : Bench.t) ~fix ~was =
  let source = bench.source in
  if not (String.is_substring source ~substring:fix)
  then raise_s [%message "BUG: the fix has moved" bench.name];
  { bench with source = String.substr_replace_first source ~pattern:fix ~with_:was }
;;

(* The teeth: the firmware each fix replaced fails its limits. The DS18B20's zero sat
   exactly on 60 us, and the SK6812's T0L missed 800 ns by less than a cycle. *)
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
    sk6812             T1H            >=      650 ns  run    32 (666.7 ns)     needs   33 FAIL  SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T0L            >=      800 ns  run    39 (812.5 ns)     needs   40 FAIL  SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    sk6812             T              >=     1200 ns  run    55 (1145.8 ns)    needs   59 FAIL  SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7, note 2; margin a cycle
    sk6812             reset          >=   200000 ns  run    2584 (53833.3 ns) needs 9601 FAIL  SK6812, OSK-SPC-SK6812-012 Rev. B/1 p.7; margin a cycle
    one_wire           tLOW0          >=    60000 ns  run    2880 (60000.0 ns) needs 2881 FAIL  DS18B20, Maxim REV 042208 p.20; margin a cycle
    can                idle to SOF    >=    22000 ns  run    103 (2145.8 ns)   needs 1057 FAIL  CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits; margin a cycle
    can_sender         idle to SOF    >=    22000 ns  run    103 (2145.8 ns)   needs 1057 FAIL  CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits; margin a cycle
    spi_cs_mode0       tRES1          >=     3000 ns  kernel 9 (187.5 ns)      needs  145 FAIL  W25Q64JV, Winbond Rev. M p.65; margin a cycle
    i2c_master_stretch TSU:STO        >=      600 ns  kernel 7 (145.8 ns)      needs   44 FAIL  24LC256, Microchip DS20001203W, Table 1-2 p.4, param 10; margin 300 ns, TR, param 4
    |}]
;;

(* The tooth: 434 cycles is the bit at 115200 baud from the chip's rated 50 MHz, and is
   outside a receiver's 2% at the 48 MHz the firmware runs at, as the label says. *)
let%expect_test "a rate comes from the clock it runs at" =
  let fifty_mhz = { Uart.log with load = Some (50_000_000 / 115_200) } in
  print_endline (Datasheet.to_string fifty_mhz (Datasheet.check Library.limits fifty_mhz));
  print_endline (Bench.rate ~unit:"baud" 434);
  [%expect
    {|
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
