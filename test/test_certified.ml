open! Core
open Protocol_emulator

(* The README's table: each firmware's certificate and what it rests on. Proved on the RTL
   by [make -C formal certificates] and [make -C formal inductive_certificates]. *)
let%expect_test "the firmware library and its certificates" =
  printf "%-18s %5s  %8s  %5s  %s\n" "firmware" "words" "deadline" "slack" "assumes";
  List.iter Library.certified ~f:(fun t ->
    let program = Asm.assemble t.source |> ok_exn in
    let verdict =
      Analyser.check
        ?period:t.period
        ~single_capture_edge:t.single_capture_edge
        ~config:(Asm.Program.configure program t.config)
        program
    in
    let assumes =
      List.filter_opt
        [ Option.map t.period ~f:(sprintf "period %d")
        ; Option.some_if t.single_capture_edge "one edge before capture"
        ; Option.some_if t.no_wrap "no wrap"
        ]
      |> String.concat ~sep:", "
    in
    match verdict with
    | Error e ->
      printf
        "%-18s refused: %s\n"
        t.name
        (List.hd_exn (String.split_lines (Error.to_string_hum e)))
    | Ok verdict ->
      printf
        "%-18s %5d  %8d  %5s  %s\n"
        t.name
        verdict.words
        verdict.deadline_waits
        (Option.value_map verdict.worst_slack ~default:"-" ~f:Int.to_string)
        assumes);
  [%expect
    {|
    firmware           words  deadline  slack  assumes
    uart_tx               15         3      4
    uart_tx16             15         3     12
    uart_tx_host_rate     17         3    430  period 434, no wrap
    uart_rx               19         2      7  one edge before capture, no wrap
    uart_rx_host_rate     22         2    409  period 208, one edge before capture, no wrap
    spi_master            16         3      4
    spi_slave              6         0      -
    i2c_master            99        31      5  no wrap
    i2c_slave             72         0      -
    i2c_logger            73        25      1
    i2c_master_standard   113        43    113  period 121, no wrap
    i2c_master_fast      107        37     24  period 32, no wrap
    i2c_master_standard_asym   121        43     90  period 127, no wrap
    i2c_master_fast_asym   111        37     22  period 32, no wrap
    i2c_controller_wire    87        25    113  period 121, no wrap
    i2c_target_wire       78         0      -
    usb_tx                67        11     16  period 32
    usb_rx                92         4      5  period 32, one edge before capture, no wrap
    usb_device           470        54      6  period 32, one edge before capture, no wrap
    edge_meter            12         2      6
    ws2812                32         4      0  no wrap
    ws2812_standard       32         4      9  no wrap
    ethernet              32         1  63987  period 64000, no wrap
    one_wire              48        15    295  period 300
    ps2                   65        12    992  period 1000
    jtag                  15         3      0
    can                   56        10     81  period 96, no wrap
    dshot600              21         4     14  no wrap
    sent                  83         9    129  period 150, no wrap
    cec                   71        20   2493  period 2500, no wrap
    spi_cs_mode0          43         6      1  no wrap
    spi_cs_mode1          43         6      1  no wrap
    spi_cs_mode2          43         6      1  no wrap
    spi_cs_mode3          43         6      1  no wrap
    spi_cs_mode0_default_pins    43         6      1  no wrap
    spi_cs_mode1_default_pins    43         6      1  no wrap
    spi_cs_mode2_default_pins    43         6      1  no wrap
    spi_cs_mode3_default_pins    43         6      1  no wrap
    spi_target_mode0      47         0      -
    spi_target_mode1      35         0      -
    spi_target_mode2      45         0      -
    spi_target_mode3      34         0      -
    swd                  232        52     15  period 25, no wrap
    table                112         2      0
    table_open_drain     112         2      0
    nec_tx                80        22  26989  period 27000, no wrap
    nec_rx                37         4  13493  period 13500, one edge before capture, no wrap
    snorble               84         5      0  no wrap
    plinkoo               90        15      0  no wrap
    microwire             69         7     13
    ir_rc6                64        22  21325  period 21333, no wrap
    caliper               57        11    263  period 270
    xy2_100               35        10      2
    lfast                 64        27      6
    |}]
;;

module G = Hardcaml_verify.Comb_gates

(* Where the host picks the rate, the least period it may load. The analyser's table for
   loads of the floor or more passes the kernel at every such load, by checked SAT; at the
   floor less one the kernel refuses its table. With phase_step.sv, whose load is free at
   each entry, no deadline is missed however the loads from the floor up vary. *)
let%expect_test "the least period the host may load" =
  List.iter Library.certified ~f:(fun t ->
    Option.iter t.period_floor ~f:(fun floor ->
      let program = Asm.assemble t.source |> ok_exn in
      let config = Asm.Program.configure program t.config in
      let words = Asm.Program.words program |> ok_exn in
      let single_capture_edge = t.single_capture_edge in
      let table floor =
        Analyser.analyse
          ~period_floor:floor
          ~single_capture_edge
          ~config
          program.instructions
        |> Kernel.Table.of_analyser
      in
      let passes floor =
        Kernel.check ~period:floor ~single_capture_edge ~config ~words (table floor)
        |> Result.is_ok
      in
      let loads_from least =
        Table_query.every_load_from
          ~floor:least
          ~single_capture_edge
          ~config
          ~words
          (table floor)
      in
      print_s
        [%message
          t.name
            ~period:(t.period : int option)
            (floor : int)
            ~passes:(passes floor : bool)
            ~one_less:(passes (floor - 1) : bool)];
      Checked_unsat.prove
        [%string "%{t.name}: every load of %{floor#Int} or more"]
        ~cases:[ G.vdd ]
        ~claim:(loads_from floor);
      (* the tooth: one less than the table allows *)
      Checked_unsat.prove
        ~show:[ "loaded" ]
        [%string "%{t.name}: every load of %{floor - 1#Int} or more"]
        ~cases:[ G.vdd ]
        ~claim:(loads_from (floor - 1))));
  [%expect
    {|
    (uart_tx_host_rate (period (434)) (floor 4) (passes true) (one_less false))
    (QED "uart_tx_host_rate: every load of 4 or more")
    (counterexample "uart_tx_host_rate: every load of 3 or more"
     (model ((loaded 0000000000000011))))
    (uart_rx_host_rate (period (208)) (floor 4) (passes true) (one_less false))
    (QED "uart_rx_host_rate: every load of 4 or more")
    (counterexample "uart_rx_host_rate: every load of 3 or more"
     (model ((loaded 0000000000000011))))
    (i2c_master_standard (period (121)) (floor 8) (passes true) (one_less false))
    (QED "i2c_master_standard: every load of 8 or more")
    (counterexample "i2c_master_standard: every load of 7 or more"
     (model ((loaded 0000000000000111))))
    (i2c_master_fast (period (32)) (floor 8) (passes true) (one_less false))
    (QED "i2c_master_fast: every load of 8 or more")
    (counterexample "i2c_master_fast: every load of 7 or more"
     (model ((loaded 0000000000000111))))
    (i2c_controller_wire (period (121)) (floor 8) (passes true) (one_less false))
    (QED "i2c_controller_wire: every load of 8 or more")
    (counterexample "i2c_controller_wire: every load of 7 or more"
     (model ((loaded 0000000000000111))))
    (one_wire (period (300)) (floor 5) (passes true) (one_less false))
    (QED "one_wire: every load of 5 or more")
    (counterexample "one_wire: every load of 4 or more"
     (model ((loaded 0000000000000100))))
    (ps2 (period (1000)) (floor 8) (passes true) (one_less false))
    (QED "ps2: every load of 8 or more")
    (counterexample "ps2: every load of 7 or more"
     (model ((loaded 0000000000000111))))
    (can (period (96)) (floor 15) (passes true) (one_less false))
    (QED "can: every load of 15 or more")
    (counterexample "can: every load of 14 or more"
     (model ((loaded 0000000000001110))))
    (sent (period (150)) (floor 21) (passes true) (one_less false))
    (QED "sent: every load of 21 or more")
    (counterexample "sent: every load of 20 or more"
     (model ((loaded 0000000000010100))))
    (cec (period (2500)) (floor 7) (passes true) (one_less false))
    (QED "cec: every load of 7 or more")
    (counterexample "cec: every load of 6 or more"
     (model ((loaded 0000000000000110))))
    (swd (period (25)) (floor 10) (passes true) (one_less false))
    (QED "swd: every load of 10 or more")
    (counterexample "swd: every load of 9 or more"
     (model ((loaded 0000000000001001))))
    (nec_tx (period (27000)) (floor 11) (passes true) (one_less false))
    (QED "nec_tx: every load of 11 or more")
    (counterexample "nec_tx: every load of 10 or more"
     (model ((loaded 0000000000001010))))
    (ir_rc6 (period (21333)) (floor 14) (passes true) (one_less true))
    (QED "ir_rc6: every load of 14 or more")
    (counterexample "ir_rc6: every load of 13 or more"
     (model ((loaded 0000000000001101))))
    (caliper (period (270)) (floor 16) (passes true) (one_less true))
    (QED "caliper: every load of 16 or more")
    (counterexample "caliper: every load of 15 or more"
     (model ((loaded 0000000000001111))))
    |}]
;;

(* The fastest rate each protocol's firmware is certified at, as the least setting of its
   rate, a half period or the period the host loads, that the analyser and the kernel
   accept. Where the host loads the period, the certificate holds for every load from it
   up, as above. The deadlines only: datasheet limits and pad speed are apart. *)
module Rate = struct
  type t =
    { protocol : string
    ; firmware : string
    ; unit : string
    ; cycles : int (* to a unit of the rate, for a setting of 1 *)
    ; make : int -> Certified.t
    ; pio : int option
        (* what RP2040 PIO's pico-examples (uart_tx, uart_rx, spi, i2c) take to a unit, in
           its own cycles: the perf scout's reading, 2026-10-29 *)
    ; note : string
    }

  let lib = Library.find_certified_exn

  (* the library's firmware, checked as loaded at [setting] and every period above *)
  let loaded name setting =
    { (lib name) with period = Some setting; period_floor = Some setting }
  ;;

  let rebuilt name source = { (lib name) with source; period = None }

  let spi_cs mode =
    let name = sprintf "spi_cs_mode%d" (Spi_cs.Mode.to_int mode) in
    { protocol = "spi controller"
    ; firmware = name
    ; unit = "Hz"
    ; cycles = 2
    ; make =
        (fun half_period ->
          rebuilt
            name
            (Spi_cs.master
               ~mode
               ~half_period
               ~setup:4
               ~hold:8
               ~deselect:(Bench.cycles_in ~us:3)))
    ; pio = Some 4
    ; note = "CS 4 cycles before and 8 after, 3 us apart"
    }
  ;;

  let all =
    [ { protocol = "uart tx"
      ; firmware = "uart_tx_host_rate"
      ; unit = "baud"
      ; cycles = 1
      ; make = loaded "uart_tx_host_rate"
      ; pio = Some 8
      ; note = ""
      }
    ; { protocol = "uart rx"
      ; firmware = "uart_rx_host_rate"
      ; unit = "baud"
      ; cycles = 2
      ; make = loaded "uart_rx_host_rate"
      ; pio = Some 8
      ; note = "the host loads half a bit"
      }
    ; { protocol = "spi controller"
      ; firmware = "spi_master"
      ; unit = "Hz"
      ; cycles = 2
      ; make = (fun half_period -> rebuilt "spi_master" (Spi.master ~half_period))
      ; pio = Some 4
      ; note = "no CS"
      }
    ]
    @ List.map Spi_cs.Mode.all ~f:spi_cs
    @ [ { protocol = "i2c controller"
        ; firmware = "i2c_master_fast"
        ; unit = "Hz"
        ; cycles = 4
        ; make = loaded "i2c_master_fast"
        ; pio = Some 32
        ; note = "the host loads a quarter, and the datasheet rows ask for more"
        }
      ; { protocol = "jtag"
        ; firmware = "jtag"
        ; unit = "Hz"
        ; cycles = 2
        ; make = (fun half_period -> rebuilt "jtag" (Jtag.firmware ~half_period))
        ; pio = None
        ; note = ""
        }
      ; { protocol = "swd"
        ; firmware = "swd"
        ; unit = "Hz"
        ; cycles = 2
        ; make = loaded "swd"
        ; pio = None
        ; note = "the host loads a half"
        }
      ; { protocol = "can"
        ; firmware = "can"
        ; unit = "bit/s"
        ; cycles = 1
        ; make = loaded "can"
        ; pio = None
        ; note = ""
        }
      ]
  ;;

  (* the slack of the worst deadline, if the analyser and the kernel accept [c] *)
  let accepted (c : Certified.t) =
    Option.try_with (fun () ->
      let program = Asm.assemble c.source |> ok_exn in
      let config = Asm.Program.configure program c.config in
      let words = Asm.Program.words program |> ok_exn in
      let period = if Option.is_some c.period_floor then None else c.period in
      let single_capture_edge = c.single_capture_edge in
      let verdict =
        Analyser.check
          ?period
          ?period_floor:c.period_floor
          ~single_capture_edge
          ~config
          program
        |> ok_exn
      in
      let table =
        Analyser.analyse
          ?period
          ?period_floor:c.period_floor
          ~single_capture_edge
          ~config
          program.instructions
        |> Kernel.Table.of_analyser
      in
      Kernel.check
        ?period:(Option.first_some c.period_floor period)
        ~single_capture_edge
        ~config
        ~words
        table
      |> ok_exn;
      verdict.worst_slack)
  ;;

  let fastest t =
    List.find_map (List.range 1 65) ~f:(fun setting ->
      Option.map (accepted (t.make setting)) ~f:(fun slack -> setting, slack))
  ;;

  (* firmware whose bit period is in its source, as the library ships it *)
  let fixed =
    [ "usb", "usb_tx", "bit/s", 32, None
    ; "ws2812", "ws2812", "bit/s", 18, Some 10
    ; "ws2812", "ws2812_standard", "bit/s", 60, Some 10
    ]
  ;;

  let assumes (c : Certified.t) =
    List.filter_opt
      [ Option.some_if (Option.is_some c.period_floor) "every load from it up"
      ; Option.some_if c.single_capture_edge "one edge before capture"
      ; Option.some_if c.no_wrap "no wrap"
      ]
  ;;
end

let%expect_test "the fastest rate each protocol is certified at" =
  printf
    "%-15s %-18s %-12s %6s %5s %4s  %s\n"
    "protocol"
    "firmware"
    "fastest"
    "cycles"
    "slack"
    "pio"
    "assumes";
  List.iter Rate.all ~f:(fun t ->
    match Rate.fastest t with
    | None -> printf "%-15s %-18s refused at every setting\n" t.protocol t.firmware
    | Some (setting, slack) ->
      let cycles = t.cycles * setting in
      let c = t.make setting in
      printf
        "%-15s %-18s %-12s %6d %5s %4s  %s\n"
        t.protocol
        t.firmware
        (Bench.rate ~unit:t.unit cycles)
        cycles
        (Option.value_map slack ~default:"-" ~f:Int.to_string)
        (Option.value_map t.pio ~default:"-" ~f:Int.to_string)
        (String.concat
           ~sep:", "
           (List.filter
              [ Rate.assumes c |> String.concat ~sep:", "; t.note ]
              ~f:(Fn.non String.is_empty))));
  List.iter Rate.fixed ~f:(fun (protocol, firmware, unit, cycles, pio) ->
    let c = Rate.lib firmware in
    printf
      "%-15s %-18s %-12s %6d %5s %4s  %s\n"
      protocol
      firmware
      (Bench.rate ~unit cycles)
      cycles
      (match Rate.accepted c with
       | Some slack -> Option.value_map slack ~default:"-" ~f:Int.to_string
       | None -> "REFUSED")
      (Option.value_map pio ~default:"-" ~f:Int.to_string)
      ("as shipped, " ^ String.concat ~sep:", " (Rate.assumes c)));
  (* a target is not held to a deadline: test_spi_target runs it against the controller *)
  List.iter Spi_cs.Mode.all ~f:(fun mode ->
    let cycles = 2 * Spi_target.shortest_half in
    printf
      "%-15s %-18s %-12s %6d %5s %4s  %s\n"
      "spi target"
      (sprintf "spi_target_mode%d" (Spi_cs.Mode.to_int mode))
      (Bench.rate ~unit:"Hz" cycles)
      cycles
      "-"
      "-"
      "simulated against Spi_cs.master, not a kernel bound");
  [%expect
    {|
    protocol        firmware           fastest      cycles slack  pio  assumes
    uart tx         uart_tx_host_rate  12 Mbaud          4     0    8  every load from it up, no wrap
    uart rx         uart_rx_host_rate  6 Mbaud           8     1    8  every load from it up, one edge before capture, no wrap, the host loads half a bit
    spi controller  spi_master         6 MHz             8     0    4  no CS
    spi controller  spi_cs_mode0       6 MHz             8     0    4  no wrap, CS 4 cycles before and 8 after, 3 us apart
    spi controller  spi_cs_mode1       6 MHz             8     0    4  no wrap, CS 4 cycles before and 8 after, 3 us apart
    spi controller  spi_cs_mode2       6 MHz             8     0    4  no wrap, CS 4 cycles before and 8 after, 3 us apart
    spi controller  spi_cs_mode3       6 MHz             8     0    4  no wrap, CS 4 cycles before and 8 after, 3 us apart
    i2c controller  i2c_master_fast    1.5 MHz          32     0   32  every load from it up, no wrap, the host loads a quarter, and the datasheet rows ask for more
    jtag            jtag               6 MHz             8     0    -
    swd             swd                2.4 MHz          20     0    -  every load from it up, no wrap, the host loads a half
    can             can                3.2 Mbit/s       15     0    -  every load from it up, no wrap
    usb             usb_tx             1.5 Mbit/s       32    16    -  as shipped,
    ws2812          ws2812             2.667 Mbit/s     18     0   10  as shipped, no wrap
    ws2812          ws2812_standard    800 kbit/s       60     9   10  as shipped, no wrap
    spi target      spi_target_mode0   1.5 MHz          32     -    -  simulated against Spi_cs.master, not a kernel bound
    spi target      spi_target_mode1   1.5 MHz          32     -    -  simulated against Spi_cs.master, not a kernel bound
    spi target      spi_target_mode2   1.5 MHz          32     -    -  simulated against Spi_cs.master, not a kernel bound
    spi target      spi_target_mode3   1.5 MHz          32     -    -  simulated against Spi_cs.master, not a kernel bound
    |}]
;;

(* The common bauds, at the bit period nearest in cycles: its error, and whether the
   firmware the host loads it into is certified there. *)
let%expect_test "the common baud rates" =
  let clock_hz = Bench.clock_hz in
  let certified name setting =
    match Rate.accepted (Rate.loaded name setting) with
    | Some slack ->
      sprintf "slack %s" (Option.value_map slack ~default:"-" ~f:Int.to_string)
    | None -> "refused"
  in
  let error ~cycles baud =
    100. *. ((Float.of_int clock_hz /. Float.of_int cycles /. Float.of_int baud) -. 1.)
  in
  printf "%9s  %5s %7s %-10s  %5s %7s %-10s\n" "baud" "tx" "error" "" "rx" "error" "";
  List.iter
    [ 9600
    ; 19200
    ; 38400
    ; 57600
    ; 115200
    ; 230400
    ; 460800
    ; 921600
    ; 1_000_000
    ; 2_000_000
    ; 3_000_000
    ; 4_000_000
    ; 6_000_000
    ; 12_000_000
    ; 24_000_000
    ]
    ~f:(fun baud ->
      let bit = Float.iround_nearest_exn (Float.of_int clock_hz /. Float.of_int baud) in
      let half = Int.max 1 (bit / 2) in
      printf
        "%9d  %5d %+6.2f%% %-10s  %5d %+6.2f%% %-10s\n"
        baud
        bit
        (error ~cycles:bit baud)
        (certified "uart_tx_host_rate" bit)
        half
        (error ~cycles:(2 * half) baud)
        (certified "uart_rx_host_rate" half));
  [%expect
    {|
        baud     tx   error                rx   error
        9600   5000  +0.00% slack 4996   2500  +0.00% slack 4993
       19200   2500  +0.00% slack 2496   1250  +0.00% slack 2493
       38400   1250  +0.00% slack 1246    625  +0.00% slack 1243
       57600    833  +0.04% slack 829     416  +0.16% slack 825
      115200    417  -0.08% slack 413     208  +0.16% slack 409
      230400    208  +0.16% slack 204     104  +0.16% slack 201
      460800    104  +0.16% slack 100      52  +0.16% slack 97
      921600     52  +0.16% slack 48       26  +0.16% slack 45
     1000000     48  +0.00% slack 44       24  +0.00% slack 41
     2000000     24  +0.00% slack 20       12  +0.00% slack 17
     3000000     16  +0.00% slack 12        8  +0.00% slack 9
     4000000     12  +0.00% slack 8         6  +0.00% slack 5
     6000000      8  +0.00% slack 4         4  +0.00% slack 1
    12000000      4  +0.00% slack 0         2  +0.00% refused
    24000000      2  +0.00% refused         1  +0.00% refused
    |}]
;;

(* UM10204's Standard-mode and Fast-mode, each as the one-cycle margin on its rows allows
   at the bench's clock, the library's and the asymmetric clock, against the rows. *)
let%expect_test "i2c at 100 and 400 kHz" =
  printf
    "%-18s %10s  %-5s %-26s %s\n"
    "firmware"
    "SCL"
    "rows"
    "tightest row"
    "certificate";
  List.iter
    [ "i2c_standard", "i2c_master_standard"
    ; "i2c_standard_asym", "i2c_master_standard_asym"
    ; "i2c_fast", "i2c_master_fast"
    ; "i2c_fast_asym", "i2c_master_fast_asym"
    ]
    ~f:(fun (name, certified) ->
      let verdicts = Datasheet.check Library.limits (Library.find_bench_exn name) in
      let spare ((t : Datasheet.t), (v : Datasheet.Verdict.t)) =
        Option.map v.bound ~f:(fun bound ->
          let spare =
            match t.limit with
            | At_least _ -> bound - v.needed
            | At_most _ -> v.needed - bound
          in
          spare, t.parameter)
      in
      let tightest =
        List.filter_map verdicts ~f:spare
        |> List.min_elt ~compare:[%compare: int * string]
      in
      let period =
        List.find_map verdicts ~f:(fun (t, v) ->
          if String.equal t.parameter "1/fSCL" then v.bound else None)
      in
      let c = Library.find_certified_exn certified in
      printf
        "%-18s %10s  %d/%d   %-26s %s\n"
        name
        (Option.value_map period ~default:"-" ~f:(Bench.rate ~unit:"Hz"))
        (List.count verdicts ~f:(fun (_, v) -> v.ok))
        (List.length verdicts)
        (Option.value_map tightest ~default:"-" ~f:(fun (spare, parameter) ->
           sprintf "%s, %d cycles spare" parameter spare))
        (match Rate.accepted { c with period_floor = None } with
         | Some slack ->
           sprintf
             "%s, slack %s"
             certified
             (Option.value_map slack ~default:"-" ~f:Int.to_string)
         | None -> sprintf "%s refused" certified));
  [%expect
    {|
    firmware                  SCL  rows  tightest row               certificate
    i2c_standard        99.17 kHz  8/8   THIGH, 2 cycles spare      i2c_master_standard, slack 113
    i2c_standard_asym   99.79 kHz  8/8   1/fSCL, 0 cycles spare     i2c_master_standard_asym, slack 90
    i2c_fast              375 kHz  8/8   TLOW, 0 cycles spare       i2c_master_fast, slack 24
    i2c_fast_asym       396.7 kHz  8/8   1/fSCL, 0 cycles spare     i2c_master_fast_asym, slack 22
    |}]
;;
