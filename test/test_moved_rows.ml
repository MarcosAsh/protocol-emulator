open! Core
open! Hardcaml
open Protocol_emulator

(* Each bounded row of the library's tables moved a cycle earlier and later: its phase,
   and where a capture is armed or taken, its age. The kernel refuses every one. *)
let%expect_test "the kernel refuses each row moved by a cycle" =
  let move by b = Bits.(b +: of_signed_int ~width:(width b) by) in
  List.iter Certified.all ~f:(fun (c : Certified.t) ->
    let program = Asm.assemble c.source |> ok_exn in
    let config = Asm.Program.configure program c.config in
    let single_capture_edge = c.single_capture_edge in
    let words = Asm.Program.words program |> ok_exn in
    let rows =
      Analyser.analyse ?period:c.period ~single_capture_edge ~config program.instructions
    in
    let table = Kernel.Table.of_analyser rows in
    let accepted pc f =
      let table = Array.copy table in
      table.(pc) <- f table.(pc);
      Kernel.check ?period:c.period ~single_capture_edge ~config ~words table
      |> Result.is_ok
    in
    let tries =
      List.concat_map rows ~f:(fun (row : Analyser.Row.t) ->
        let phase =
          match row.phase with
          | { lo = Some _; hi = Some _ } when row.pc > 0 ->
            List.map [ -1; 1 ] ~f:(fun by ->
              ( "phase"
              , row.pc
              , by
              , fun (r : _ Kernel.Row.t) ->
                  { r with phase_lo = move by r.phase_lo; phase_hi = move by r.phase_hi }
              ))
          | _ -> []
        in
        (* an age never goes below zero *)
        let arm =
          match row.since_arm with
          | Some { lo = Some lo; hi = Some _ } when row.pc > 0 ->
            List.filter_map [ -1; 1 ] ~f:(fun by ->
              Option.some_if
                (lo + by >= 0)
                ( (if row.captured then "capture" else "arm")
                , row.pc
                , by
                , fun (r : _ Kernel.Row.t) ->
                    { r with arm_lo = move by r.arm_lo; arm_hi = move by r.arm_hi } ))
          | _ -> []
        in
        phase @ arm)
    in
    let count what =
      List.count tries ~f:(fun (name, _, _, _) -> String.equal name what)
    in
    let accepted =
      List.filter_map tries ~f:(fun (name, pc, by, f) ->
        Option.some_if (accepted pc f) (name, pc, by))
    in
    print_s
      [%message
        c.name
          ~phase:(count "phase" : int)
          ~arm:(count "arm" : int)
          ~capture:(count "capture" : int)
          (accepted : (string * int * int) list)]);
  [%expect
    {|
    (uart_tx (phase 18) (arm 0) (capture 0) (accepted ()))
    (uart_tx16 (phase 18) (arm 0) (capture 0) (accepted ()))
    (uart_tx_host_rate (phase 18) (arm 0) (capture 0) (accepted ()))
    (uart_rx (phase 26) (arm 2) (capture 8) (accepted ()))
    (spi_master (phase 20) (arm 0) (capture 0) (accepted ()))
    (spi_slave (phase 0) (arm 0) (capture 0) (accepted ()))
    (i2c_master (phase 154) (arm 0) (capture 0) (accepted ()))
    (i2c_slave (phase 0) (arm 0) (capture 0) (accepted ()))
    (i2c_logger (phase 138) (arm 0) (capture 0) (accepted ()))
    (usb_tx (phase 120) (arm 0) (capture 0) (accepted ()))
    (usb_rx (phase 42) (arm 2) (capture 8) (accepted ()))
    (usb_device (phase 892) (arm 4) (capture 22) (accepted ()))
    (edge_meter (phase 18) (arm 14) (capture 0) (accepted ()))
    (ws2812 (phase 60) (arm 0) (capture 0) (accepted ()))
    (ethernet (phase 30) (arm 0) (capture 0) (accepted ()))
    (one_wire (phase 82) (arm 0) (capture 0) (accepted ()))
    (ps2 (phase 86) (arm 0) (capture 0) (accepted ()))
    (jtag (phase 20) (arm 0) (capture 0) (accepted ()))
    (can (phase 94) (arm 0) (capture 0) (accepted ()))
    (dshot600 (phase 34) (arm 0) (capture 0) (accepted ()))
    (sent (phase 154) (arm 0) (capture 0) (accepted ()))
    (cec (phase 128) (arm 0) (capture 0) (accepted ()))
    |}]
;;
