open! Core

let report (bench : Bench.t) =
  List.iter (Named_refusal.refusals Library.limits bench) ~f:(fun t ->
    print_endline (Named_refusal.to_line t))
;;

let%expect_test "the library's benches break no datasheet limit" =
  report (Library.find_bench_exn "i2c_standard");
  report (Library.find_bench_exn "sk6812");
  [%expect {| |}]
;;

let%expect_test "an i2c START held a quarter short is named at its edge" =
  report Refusal_mutants.i2c_short_start;
  [%expect
    {|
    i2c_standard: edge 2, THD:STA 2.521 us < 4 us min (I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; 121 cycles at 48 MHz, 193 needed)
    i2c_standard: edge 145, TSU:STA 2.521 us < 4.7 us min (I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; 121 cycles at 48 MHz, 274 needed)
    i2c_standard: edge 4, TSU:STO 2.521 us < 4 us min (I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; 121 cycles at 48 MHz, 240 needed)
    |}]
;;

let%expect_test "a ws2812 bit a few cycles short is named at its edge" =
  report Refusal_mutants.ws2812_short_bit;
  [%expect
    {|
    sk6812: edge 11, T0L 812 ns, inside the 800 ns min but not its margin (SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; 39 cycles at 48 MHz, 40 needed)
    sk6812: edge 3, T1L 458 ns, inside the 450 ns min but not its margin (SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15; 22 cycles at 48 MHz, 23 needed)
    sk6812: edge 3, T 1.167 us < 1.2 us min (SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7, note 2; 56 cycles at 48 MHz, 59 needed)
    |}]
;;

let%expect_test "the picture of the i2c START's hold" =
  let t =
    List.hd_exn (Named_refusal.refusals Library.limits Refusal_mutants.i2c_short_start)
  in
  print_endline (Named_refusal.to_svg ~names:[ Bench.scl, "SCL"; Bench.sda, "SDA" ] t);
  [%expect
    {|
    <svg xmlns="http://www.w3.org/2000/svg" width="780" height="222" viewBox="0 0 780 222" font-family="monospace" font-size="12">
    <rect width="780" height="222" fill="#ffffff"/>
    <text x="90" y="22" fill="#1a1a1a">i2c_standard: edge 2, THD:STA 2.521 us &lt; 4 us min (I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; 121 cycles at 48 MHz, 193 needed)</text>
    <text x="8" y="78" fill="#1a1a1a">SCL</text>
    <path d="M90,58 L593,58 L593,92 L760,92" fill="none" stroke="#1a1a1a" stroke-width="2"/>
    <text x="8" y="134" fill="#1a1a1a">SDA</text>
    <path d="M90,114 L256,114 L256,148 L760,148" fill="none" stroke="#1a1a1a" stroke-width="2"/>
    <line x1="256" y1="40" x2="256" y2="168" stroke="#c0392b" stroke-dasharray="4 3"/>
    <line x1="593" y1="40" x2="593" y2="168" stroke="#c0392b" stroke-dasharray="4 3"/>
    <line x1="256" y1="180" x2="593" y2="180" stroke="#c0392b" stroke-width="2"/>
    <text x="256" y="198" fill="#c0392b">2.521 us, min 4 us</text>
    <text x="90" y="216" fill="#8a8f98">cycles 66 to 307 at 48 MHz</text>
    </svg>
    |}]
;;

(* the bracket is the width that breaks: the pin rises at its start and falls at its end *)
let bracket (t : Named_refusal.t) =
  let measured = Option.value_exn t.measured in
  let pin = List.hd_exn t.pins in
  let level cycle = (t.trace.(cycle) lsr pin) land 1 in
  print_s
    [%message
      (t.edge : int option)
        (measured : int)
        ~before:(level (t.cycle - measured - 1) : int)
        ~start:(level (t.cycle - measured) : int)
        ~last:(level (t.cycle - 1) : int)
        ~after:(level t.cycle : int)]
;;

let sk6812 ~third ~tail =
  let bench = Library.find_bench_exn "sk6812" in
  let gaps = (Bench.cycles_in ~us:200 / (160 * 17)) + 1 in
  { bench with source = Ws2812.latching ~gaps ~third ~tail }
;;

let find t ~parameter ~least =
  List.find_exn t ~f:(fun (t : Named_refusal.t) ->
    String.equal t.entry.parameter parameter
    && Bool.equal
         least
         (match t.entry.limit with
          | At_least _ -> true
          | At_most _ -> false))
;;

let%expect_test "a high shorter than T0H or T1H is bracketed from its rise to its fall" =
  List.iter
    [ "T0H", 8; "T1H", 12 ]
    ~f:(fun (parameter, third) ->
      let t =
        find
          (Named_refusal.refusals Library.limits (sk6812 ~third ~tail:8))
          ~parameter
          ~least:true
      in
      print_endline (Named_refusal.to_line t);
      bracket t);
  [%expect {|
    sk6812: edge 10, T0H 167 ns < 200 ns min (SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; 8 cycles at 48 MHz, 11 needed)
    ((t.edge (10)) (measured 8) (before 0) (start 1) (last 1) (after 0))
    sk6812: edge 2, T1H 500 ns < 600 ns min (SK6812, OSK-SPC-SK6812-012 Rev. B/0 p.7; 24 cycles at 48 MHz, 30 needed)
    ((t.edge (2)) (measured 24) (before 0) (start 1) (last 1) (after 0))
    |}]
;;

let%expect_test "a high longer than T1H's most is bracketed too" =
  let t =
    find
      (Named_refusal.refusals Library.limits (sk6812 ~third:25 ~tail:8))
      ~parameter:"T1H"
      ~least:false
  in
  print_endline (Named_refusal.to_line t);
  bracket t;
  [%expect {|
    sk6812: edge 2, T1H 1.042 us > 750 ns max (SK6812, SPC/SK6812 Rev. 01 p.5, 0.3/0.6/0.9/0.6 us +-0.15; 50 cycles at 48 MHz, 35 needed)
    ((t.edge (2)) (measured 50) (before 0) (start 1) (last 1) (after 0))
    |}]
;;

(* The kernel's bound breaks the limit but the run shows no edge that does: the line and
   the picture say the bound only. *)
let%expect_test "a refusal with no edge on the run names the kernel's bound" =
  let bench = Library.find_bench_exn "i2c_standard" in
  let entry =
    List.find_exn Library.limits ~f:(fun (e : Datasheet.t) ->
      String.equal e.firmware bench.name && String.equal e.parameter "THD:STA")
  in
  let entry = { entry with limit = At_least 7530. } in
  let t = List.hd_exn (Named_refusal.refusals [ entry ] bench) in
  let t = { t with edge = None; measured = None; cycle = 0 } in
  print_endline (Named_refusal.to_line t);
  print_endline (Named_refusal.to_svg t);
  [%expect {|
    i2c_standard: THD:STA kernel bound 7.542 us (I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; 362 cycles at 48 MHz, 363 needed)
    <svg xmlns="http://www.w3.org/2000/svg" width="780" height="222" viewBox="0 0 780 222" font-family="monospace" font-size="12">
    <rect width="780" height="222" fill="#ffffff"/>
    <text x="90" y="22" fill="#1a1a1a">i2c_standard: THD:STA kernel bound 7.542 us (I2C Standard-mode, NXP UM10204 Rev. 7.0 Table 10; 362 cycles at 48 MHz, 363 needed)</text>
    <text x="8" y="78" fill="#1a1a1a">pin 14</text>
    <path d="M90,58 L760,58" fill="none" stroke="#1a1a1a" stroke-width="2"/>
    <text x="8" y="134" fill="#1a1a1a">pin 15</text>
    <path d="M90,114 L760,114" fill="none" stroke="#1a1a1a" stroke-width="2"/>
    <text x="90" y="216" fill="#8a8f98">cycles 0 to 181 at 48 MHz</text>
    </svg>
    |}]
;;
