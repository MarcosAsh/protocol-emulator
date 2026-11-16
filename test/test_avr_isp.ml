open! Core
open Protocol_emulator

(* The analyser and kernel verdicts on the firmware (it already compiles). *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Avr_isp.firmware));
  [%expect {| 47 words, 3 deadline waits, worst slack 16 |}]
;;

(* The bench's run against the ATmega88 model, fed the pins every cycle: programming
   enable, the three signature bytes and the low fuse. The host keeps the fifo topped up
   and reads one word per instruction. *)
let%expect_test "a target answers a programming enable, its signature and a fuse" =
  let machine =
    Machine.create
      ~config:(Timed_program.config Avr_isp.firmware)
      ~program:(Timed_program.words Avr_isp.firmware)
    |> ok_exn
  in
  let rec go machine device ~cycle ~words ~received =
    if cycle = 1_100_000
    then machine, device, List.rev received
    else (
      let machine, words =
        match words with
        | word :: rest when List.length machine.Machine.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx machine word |> ok_exn, rest
        | _ -> machine, words
      in
      let machine, received =
        match Machine.read_rx machine with
        | Some (word, machine) -> machine, word :: received
        | None -> machine, received
      in
      let machine =
        Machine.step
          machine
          ~inputs:(Bool.to_int (Avr_isp.Atmega88.miso device) lsl Avr_isp.miso)
      in
      let level pin = (machine.pin_out lsr pin) land 1 = 1 in
      let device =
        Avr_isp.Atmega88.step
          device
          ~sck:(level Avr_isp.sck)
          ~reset:(level Avr_isp.reset)
          ~mosi:(level Avr_isp.mosi)
      in
      go machine device ~cycle:(cycle + 1) ~words ~received)
  in
  let machine, device, received =
    go
      machine
      (Avr_isp.Atmega88.create ())
      ~cycle:0
      ~words:(List.concat_map Avr_isp.instructions ~f:Avr_isp.instruction)
      ~received:[]
  in
  let received = List.map received ~f:(sprintf "%04X") in
  print_s
    [%message
      ""
        ~log:
          (List.map (Avr_isp.Atmega88.log device) ~f:(List.map ~f:(sprintf "%02X"))
           : string list list)
        (received : string list)
        ~violations:(Avr_isp.Atmega88.violations device : string list)
        ~fault:(machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ((log
      ((AC 53 00 00) (30 00 00 00) (30 00 01 00) (30 00 02 00) (50 00 00 00)))
     (received (5300 001E 0093 000A 0062)) (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false))))
    |}]
;;
