open! Core

(* pio_import's verdict lines and exit code: 0 certified, 2 refused or not certified. *)
let run args =
  let command =
    String.concat
      ~sep:" "
      (("../bin/pio_import.exe" :: List.map args ~f:Filename.quote)
       @ [ "| grep '^; [a-z_0-9]* at\\|^; limit\\|^; carrier\\|^((words'; exit \
            ${PIPESTATUS[0]}"
         ])
  in
  Out_channel.flush stdout;
  let status = Sys_unix.command ("bash -c " ^ Filename.quote command) in
  printf "exit %d\n" status
;;

let%expect_test "i2c at its own rate is refused on tHD;STA, by name" =
  run [ "pico_examples/i2c.pio"; "-program"; "i2c"; "-own-rate" ];
  [%expect
    {|
    ; i2c at k = 15, refused: tHD;STA
    ; limit: tHD;STA, SDA low to SCL low: the kernel proves 150 cycles, 3.125 us at 48 MHz, under 4.0 us (UM10204 Rev. 7.0, table 11, p.44, Standard-mode)
    ((words 474) (deadline_waits 193) (worst_slack (0)))
    exit 2
    |}]
;;

let%expect_test "-k and -own-rate together, or a rate the example has not, is a usage \
                 error"
  =
  run [ "pico_examples/i2c.pio"; "-program"; "i2c"; "-own-rate"; "-k"; "15" ];
  run [ "pico_examples/squarewave.pio"; "-own-rate" ];
  [%expect
    {|
    one of -k, -own-rate and -carrier
    exit 1
    squarewave: no rate of its own to run at
    exit 1
    |}]
;;

let%expect_test "the bench's three, each on the carrier's pins at its example's rate" =
  List.iter
    [ "ws2812.pio", "ws2812"; "uart_tx.pio", "uart_tx"; "spi.pio", "spi_cpha0_cs" ]
    ~f:(fun (file, program) ->
      run [ "pico_examples/" ^ file; "-program"; program; "-carrier" ]);
  run [ "pico_examples/i2c.pio"; "-program"; "i2c"; "-carrier" ];
  [%expect
    {|
    ; ws2812 at k = 6, certified
    ; carrier: k for ws2812.c's 800 kHz
    ((words 73) (deadline_waits 29) (worst_slack (1)))
    exit 0
    ; uart_tx at k = 52.0833, certified
    ; carrier: k for uart_tx.c's 115200 baud
    ((words 105) (deadline_waits 80) (worst_slack (21)))
    exit 0
    ; spi_cpha0_cs at k = 12, certified
    ; carrier: k for the 1 MHz SCK spi_flash.c runs spi_cpha0 at
    ((words 136) (deadline_waits 37) (worst_slack (3)))
    exit 0
    i2c: no place on the carrier
    exit 1
    |}]
;;
