open! Core
open Protocol_emulator

(* The table the README quotes: every firmware in the library, what the analyser says of
   it and what that rests on. The proofs that check each certificate on the RTL are
   [make -C formal certificates] and [make -C formal inductive_certificates]. *)
let%expect_test "the firmware library and its certificates" =
  printf "%-18s %5s  %8s  %5s  %s\n" "firmware" "words" "deadline" "slack" "assumes";
  List.iter Certified.all ~f:(fun t ->
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
    uart_rx               21         2      3  one edge before capture, no wrap
    spi_master            16         3      4
    spi_slave              6         0      -
    i2c_master            83        25      2  no wrap
    i2c_slave             72         0      -
    i2c_logger            73        25      1
    usb_tx                65        11     16  period 32
    usb_rx                29         2      8  period 32, one edge before capture, no wrap
    usb_device           470        54      6  period 32, one edge before capture, no wrap
    edge_meter            12         2      6
    ws2812                32         4      0  no wrap
    ethernet              24         1  63987  period 64000
    one_wire              48        15    295  period 300
    ps2                   65        12    992  period 1000
    jtag                  15         3      0
    |}]
;;
