open! Core
open Protocol_emulator

(* Each firmware from the lowest clock to the highest, in MHz, and the limit that fails a
   hertz past each end; "-" where none does. *)
let%expect_test "the clocks each bench firmware stays certified at" =
  print_endline (Clock_window.to_string (Clock_window.all ()));
  [%expect
    {|
    uart_tx_9600        47.068 bit <= 106250 ns             48.000  48.970 bit >= 102083 ns
    uart_tx_19200       47.078 bit <= 53125 ns              48.000  48.960 bit >= 51041.7 ns
    uart_tx_38400       47.096 bit <= 26562.5 ns            48.000  48.940 bit >= 25520.8 ns
    uart_tx_57600       47.096 bit <= 17708.3 ns            48.000  48.901 bit >= 17013.9 ns
    uart_tx_115200      47.209 bit <= 8854.17 ns            48.000  48.901 bit >= 8506.94 ns
    uart_tx_230400      47.209 bit <= 4427.08 ns            48.000  48.666 bit >= 4253.47 ns
    i2c_master               -                              48.000  53.333 TSU:STA >= 600 ns
    i2c_master_stretch       -                              48.000  53.333 TSU:STA >= 600 ns
    i2c_standard             -                              48.000  48.300 1/fSCL >= 10000 ns
    i2c_fast                 -                              48.000  48.462 TLOW >= 1300 ns
    sk6812              45.000 T0H <= 400 ns                48.000  48.333 T >= 1200 ns
    one_wire            26.408 tLOW0 <= 120000 ns           48.000  48.615 tRSTH >= 480000 ns
    ps2                 38.420 CLK low <= 50000 ns          48.000  63.967 CLK low >= 30000 ns
    can                      -                              48.000  52.909 idle to SOF >= 22000 ns
    can_sender               -                              48.000  52.909 idle to SOF >= 22000 ns
    can_receiver        47.452 sender faster, read at pc 8  48.000  51.600 sender slower, read at pc 194
    cec                 45.958 start bit <= 4.7e+06 ns      48.000  50.232 start bit >= 4.3e+06 ns
    spi_cs_mode0             -                              48.000  51.000 tRES1 >= 3000 ns
    spi_cs_mode1             -                              48.000  51.000 tRES1 >= 3000 ns
    spi_cs_mode2             -                              48.000  51.000 tRES1 >= 3000 ns
    spi_cs_mode3             -                              48.000  51.000 tRES1 >= 3000 ns
    swd                      -                              48.000 288.005 SWCLK high >= 20.8333 ns
    snorble             46.774 tL1 <= 3100 ns               48.000  49.310 tL1 >= 2900 ns
    microwire           41.507 CS low period following an E/W instruction <= 3e+07 ns 48.000  51.250 Write data DI hold >= 800 ns
    uart_log            47.209 bit <= 8854.17 ns            48.000  48.901 bit >= 8506.94 ns
    |}]
;;

(* The teeth: each cliff holds at its clock and fails a hertz past, by [Datasheet.check]'s
   own sum, and every firmware holds at the clock it ships at. *)
let%expect_test "each cliff is exact" =
  let wrong =
    List.concat_map (Library.bench @ [ Uart.log ]) ~f:(fun bench ->
      List.filter_map
        (Datasheet.cliffs Library.limits bench)
        ~f:(fun (limit, bound, cliff) ->
          let ok clock_hz = (Datasheet.verdict limit ~clock_hz ~bound).ok in
          let exact =
            match cliff with
            | Never -> false
            | Up_to hz -> ok hz && (not (ok (hz + 1))) && ok 1
            | From hz -> ok hz && (not (ok (hz - 1))) && ok (hz * 2)
          in
          let shipped = ok bench.clock_hz in
          if exact && shipped
          then None
          else Some (bench.name, Clock_window.limit_name limit, exact, shipped)))
  in
  print_s [%sexp (wrong : (string * string * bool * bool) list)];
  [%expect {| () |}]
;;

(* The receiver's ends put the sender's bit inside its certified m and a hertz past puts
   it outside, where test_tolerance.ml shows the model losing a frame. *)
let%expect_test "the CAN receiver's window is its tolerance" =
  let r =
    Tolerance.Receiver.can_rx
      ~period:Can_node.Receiver.period
      ~sample:Can_node.Receiver.sample
      ()
  in
  let b = Tolerance.bounds r in
  let rate = Bench.clock_hz / Can_node.Receiver.period in
  let low, high = Clock_window.of_tolerance b ~rate in
  (* m = 2^16 hz / rate, cross-multiplied to stay exact *)
  let m hz = hz * Tolerance.unit
  and m' bound = bound * rate in
  print_s
    [%message
      ""
        ~low:(low : Clock_window.End.t)
        ~high:(high : Clock_window.End.t)
        ~inside:(m' b.least <= m low.hz && m high.hz <= m' b.most : bool)
        ~outside:(m (low.hz - 1) < m' b.least && m (high.hz + 1) > m' b.most : bool)];
  [%expect
    {|
    ((low ((hz 47452385) (limit "sender faster, read at pc 8")))
     (high ((hz 51599998) (limit "sender slower, read at pc 194"))) (inside true)
     (outside true))
    |}]
;;

(* The diagrams' limits as [Wavedrom.compile] checks them at a clock: it compiles at each
   end and refuses a hertz past, naming the edge. ws2812.json's 19, 19 and 22 cycles are a
   1.25 us bit at the rated 48 MHz. *)
let%expect_test "the diagrams' windows" =
  let read name = In_channel.read_all [%string "diagrams/%{name}.json"] in
  List.iter (Clock_window.diagrams ~dir:"diagrams") ~f:(fun (t : Clock_window.t) ->
    let source = read (String.chop_prefix_exn t.firmware ~prefix:"diagram ") in
    let compiles clock_hz = Or_error.is_ok (Wavedrom.of_string ~clock_hz source) in
    print_endline (Clock_window.to_string [ t ]);
    let low = (Option.value_exn t.lowest).hz
    and high = (Option.value_exn t.highest).hz in
    print_s
      [%message
        ""
          ~compiles_at_ends:(compiles low && compiles high : bool)
          ~refused_past:(not (compiles (low - 1) || compiles (high + 1)) : bool)]);
  print_s
    [%sexp
      (Wavedrom.of_string ~clock_hz:Bench.clock_hz (read "ws2812")
       |> Or_error.map ~f:ignore
       : unit Or_error.t)];
  [%expect
    {|
    diagram ws2812      47.368 T1H <= 950 ns                48.000  67.143 T0L >= 700 ns
    ((compiles_at_ends true) (refused_past true))
    (Ok ())
    |}]
;;
