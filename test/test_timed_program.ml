open! Core
open Protocol_emulator

let config = Program_config.default

let%expect_test "firmware the kernel accepts" =
  let timed = Timed_program.of_source_exn ~config (In_channel.read_all "uart_tx.asm") in
  print_s [%message "" ~verdict:(Timed_program.verdict timed : Analyser.Verdict.t)];
  [%expect {| (verdict ((words 15) (deadline_waits 3) (worst_slack (12)))) |}]
;;

let refusal source =
  match Timed_program.check ~config source with
  | Ok _ -> print_s [%message "accepted"]
  | Error { faults; verdict; error = _ } ->
    print_s
      [%message
        "" (faults : Timed_program.Fault.t list) (verdict : Analyser.Verdict.t option)]
;;

let%expect_test "a refusal names its lines, and the verdict if the analyser passed" =
  (* the analyser refuses a loop that falls further behind on every pass *)
  refusal
    {|
    set p, 4
    mov t, now
loop:
    add t, p
    wait t
    out pins, 1 [5]
    jmp loop
|};
  (* the analyser passes this one and the kernel refuses it *)
  refusal (In_channel.read_all "assemble/gap_adding_x.asm");
  [%expect
    {|
    ((faults
      (((line 6) (pc (3))
        (reason
         "this deadline wait can be reached late, by more on each pass of a loop or after an untimed wait"))))
     (verdict ()))
    ((faults
      (((line 17) (pc (11))
        (reason
         "the analyser passed this row, and the kernel refuses it: in time, next phase"))))
     (verdict (((words 32) (deadline_waits 4) (worst_slack (0))))))
    |}]
;;

let%expect_test "lines count from 1, and an error comes at its first fault's" =
  let lines source =
    print_s
      [%sexp
        (Asm.assemble_with_lines source |> Result.map ~f:snd
         : (int list, int * Error.t) Result.t)]
  in
  lines
    ".side_set 1\nstart:\n    set p, 4 side 0 ; comment\n\n    jmp start\nend: nop side 1";
  lines "    set p, 4\n    frob pins, 1\n    nop\n    jmp nowhere";
  [%expect
    {|
    (Ok (3 5 6))
    (Error
     (2
      (((line 2 "    frob pins, 1") ("cannot parse" frob (args (pins 1))))
       ((line 4 "    jmp nowhere") ("unknown label" nowhere)))))
    |}]
;;

let%expect_test "a deadline past half the timer is refused" =
  (* 160 adds of 65535 put [t] past 2^23 ahead, which the wait's signed compare reads as
     passed, so the model misses it *)
  let source =
    {|
    mov p, !null
    mov t, now
    set x, 31
loop:
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    jmp x--, loop
    wait t
    halt
|}
  in
  let ahead = Asm.assemble source |> ok_exn in
  let configured = Asm.Program.configure ahead config in
  let machine =
    Fn.apply_n_times
      ~n:1000
      (Machine.step ~inputs:0)
      (Machine.create ~config:configured ~program:(Asm.Program.words ahead |> ok_exn)
       |> ok_exn)
  in
  print_s [%message "" ~missed_deadline:(machine.fault.missed_deadline : bool)];
  (match Timed_program.check ~period:65535 ~config source with
   | Ok _ -> print_s [%message "accepted"]
   | Error { faults; verdict = _; error = _ } ->
     print_s [%message "" (faults : Timed_program.Fault.t list)]);
  (* the kernel, on the analyser's rows alone, refuses it too *)
  let rows = Analyser.analyse ~period:65535 ~config:configured ahead.instructions in
  print_s
    [%message
      ""
        ~kernel_accepts:
          (Kernel.check
             ~period:65535
             ~config:configured
             ~words:(Asm.Program.words ahead |> ok_exn)
             (Kernel.Table.of_analyser rows)
           |> Result.is_ok
           : bool)];
  [%expect {|
    (missed_deadline true)
    (faults
     (((line 12) (pc (9))
       (reason
        "this deadline wait can be reached more than half the timer early, which the wait reads as passed (slack 10485374)"))))
    (kernel_accepts false)
    |}]
;;
