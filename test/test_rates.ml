open! Core

let%expect_test "the standard settings against their sheets" =
  List.iter Rates.all ~f:(fun t ->
    print_endline (Datasheet.to_string t.bench (Rates.check t)));
  [%expect {|
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
