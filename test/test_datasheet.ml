open! Core
open Protocol_emulator

let fails (bench : Bench.t) =
  let verdicts =
    Datasheet.check bench
    |> List.filter ~f:(fun (_, (v : Datasheet.Verdict.t)) -> not v.ok)
  in
  print_endline (Datasheet.to_string bench verdicts)
;;

(* Each kernel bound is the most cycles the kernel accepts, so one more is refused. *)
let%expect_test "the bench firmware against its datasheet limits" =
  List.iter Bench.all ~f:(fun bench ->
    match Datasheet.check bench with
    | [] -> ()
    | verdicts -> print_endline (Datasheet.to_string bench verdicts));
  [%expect
    {|
    i2c_master         THIGH          >=      600 ns  kernel 96 (2000.0 ns)    needs   29       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 2
    i2c_master         TLOW           >=     1300 ns  kernel 96 (2000.0 ns)    needs   63       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 3
    i2c_master         THD:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   29       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 6
    i2c_master         TSU:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   29       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 7
    i2c_master         TSU:DAT        >=      100 ns  kernel 47 (979.2 ns)     needs    5       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 9
    i2c_master         TSU:STO        >=      600 ns  kernel 48 (1000.0 ns)    needs   29       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 10
    i2c_master         TBUF           >=     1300 ns  kernel 149 (3104.2 ns)   needs   63       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 14
    i2c_master_stretch THIGH          >=      600 ns  kernel 96 (2000.0 ns)    needs   29       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 2
    i2c_master_stretch TLOW           >=     1300 ns  kernel 96 (2000.0 ns)    needs   63       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 3
    i2c_master_stretch THD:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   29       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 6
    i2c_master_stretch TSU:STA        >=      600 ns  kernel 48 (1000.0 ns)    needs   29       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 7
    i2c_master_stretch TSU:DAT        >=      100 ns  kernel 47 (979.2 ns)     needs    5       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 9
    i2c_master_stretch TSU:STO        >=      600 ns  kernel 48 (1000.0 ns)    needs   29       24LC256, Microchip DS20001203W, Table 1-2 p.3, param 10
    i2c_master_stretch TBUF           >=     1300 ns  kernel 105 (2187.5 ns)   needs   63       24LC256, Microchip DS20001203W, Table 1-2 p.4, param 14
    one_wire           tLOW1          >=     1000 ns  kernel 288 (6000.0 ns)   needs   48       DS18B20, Maxim REV 042208 p.20
    one_wire           tLOW1          <=    15000 ns  run    288 (6000.0 ns)   needs  720       DS18B20, Maxim REV 042208 p.20
    one_wire           tLOW0          >=    60000 ns  run    3168 (66000.0 ns) needs 2880       DS18B20, Maxim REV 042208 p.20
    one_wire           tLOW0          <=   120000 ns  run    3168 (66000.0 ns) needs 5760       DS18B20, Maxim REV 042208 p.20
    one_wire           tREC           >=     1000 ns  kernel 288 (6000.0 ns)   needs   48       DS18B20, Maxim REV 042208 p.20
    one_wire           tSLOT + tREC   >=    61000 ns  run    3456 (72000.0 ns) needs 2928       DS18B20, Maxim REV 042208 p.20
    one_wire           tRSTL          >=   480000 ns  run    24194 (504041.7 ns) needs 23040       DS18B20, Maxim REV 042208 p.20
    one_wire           tRSTH          >=   480000 ns  run    23336 (486166.7 ns) needs 23040       DS18B20, Maxim REV 042208 p.20
    can                recessive      >=     1000 ns  kernel 96 (2000.0 ns)    needs   48       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps
    can                dominant       >=     1000 ns  kernel 96 (2000.0 ns)    needs   48       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps
    can                idle to SOF    >=    22000 ns  run    1165 (24270.8 ns) needs 1056       CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits
    can_sender         recessive      >=     1000 ns  kernel 96 (2000.0 ns)    needs   48       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps
    can_sender         dominant       >=     1000 ns  kernel 96 (2000.0 ns)    needs   48       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps
    can_sender         idle to SOF    >=    22000 ns  run    1165 (24270.8 ns) needs 1056       CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits
    can_receiver       ACK            >=     1000 ns  kernel 96 (2000.0 ns)    needs   48       SN65HVD230, TI SLOS346O p.1, up to 1 Mbps
    sk6812             T0H            >=      200 ns  kernel 17 (354.2 ns)     needs   10       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7
    sk6812             T0H            <=      400 ns  run    17 (354.2 ns)     needs   19       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7
    sk6812             T1H            >=      600 ns  run    34 (708.3 ns)     needs   29       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7
    sk6812             T1H            <=      750 ns  run    34 (708.3 ns)     needs   36       SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15
    sk6812             T0L            >=      800 ns  run    42 (875.0 ns)     needs   39       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7
    sk6812             T0L            <=     1050 ns  run    42 (875.0 ns)     needs   50       SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15
    sk6812             T1L            >=      450 ns  kernel 25 (520.8 ns)     needs   22       SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15
    sk6812             T1L            <=      750 ns  run    25 (520.8 ns)     needs   36       SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15
    sk6812             T              >=     1200 ns  run    59 (1229.2 ns)    needs   58       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7, note 2
    sk6812             reset          >=   200000 ns  run    10907 (227229.2 ns) needs 9600       SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7
    swd                SWCLK high     >=  20.8333 ns  kernel 7 (145.8 ns)      needs    1       RP2040, RP2040 datasheet, 2025-02-20 s.2.3.4 p.61
    swd                SWCLK low      >=  20.8333 ns  kernel 24 (500.0 ns)     needs    1       RP2040, RP2040 datasheet, 2025-02-20 s.2.3.4 p.61
    spi_cs_mode0       tCLH           >=        9 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode0       tCLL           >=        9 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode0       tSLCH          >=        3 ns  kernel 4 (83.3 ns)       needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode0       tCHSH          >=        3 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode0       tSHSL2         >=       50 ns  kernel 154 (3208.3 ns)   needs    3       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode0       tRES1          >=     3000 ns  kernel 154 (3208.3 ns)   needs  144       W25Q64JV, Winbond Rev. M p.65
    spi_cs_mode1       tCLH           >=        9 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode1       tCLL           >=        9 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode1       tSLCH          >=        3 ns  kernel 4 (83.3 ns)       needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode1       tCHSH          >=        3 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode1       tSHSL2         >=       50 ns  kernel 154 (3208.3 ns)   needs    3       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode1       tRES1          >=     3000 ns  kernel 154 (3208.3 ns)   needs  144       W25Q64JV, Winbond Rev. M p.65
    spi_cs_mode2       tCLH           >=        9 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode2       tCLL           >=        9 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode2       tSLCH          >=        3 ns  kernel 4 (83.3 ns)       needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode2       tCHSH          >=        3 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode2       tSHSL2         >=       50 ns  kernel 154 (3208.3 ns)   needs    3       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode2       tRES1          >=     3000 ns  kernel 154 (3208.3 ns)   needs  144       W25Q64JV, Winbond Rev. M p.65
    spi_cs_mode3       tCLH           >=        9 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode3       tCLL           >=        9 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode3       tSLCH          >=        3 ns  kernel 4 (83.3 ns)       needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode3       tCHSH          >=        3 ns  kernel 8 (166.7 ns)      needs    1       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode3       tSHSL2         >=       50 ns  kernel 154 (3208.3 ns)   needs    3       W25Q64JV, Winbond Rev. M p.64
    spi_cs_mode3       tRES1          >=     3000 ns  kernel 154 (3208.3 ns)   needs  144       W25Q64JV, Winbond Rev. M p.65
    |}]
;;

let before name ~source = { (Bench.find_exn name) with source }

let undo (bench : Bench.t) ~fix ~was =
  let source = bench.source in
  if not (String.is_substring source ~substring:fix)
  then raise_s [%message "BUG: the fix has moved" bench.name];
  { bench with source = String.substr_replace_first source ~pattern:fix ~with_:was }
;;

(* The teeth: the firmware each fix replaced fails its limits. *)
let%expect_test "the firmware before each fix fails" =
  List.iter
    ~f:fails
    [ before "sk6812" ~source:(Ws2812.firmware ~third:16 ~tail:7)
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
        ~init:(Bench.find_exn "i2c_master_stretch")
        ~f:(fun bench comment ->
          undo
            bench
            ~fix:
              ("    mov t, now side 0\n    add t, p side 0\n    wait t side 0" ^ comment)
            ~was:"")
    ];
  [%expect
    {|
    sk6812             T              >=     1200 ns  run    55 (1145.8 ns)    needs   58 FAIL  SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7, note 2
    sk6812             reset          >=   200000 ns  run    2584 (53833.3 ns) needs 9600 FAIL  SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7
    can                idle to SOF    >=    22000 ns  run    103 (2145.8 ns)   needs 1056 FAIL  CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits
    can_sender         idle to SOF    >=    22000 ns  run    103 (2145.8 ns)   needs 1056 FAIL  CAN 2.0A, Bosch CAN 2.0, BCANPSV2.0 Rev. 3 s.2.15 p.2-6, eleven recessive bits
    spi_cs_mode0       tRES1          >=     3000 ns  kernel 9 (187.5 ns)      needs  144 FAIL  W25Q64JV, Winbond Rev. M p.65
    i2c_master_stretch TSU:STO        >=      600 ns  kernel 7 (145.8 ns)      needs   29 FAIL  24LC256, Microchip DS20001203W, Table 1-2 p.3, param 10
    |}]
;;
