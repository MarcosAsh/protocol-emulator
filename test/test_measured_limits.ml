open! Core

(* Each bench copy's limits, measured on its own run as the bench's analyser would capture
   it, at 24 MHz, beside the bound [Datasheet.check] holds it to. A kernel bound is the
   least of every run, so a run at the chip's clock never shows less, and a run bound is
   that run's, so it shows the same. Each capture is also read back as demo/edges.py
   writes one from the bench. *)
let%expect_test "the datasheet limits, measured on the bench copies' runs" =
  List.iter (Library.bench @ [ Uart.log ]) ~f:(fun (bench : Bench.t) ->
    match bench.stimulus with
    | None -> ()
    | Some _ ->
      List.iter (Datasheet.check Library.limits bench) ~f:(fun (limit, checked) ->
        let measured ?rate_hz () =
          let capture = Measured_limits.Capture.of_run ?rate_hz bench limit in
          capture, Measured_limits.measure [ limit ] bench capture |> List.hd_exn
        in
        let _, exact = measured () in
        let kind, agrees =
          match limit.bound, exact.samples, checked.bound with
          | Kernel _, Some shown, Some bound -> "kernel", shown >= bound
          | Run _, Some shown, Some bound -> "run", shown = bound
          | Kernel _, _, _ -> "kernel", false
          | Run _, _, _ -> "run", false
        in
        if not agrees
        then
          print_s
            [%message
              "the run disagrees with the bound"
                bench.name
                limit.parameter
                (exact.samples : int option)
                (checked.bound : int option)];
        let capture, at_24 = measured ~rate_hz:24_000_000 () in
        (* as test/measure reads it from demo/edges.py *)
        let read_back =
          { (Measured_limits.Capture.of_string
               (Measured_limits.Capture.to_string capture))
            with
            from_reset = true
          }
        in
        let again = Measured_limits.measure [ limit ] bench read_back |> List.hd_exn in
        if not ([%equal: int option] again.samples at_24.samples)
        then print_s [%message "read back otherwise" bench.name limit.parameter];
        printf
          "%-6s %d  %s\n"
          kind
          (Option.value checked.bound ~default:(-1))
          (Measured_limits.to_string capture [ at_24 ])));
  [%expect
    {|
    kernel 5000  uart_tx_9600       bit              >=   102083 ns  measured 2500 (104166.7 ns)   Pass            Maxim AN2141, p.4, +-3/152, 2%
    run    5000  uart_tx_9600       bit              <=   106250 ns  measured 2500 (104166.7 ns)   Pass            Maxim AN2141, p.4, +-3/152, 2%
    kernel 2500  uart_tx_19200      bit              >=  51041.7 ns  measured 1250 (52083.3 ns)    Pass            Maxim AN2141, p.4, +-3/152, 2%
    run    2500  uart_tx_19200      bit              <=    53125 ns  measured 1250 (52083.3 ns)    Pass            Maxim AN2141, p.4, +-3/152, 2%
    kernel 1250  uart_tx_38400      bit              >=  25520.8 ns  measured 625 (26041.7 ns)     Pass            Maxim AN2141, p.4, +-3/152, 2%
    run    1250  uart_tx_38400      bit              <=  26562.5 ns  measured 625 (26041.7 ns)     Pass            Maxim AN2141, p.4, +-3/152, 2%
    kernel 833  uart_tx_57600      bit              >=  17013.9 ns  measured 417 (17375.0 ns)     Pass            Maxim AN2141, p.4, +-3/152, 2%
    run    833  uart_tx_57600      bit              <=  17708.3 ns  measured 417 (17375.0 ns)     Pass            Maxim AN2141, p.4, +-3/152, 2%
    kernel 417  uart_tx_115200     bit              >=  8506.94 ns  measured 209 (8708.3 ns)      Pass            Maxim AN2141, p.4, +-3/152, 2%
    run    417  uart_tx_115200     bit              <=  8854.17 ns  measured 209 (8708.3 ns)      Pass            Maxim AN2141, p.4, +-3/152, 2%
    kernel 208  uart_tx_230400     bit              >=  4253.47 ns  measured 104 (4333.3 ns)      Pass            Maxim AN2141, p.4, +-3/152, 2%
    run    208  uart_tx_230400     bit              <=  4427.08 ns  measured 104 (4333.3 ns)      Pass            Maxim AN2141, p.4, +-3/152, 2%
    kernel 242  i2c_standard       THIGH            >=     4000 ns  measured 121 (5041.7 ns)      Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 242  i2c_standard       TLOW             >=     4700 ns  measured 121 (5041.7 ns)      Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 362  i2c_standard       THD:STA          >=     4000 ns  measured 181 (7541.7 ns)      Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 363  i2c_standard       TSU:STA          >=     4700 ns  measured 182 (7583.3 ns)      Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 120  i2c_standard       TSU:DAT          >=      250 ns  measured 60 (2500.0 ns)       Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 363  i2c_standard       TSU:STO          >=     4000 ns  measured 181 (7541.7 ns)      Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 368  i2c_standard       TBUF             >=     4700 ns  measured 184 (7666.7 ns)      Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    run    484  i2c_standard       1/fSCL           >=    10000 ns  measured 242 (10083.3 ns)     Pass            NXP UM10204 Rev. 7.0, Table 11, p.44, fSCL
    kernel 64  i2c_fast           THIGH            >=      600 ns  measured 32 (1333.3 ns)       Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 64  i2c_fast           TLOW             >=     1300 ns  measured 32 (1333.3 ns)       Within_a_sample NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 64  i2c_fast           THD:STA          >=      600 ns  measured 32 (1333.3 ns)       Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 64  i2c_fast           TSU:STA          >=      600 ns  measured 32 (1333.3 ns)       Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 31  i2c_fast           TSU:DAT          >=      100 ns  measured 15 (625.0 ns)        Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 64  i2c_fast           TSU:STO          >=      600 ns  measured 32 (1333.3 ns)       Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    kernel 101  i2c_fast           TBUF             >=     1300 ns  measured 50 (2083.3 ns)       Pass            NXP UM10204 Rev. 7.0, Table 11, p.44
    run    128  i2c_fast           1/fSCL           >=     2500 ns  measured 64 (2666.7 ns)       Pass            NXP UM10204 Rev. 7.0, Table 11, p.44, fSCL
    kernel 17  sk6812             T0H              >=      250 ns  measured 8 (333.3 ns)         Pass            OSK-SPC-SK6812-012 Rev. B/1, p.7
    run    17  sk6812             T0H              <=      400 ns  measured 9 (375.0 ns)         Within_a_sample OSK-SPC-SK6812-012 Rev. B/1, p.7
    run    34  sk6812             T1H              >=      650 ns  measured 17 (708.3 ns)        Pass            OSK-SPC-SK6812-012 Rev. B/1, p.7
    run    34  sk6812             T1H              <=     1000 ns  measured 17 (708.3 ns)        Pass            OSK-SPC-SK6812-012 Rev. B/1, p.7
    run    42  sk6812             T0L              >=      800 ns  measured 21 (875.0 ns)        Pass            OSK-SPC-SK6812-012 Rev. B/1, p.7
    kernel 25  sk6812             T1L              >=      200 ns  measured 12 (500.0 ns)        Pass            OSK-SPC-SK6812-012 Rev. B/1, p.7
    run    59  sk6812             T                >=     1200 ns  measured 29 (1208.3 ns)       Within_a_sample OSK-SPC-SK6812-012 Rev. B/1, p.7, note 2
    run    10907  sk6812             reset            >=   200000 ns  measured 5454 (227250.0 ns)   Pass            OSK-SPC-SK6812-012 Rev. B/1, p.7
    kernel 288  one_wire           tLOW1            >=     1000 ns  measured 144 (6000.0 ns)      Pass            Maxim REV 042208, p.20
    run    288  one_wire           tLOW1            <=    15000 ns  measured 144 (6000.0 ns)      Pass            Maxim REV 042208, p.20
    run    3168  one_wire           tLOW0            >=    60000 ns  measured 1584 (66000.0 ns)    Pass            Maxim REV 042208, p.20
    run    3168  one_wire           tLOW0            <=   120000 ns  measured 1584 (66000.0 ns)    Pass            Maxim REV 042208, p.20
    kernel 288  one_wire           tREC             >=     1000 ns  measured 144 (6000.0 ns)      Pass            Maxim REV 042208, p.20
    run    3456  one_wire           tSLOT + tREC     >=    61000 ns  measured 1728 (72000.0 ns)    Pass            Maxim REV 042208, p.20
    run    24194  one_wire           tRSTL            >=   480000 ns  measured 12097 (504041.7 ns)  Pass            Maxim REV 042208, p.20
    run    23336  one_wire           tRSTH            >=   480000 ns  measured 11668 (486166.7 ns)  Pass            Maxim REV 042208, p.20
    kernel 957  ps2                data to CLK fall >=     5000 ns  measured 479 (19958.3 ns)     Pass            IBM Personal System/2 Hardware Interface Technical Reference, May 1988, Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T1
    kernel 960  ps2                CLK rise to data >=     5000 ns  measured 481 (20041.7 ns)     Pass            IBM Personal System/2 Hardware Interface Technical Reference, May 1988, Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T2
    kernel 1920  ps2                CLK low          >=    30000 ns  measured 960 (40000.0 ns)     Pass            IBM Personal System/2 Hardware Interface Technical Reference, May 1988, Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T3
    run    1920  ps2                CLK low          <=    50000 ns  measured 960 (40000.0 ns)     Pass            IBM Personal System/2 Hardware Interface Technical Reference, May 1988, Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T3
    run    1920  ps2                CLK high         >=    30000 ns  measured 960 (40000.0 ns)     Pass            IBM Personal System/2 Hardware Interface Technical Reference, May 1988, Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T4
    run    1920  ps2                CLK high         <=    50000 ns  measured 960 (40000.0 ns)     Pass            IBM Personal System/2 Hardware Interface Technical Reference, May 1988, Keyboard and Auxiliary Device Controller, Figure 8, p. 13, T4
    kernel 96  can                recessive        >=     1000 ns  measured 48 (2000.0 ns)       Pass            TI SLOS346O, p.1, up to 1 Mbps
    kernel 96  can                dominant         >=     1000 ns  measured 48 (2000.0 ns)       Pass            TI SLOS346O, p.1, up to 1 Mbps
    run    1165  can                idle to SOF      >=    22000 ns  measured 583 (24291.7 ns)     Pass            Bosch CAN 2.0, BCANPSV2.0 Rev. 3, s.2.15 p.2-6, eleven recessive bits
    kernel 96  can_sender         recessive        >=     1000 ns  measured 48 (2000.0 ns)       Pass            TI SLOS346O, p.1, up to 1 Mbps
    kernel 96  can_sender         dominant         >=     1000 ns  measured 48 (2000.0 ns)       Pass            TI SLOS346O, p.1, up to 1 Mbps
    run    1165  can_sender         idle to SOF      >=    22000 ns  measured 583 (24291.7 ns)     Pass            Bosch CAN 2.0, BCANPSV2.0 Rev. 3, s.2.15 p.2-6, eleven recessive bits
    run    177600  cec                start low        >=  3.5e+06 ns  measured 88800 (3700000.0 ns) Pass            HDMI Specification 1.3a, Supplement 1 CEC, CEC 5.2.1, CEC Figure 3, p. CEC-8
    run    177600  cec                start low        <=  3.9e+06 ns  measured 88800 (3700000.0 ns) Pass            HDMI Specification 1.3a, Supplement 1 CEC, CEC 5.2.1, CEC Figure 3, p. CEC-8
    run    216000  cec                start bit        >=  4.3e+06 ns  measured 108000 (4500000.0 ns) Pass            HDMI Specification 1.3a, Supplement 1 CEC, CEC 5.2.1, CEC Figure 3, p. CEC-8
    run    216000  cec                start bit        <=  4.7e+06 ns  measured 108000 (4500000.0 ns) Pass            HDMI Specification 1.3a, Supplement 1 CEC, CEC 5.2.1, CEC Figure 3, p. CEC-8
    run    28800  cec                one low, T1      >=   400000 ns  measured 14400 (600000.0 ns)  Pass            HDMI Specification 1.3a, Supplement 1 CEC, CEC 5.2.2, CEC Figure 4, p. CEC-9
    run    28800  cec                one low, T2      <=   800000 ns  measured 14400 (600000.0 ns)  Pass            HDMI Specification 1.3a, Supplement 1 CEC, CEC 5.2.2, CEC Figure 4, p. CEC-9
    run    72000  cec                zero low, T5     >=  1.3e+06 ns  measured 36000 (1500000.0 ns) Pass            HDMI Specification 1.3a, Supplement 1 CEC, CEC 5.2.2, CEC Figure 4, p. CEC-9
    run    72000  cec                zero low, T6     <=  1.7e+06 ns  measured 36000 (1500000.0 ns) Pass            HDMI Specification 1.3a, Supplement 1 CEC, CEC 5.2.2, CEC Figure 4, p. CEC-9
    run    115200  cec                bit, T7          >= 2.05e+06 ns  measured 57600 (2400000.0 ns) Pass            HDMI Specification 1.3a, Supplement 1 CEC, CEC 5.2.2, CEC Figure 4, p. CEC-9
    run    115200  cec                bit, T8          <= 2.75e+06 ns  measured 57600 (2400000.0 ns) Pass            HDMI Specification 1.3a, Supplement 1 CEC, CEC 5.2.2, CEC Figure 4, p. CEC-9
    kernel 417  uart_log           bit              >=  8506.94 ns  measured 209 (8708.3 ns)      Pass            Maxim AN2141, p.4, +-3/152, 2%
    run    417  uart_log           bit              <=  8854.17 ns  measured 209 (8708.3 ns)      Pass            Maxim AN2141, p.4, +-3/152, 2%
    |}]
;;
