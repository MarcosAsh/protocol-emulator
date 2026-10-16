open! Core
open Protocol_emulator

let diagram name =
  In_channel.read_all [%string "diagrams/%{name}.json"] |> Wavejson.parse |> ok_exn
;;

let%expect_test "3% too fast: the original is taken, the mutant refused" =
  List.iter [ "uart_tx"; "uart_rx"; "dshot"; "spi_master"; "ws2812" ] ~f:(fun name ->
    let r = Diagram_mutation.run (diagram name) ~percent:3. |> ok_exn in
    print_endline
      [%string "%{name}\noriginal: %{Diagram_mutation.Verdict.to_string r.original}"];
    print_endline [%string "mutant: %{Diagram_mutation.Verdict.to_string r.mutant}\n"]);
  [%expect {|
    uart_tx
    original: taken, 11 steps
    mutant: refused: ("outside the table class"
     ("bit 0 has no step to move the host bit on: a Shift needs 26 cycles"
      (steps "period 2")))

    uart_rx
    original: taken, 10 steps
    mutant: taken, 10 steps

    dshot
    original: taken, 50 steps
    mutant: taken, 50 steps

    spi_master
    original: taken, 18 steps
    mutant: refused: ("outside the table class"
     ("bit 0 has no step to move the host bit on: a Shift needs 26 cycles, reading inside its input cell"
      (steps "period 1, second half")))

    ws2812
    original: taken, 38 steps
    edge a<->b T0H 250ns..550ns: 520 ns, holds
    edge a<->c T1H 650ns..950ns: 940 ns, holds
    edge b<->d T0L 700ns..1000ns: 980 ns, holds
    edge c<->d T1L 300ns..600ns: 560 ns, holds
    mutant: refused: ("outside the table class"
     ("the host's flag before a pass has no step to move the host bit on: a Shift needs 26 cycles"
      (steps "period 1 (copy 1)")))
    |}]
;;

let%expect_test "a percentage outside (0, 100)" =
  List.iter [ 0.; 100.; -1. ] ~f:(fun percent ->
    print_s
      [%sexp
        (Diagram_mutation.faster (diagram "uart_tx") ~percent : Wavejson.t Or_error.t)]);
  [%expect {|
    (Error ("a mutation is a percentage in (0, 100)" (percent 0)))
    (Error ("a mutation is a percentage in (0, 100)" (percent 100)))
    (Error ("a mutation is a percentage in (0, 100)" (percent -1)))
    |}]
;;
