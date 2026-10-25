open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Microwire.firmware));
  [%expect {| 69 words, 7 deadline waits, worst slack 13 |}]
;;

(* The bench's run against the NM93C06A model, fed the pins every cycle: enable, read
   register 5, write it with the 25.94 ms CS low after, read it back. The host keeps the
   fifo topped up and reads a word a frame. *)
let%expect_test "an EEPROM reads back what the host wrote" =
  let machine =
    Machine.create
      ~config:(Timed_program.config Microwire.firmware)
      ~program:(Timed_program.words Microwire.firmware)
    |> ok_exn
  in
  let words =
    List.concat
      [ Microwire.ewen; Microwire.read 5; Microwire.write 5 0xa5c3; Microwire.read 5 ]
  in
  let rec go machine device ~cycle ~words ~received =
    if cycle = 1_300_000
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
          ~inputs:(Bool.to_int (Microwire.Eeprom.dout device) lsl Microwire.do_)
      in
      let level pin = (machine.pin_out lsr pin) land 1 = 1 in
      let device =
        Microwire.Eeprom.step
          device
          ~cs:(level Microwire.cs)
          ~sk:(level Microwire.sk)
          ~di:(level Microwire.di)
      in
      go machine device ~cycle:(cycle + 1) ~words ~received)
  in
  let machine, device, received =
    go machine (Microwire.Eeprom.create ()) ~cycle:0 ~words ~received:[]
  in
  let received = List.map received ~f:(sprintf "%04X") in
  print_s
    [%message
      ""
        ~log:(Microwire.Eeprom.log device : string list)
        (received : string list)
        ~violations:(Microwire.Eeprom.violations device : string list)
        ~fault:(machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ((log
      (EWEN "READ 5: 5555" "WRITE 5 A5C3 done, CS low 25.942 ms" "READ 5: A5C3"))
     (received (01FF 5555 FFFF A5C3)) (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false))))
    |}]
;;
