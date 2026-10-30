open! Core
open Protocol_emulator

(* The library's firmware taken as what an unchecked generator wrote: a protocol file's
   string, the ppx, the table compiler. Each deadline wait, given one cycle of [nop] more
   than its slack, is reached late on its worst path, and the kernel has to refuse it, so
   a slip in whatever wrote the firmware costs a refusal and never a late edge. Given its
   slack exactly, the wait is still on time. A mutant past program memory never reaches
   the check, so it is counted apart from the refusals. *)

let accepted (c : Certified.t) source =
  let check ?period ?period_floor () =
    Timed_program.check
      ?period
      ?period_floor
      ~single_capture_edge:c.single_capture_edge
      ~config:c.config
      source
    |> Result.is_ok
  in
  check ?period:c.period ()
  && Option.value_map c.period_floor ~default:true ~f:(fun floor ->
    check ~period_floor:floor ())
;;

(* each deadline wait's pc and its least slack, at the period the firmware is certified at *)
let waits (c : Certified.t) =
  Timed_program.of_source_exn
    ?period:c.period
    ~single_capture_edge:c.single_capture_edge
    ~config:c.config
    c.source
  |> Timed_program.rows
  |> List.filter_map ~f:(fun (row : Analyser.Row.t) ->
    match row.instruction with
    | Op { op = Wait (Deadline _); _ } ->
      Option.bind row.slack ~f:(fun slack -> slack.lo)
      |> Option.map ~f:(fun slack -> row.pc, slack)
    | _ -> None)
;;

let%expect_test "every deadline wait in the library, a cycle late, is refused" =
  let firmware = (Library.certified @ Library.time_triggered) @ [ Library.stamped ] in
  let totals =
    List.fold firmware ~init:(0, 0, 0, 0) ~f:(fun (count, refused, long, on_time) c ->
      let waits = waits c in
      let too_long, built =
        List.partition_tf waits ~f:(fun (wait_pc, slack) ->
          Result.is_error (Asm.assemble (Delay_variants.with_nops c ~wait_pc (slack + 1))))
      in
      let late, in_time =
        List.partition_tf built ~f:(fun (wait_pc, slack) ->
          not (accepted c (Delay_variants.with_nops c ~wait_pc (slack + 1))))
      in
      let at_slack =
        List.count waits ~f:(fun (wait_pc, slack) ->
          accepted c (Delay_variants.with_nops c ~wait_pc slack))
      in
      if not (List.is_empty in_time)
      then
        print_s
          [%message
            "accepted a cycle late" c.name ~pcs:(List.map in_time ~f:fst : int list)];
      printf
        "%-26s %2d waits, %2d refused a cycle late, %2d too long, %2d accepted at their \
         slack\n"
        c.name
        (List.length waits)
        (List.length late)
        (List.length too_long)
        at_slack;
      ( count + List.length waits
      , refused + List.length late
      , long + List.length too_long
      , on_time + at_slack ))
  in
  let count, refused, long, on_time = totals in
  printf
    "\n\
     %d firmwares, %d deadline waits: %d refused a cycle late, %d too long to assemble a \
     cycle late, %d accepted at their slack\n"
    (List.length firmware)
    count
    refused
    long
    on_time;
  [%expect
    {|
    uart_tx                     3 waits,  3 refused a cycle late,  0 too long,  3 accepted at their slack
    uart_tx16                   3 waits,  3 refused a cycle late,  0 too long,  3 accepted at their slack
    uart_tx_host_rate           3 waits,  3 refused a cycle late,  0 too long,  0 accepted at their slack
    uart_rx                     2 waits,  2 refused a cycle late,  0 too long,  2 accepted at their slack
    uart_rx_host_rate           2 waits,  2 refused a cycle late,  0 too long,  0 accepted at their slack
    spi_master                  3 waits,  3 refused a cycle late,  0 too long,  3 accepted at their slack
    spi_slave                   0 waits,  0 refused a cycle late,  0 too long,  0 accepted at their slack
    i2c_master                 31 waits, 31 refused a cycle late,  0 too long, 31 accepted at their slack
    i2c_slave                   0 waits,  0 refused a cycle late,  0 too long,  0 accepted at their slack
    i2c_logger                 25 waits, 25 refused a cycle late,  0 too long, 25 accepted at their slack
    i2c_master_standard        43 waits, 43 refused a cycle late,  0 too long,  0 accepted at their slack
    i2c_master_fast            37 waits, 37 refused a cycle late,  0 too long,  0 accepted at their slack
    i2c_master_standard_asym   43 waits, 43 refused a cycle late,  0 too long, 43 accepted at their slack
    i2c_master_fast_asym       37 waits, 37 refused a cycle late,  0 too long, 37 accepted at their slack
    i2c_controller_wire        25 waits, 25 refused a cycle late,  0 too long,  0 accepted at their slack
    i2c_target_wire             0 waits,  0 refused a cycle late,  0 too long,  0 accepted at their slack
    usb_tx                     11 waits, 11 refused a cycle late,  0 too long, 11 accepted at their slack
    usb_rx                      4 waits,  4 refused a cycle late,  0 too long,  4 accepted at their slack
    usb_device                 54 waits, 54 refused a cycle late,  0 too long, 54 accepted at their slack
    edge_meter                  2 waits,  2 refused a cycle late,  0 too long,  2 accepted at their slack
    ws2812                      4 waits,  4 refused a cycle late,  0 too long,  4 accepted at their slack
    ws2812_standard             4 waits,  4 refused a cycle late,  0 too long,  4 accepted at their slack
    ethernet                    1 waits,  0 refused a cycle late,  1 too long,  0 accepted at their slack
    one_wire                   15 waits, 15 refused a cycle late,  0 too long,  0 accepted at their slack
    ps2                        12 waits, 12 refused a cycle late,  0 too long,  0 accepted at their slack
    jtag                        3 waits,  3 refused a cycle late,  0 too long,  3 accepted at their slack
    can                        10 waits, 10 refused a cycle late,  0 too long,  0 accepted at their slack
    dshot600                    4 waits,  4 refused a cycle late,  0 too long,  4 accepted at their slack
    sent                        9 waits,  9 refused a cycle late,  0 too long,  0 accepted at their slack
    cec                        20 waits, 20 refused a cycle late,  0 too long,  0 accepted at their slack
    spi_cs_mode0                6 waits,  6 refused a cycle late,  0 too long,  6 accepted at their slack
    spi_cs_mode1                6 waits,  6 refused a cycle late,  0 too long,  6 accepted at their slack
    spi_cs_mode2                6 waits,  6 refused a cycle late,  0 too long,  6 accepted at their slack
    spi_cs_mode3                6 waits,  6 refused a cycle late,  0 too long,  6 accepted at their slack
    spi_cs_mode0_default_pins   6 waits,  6 refused a cycle late,  0 too long,  6 accepted at their slack
    spi_cs_mode1_default_pins   6 waits,  6 refused a cycle late,  0 too long,  6 accepted at their slack
    spi_cs_mode2_default_pins   6 waits,  6 refused a cycle late,  0 too long,  6 accepted at their slack
    spi_cs_mode3_default_pins   6 waits,  6 refused a cycle late,  0 too long,  6 accepted at their slack
    spi_target_mode0            0 waits,  0 refused a cycle late,  0 too long,  0 accepted at their slack
    spi_target_mode1            0 waits,  0 refused a cycle late,  0 too long,  0 accepted at their slack
    spi_target_mode2            0 waits,  0 refused a cycle late,  0 too long,  0 accepted at their slack
    spi_target_mode3            0 waits,  0 refused a cycle late,  0 too long,  0 accepted at their slack
    swd                        52 waits, 52 refused a cycle late,  0 too long,  0 accepted at their slack
    table                       2 waits,  2 refused a cycle late,  0 too long,  2 accepted at their slack
    table_open_drain            2 waits,  2 refused a cycle late,  0 too long,  2 accepted at their slack
    nec_tx                     22 waits,  0 refused a cycle late, 22 too long,  0 accepted at their slack
    nec_rx                      4 waits,  3 refused a cycle late,  1 too long,  3 accepted at their slack
    snorble                     5 waits,  5 refused a cycle late,  0 too long,  5 accepted at their slack
    plinkoo                    15 waits, 15 refused a cycle late,  0 too long, 15 accepted at their slack
    microwire                   7 waits,  7 refused a cycle late,  0 too long,  7 accepted at their slack
    ir_rc6                     22 waits,  0 refused a cycle late, 22 too long,  0 accepted at their slack
    caliper                    11 waits, 11 refused a cycle late,  0 too long,  0 accepted at their slack
    xy2_100                    10 waits, 10 refused a cycle late,  0 too long, 10 accepted at their slack
    lfast                      27 waits, 27 refused a cycle late,  0 too long, 27 accepted at their slack
    uart_tx_stream              3 waits,  3 refused a cycle late,  0 too long,  3 accepted at their slack
    spi_master_stream           3 waits,  3 refused a cycle late,  0 too long,  3 accepted at their slack
    uart_tx_stamped             4 waits,  4 refused a cycle late,  0 too long,  4 accepted at their slack

    57 firmwares, 647 deadline waits: 601 refused a cycle late, 46 too long to assemble a cycle late, 362 accepted at their slack
    |}]
;;
