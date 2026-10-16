open! Core

let report (bench : Bench.t) =
  List.iter (Named_refusal.refusals Library.limits bench) ~f:(fun t ->
    print_endline (Named_refusal.to_line t))
;;

let%expect_test "the library's benches are refused only where the datasheet table says" =
  report (Library.find_bench_exn "i2c_standard");
  report (Library.find_bench_exn "sk6812");
  [%expect {| |}]
;;

let%expect_test "an i2c START held a quarter short is named at its edge" =
  report Refusal_mutants.i2c_short_start;
  [%expect {|
    i2c_standard: edge 2, THD:STA 2.52 us < 4.00 us min (I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; 121 cycles at 48 MHz, 193 needed)
    i2c_standard: edge 145, TSU:STA 2.52 us < 4.70 us min (I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; 121 cycles at 48 MHz, 274 needed)
    i2c_standard: edge 4, TSU:STO 2.52 us < 4.00 us min (I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; 121 cycles at 48 MHz, 240 needed)
    |}]
;;

let%expect_test "a ws2812 bit a few cycles short is named at its edge" =
  report Refusal_mutants.ws2812_short_bit;
  [%expect {|
    sk6812: edge 11, T0L 812.5 ns, inside the 800 ns min but not its margin (SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; 39 cycles at 48 MHz, 40 needed)
    sk6812: edge 3, T1L 458.3 ns, inside the 450 ns min but not its margin (SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15; 22 cycles at 48 MHz, 23 needed)
    sk6812: edge 3, T 1.17 us < 1.20 us min (SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7, note 2; 56 cycles at 48 MHz, 59 needed)
    |}]
;;

let%expect_test "the picture of the i2c START's hold" =
  let t =
    List.hd_exn (Named_refusal.refusals Library.limits Refusal_mutants.i2c_short_start)
  in
  print_endline (Named_refusal.to_svg ~names:[ Bench.scl, "SCL"; Bench.sda, "SDA" ] t);
  [%expect {|
    <svg xmlns="http://www.w3.org/2000/svg" width="780" height="222" viewBox="0 0 780 222" font-family="monospace" font-size="12">
    <rect width="780" height="222" fill="#ffffff"/>
    <text x="90" y="22" fill="#1a1a1a">i2c_standard: edge 2, THD:STA 2.52 us &lt; 4.00 us min (I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; 121 cycles at 48 MHz, 193 needed)</text>
    <text x="8" y="78" fill="#1a1a1a">SCL</text>
    <path d="M90,58 L593,58 L593,92 L760,92" fill="none" stroke="#1a1a1a" stroke-width="2"/>
    <text x="8" y="134" fill="#1a1a1a">SDA</text>
    <path d="M90,114 L256,114 L256,148 L760,148" fill="none" stroke="#1a1a1a" stroke-width="2"/>
    <line x1="256" y1="40" x2="256" y2="168" stroke="#c0392b" stroke-dasharray="4 3"/>
    <line x1="593" y1="40" x2="593" y2="168" stroke="#c0392b" stroke-dasharray="4 3"/>
    <line x1="256" y1="180" x2="593" y2="180" stroke="#c0392b" stroke-width="2"/>
    <text x="256" y="198" fill="#c0392b">2.52 us, limit &gt;= 4.00 us</text>
    <text x="90" y="216" fill="#8a8f98">cycles 66 to 307 at 48 MHz</text>
    </svg>
    |}]
;;
