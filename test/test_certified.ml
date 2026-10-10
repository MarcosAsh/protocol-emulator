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
  [%expect {|
    firmware           words  deadline  slack  assumes
    uart_tx               15         3      4
    uart_tx16             15         3     12
    uart_tx_host_rate     17         3    430  period 434, no wrap
    uart_rx               19         2      7  one edge before capture, no wrap
    spi_master            16         3      4
    spi_slave              6         0      -
    i2c_master            99        31      5  no wrap
    i2c_slave             72         0      -
    i2c_logger            73        25      1
    usb_tx                65        11     16  period 32
    usb_rx                29         2      9  period 32, one edge before capture, no wrap
    usb_device           470        54      6  period 32, one edge before capture, no wrap
    edge_meter            12         2      6
    ws2812                32         4      0  no wrap
    ethernet              24         1  63987  period 64000, no wrap
    one_wire              48        15    295  period 300
    ps2                   65        12    992  period 1000
    jtag                  15         3      0
    can                   56        10     81  period 96, no wrap
    dshot600              21         4     14  no wrap
    sent                  83         9    129  period 150, no wrap
    cec                   71        20   2493  period 2500, no wrap
    table                112         2      0
    table_open_drain     112         2      0
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
  [%expect {|
    (uart_tx_host_rate (period (434)) (floor 4) (passes true) (one_less false))
    (QED "uart_tx_host_rate: every load of 4 or more")
    (counterexample "uart_tx_host_rate: every load of 3 or more"
     (model ((loaded 0000000000000011))))
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
    |}]
;;
