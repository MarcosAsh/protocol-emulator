open! Core
open! Hardcaml
open Protocol_emulator

let base = 0

let memory words =
  let words = Array.of_list words in
  fun at -> if at < Array.length words then words.(at) else 0
;;

let certify (case : Firmware_inventory.t) =
  let config = Timed_program.config case.timed in
  let words = Timed_program.words case.timed in
  let table = Kernel.Table.of_analyser (Timed_program.rows case.timed) in
  let certificate = Load_check.of_table ~config ~words table |> ok_exn in
  config, words, Load_check.to_words certificate
;;

let walk (case : Firmware_inventory.t) ~config ~words ~certificate =
  Load_check.walk
    ?loaded:case.period
    ~single_capture_edge:case.single_capture_edge
    ~config
    ~words
    ~memory:(memory certificate)
    ~base
    ()
;;

(* Each firmware's certificate, as the host would write it, and the chip's verdict on
   it. Where the walk accepts, the kernel accepts the rows it held, so the run is
   covered by the kernel's theorem. *)
let%expect_test "every firmware against the chip's walk" =
  printf "%-26s %5s  %5s  %s\n" "firmware" "words" "table" "walk";
  List.iter Firmware_inventory.all ~f:(fun case ->
    let config, words, certificate = certify case in
    let verdict =
      match walk case ~config ~words ~certificate with
      | Error { pc; reason } -> sprintf "refused at %d: %s" pc reason
      | Ok rows ->
        (match
           Kernel.check
             ?period:case.period
             ~single_capture_edge:case.single_capture_edge
             ~config
             ~words
             rows
         with
         | Ok () -> "accepted"
         | Error e -> "accepted, BUT the kernel refuses its rows: " ^ Error.to_string_hum e)
    in
    printf
      "%-26s %5d  %5d  %s\n"
      case.name
      (List.length words)
      (List.length certificate)
      verdict);
  [%expect {|
    firmware                   words  table  walk
    uart_tx                       15     15  accepted
    uart_tx16                     15     15  accepted
    uart_tx_host_rate             17     15  accepted
    uart_rx                       19     20  accepted
    spi_master                    16     15  accepted
    spi_slave                      6      5  accepted
    i2c_master                    99     78  accepted
    i2c_slave                     72     39  accepted
    i2c_logger                    73     38  accepted
    usb_tx                        65     84  accepted
    usb_rx                        29     31  accepted
    usb_device                   470    501  accepted
    edge_meter                    12     10  accepted
    ws2812                        32     48  accepted
    ethernet                      24     29  accepted
    one_wire                      48     49  accepted
    ps2                           65     40  accepted
    jtag                          15     15  accepted
    can                           56     73  accepted
    dshot600                      21     28  accepted
    sent                          83     58  accepted
    cec                           71     93  accepted
    asm/data_stream                4      5  accepted
    asm/edge_logger_echo          13     11  accepted
    asm/edge_logger_wire           8      8  accepted
    asm/ethernet                  24     29  accepted
    asm/i2c_master_marked         84     64  accepted
    asm/i2c_start_watch           10      7  accepted
    asm/quiet_watch               23     18  refused at 8: in time
    asm/scl_rise                  12      5  accepted
    asm/scrub                      4      2  accepted
    asm/self_check_wire           69     45  accepted
    asm/uart_rx_wire              19     20  accepted
    asm/uart_tx                   15     15  accepted
    asm/uart_tx_host_rate         17     15  accepted
    asm/wrapped_loop               5     10  accepted
    bench/i2c_master             101     78  accepted
    bench/i2c_master_stretch     163    132  accepted
    bench/can_sender              64     73  accepted
    bench/can_receiver           242    275  accepted
    bench/sk6812                  32     48  accepted
    bench/start_hold               9      2  accepted
    bench/swd                    232    177  accepted
    bench/spi_cs_mode0            33     23  accepted
    bench/spi_cs_mode1            33     23  accepted
    bench/spi_cs_mode2            33     23  accepted
    bench/spi_cs_mode3            33     23  accepted
    |}]
;;

let uart_tx =
  List.find_exn Firmware_inventory.all ~f:(fun c -> String.equal c.name "uart_tx")
;;

(* What the chip reads is the program in its own memory: a certificate for one program
   does not pass another, and a table out of order or short refuses. *)
let%expect_test "the walk refuses what it was not given" =
  let config, words, certificate = certify uart_tx in
  let show what result =
    printf
      "%s: %s\n"
      what
      (match result with
       | Ok _ -> "accepted"
       | Error { Load_check.Rejection.pc; reason } -> sprintf "refused at %d: %s" pc reason)
  in
  show "as written" (walk uart_tx ~config ~words ~certificate);
  (* the README's late firmware: the bit loop's out given 13 cycles of delay *)
  let late =
    String.substr_replace_first
      (Timed_program.source uart_tx.timed)
      ~pattern:"out pins, 1"
      ~with_:"out pins, 1 [13]"
    |> Asm.assemble
    |> ok_exn
    |> Asm.Program.words
    |> ok_exn
  in
  show "out pins, 1 [13]" (walk uart_tx ~config ~words:late ~certificate);
  let count = List.hd_exn certificate in
  show
    "an entry left off"
    (walk uart_tx ~config ~words ~certificate:((count - 1) :: List.tl_exn certificate));
  show
    "an entry twice"
    (walk
       uart_tx
       ~config
       ~words
       ~certificate:
         ((count + 1)
          :: List.nth_exn certificate 1
          :: (List.sub certificate ~pos:2 ~len:3 @ List.drop certificate 2)));
  [%expect {|
    as written: accepted
    out pins, 1 [13]: refused at 10: target phase
    an entry left off: refused at 1: next period
    an entry twice: refused at 2: a table entry out of order
    |}]
;;

(* USB's device address is in its words, patched at SET_ADDRESS. A certificate for address
   0 with x and y left whole passes every address's program, so the chip checks a patch
   against the certificate already in its data memory. *)
let%expect_test "one usb certificate serves every address" =
  let config = Firmware.usb_device_config in
  let program address =
    Asm.assemble (Firmware.usb_device ~address ~half_period:16)
    |> ok_exn
    |> Asm.Program.words
    |> ok_exn
  in
  let certificate =
    Load_check.of_program
      ~registers_whole:true
      ~period:32
      ~single_capture_edge:true
      ~config
      (program 0)
    |> ok_exn
    |> Load_check.to_words
  in
  let refused =
    List.filter (List.range 0 128) ~f:(fun address ->
      Result.is_error
        (Load_check.walk
           ~loaded:32
           ~single_capture_edge:true
           ~config
           ~words:(program address)
           ~memory:(memory certificate)
           ~base
           ()))
  in
  print_s [%message (List.length certificate : int) (refused : int list)];
  [%expect {| (("List.length certificate" 483) (refused ())) |}]
;;
