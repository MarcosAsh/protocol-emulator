open! Core
open Protocol_emulator

let config = Program_config.default

let%expect_test "firmware the kernel accepts" =
  let timed = Timed_program.of_source_exn ~config (In_channel.read_all "uart_tx.asm") in
  print_s [%message "" ~verdict:(Timed_program.verdict timed : Analyser.Verdict.t)];
  [%expect {| (verdict ((words 15) (deadline_waits 3) (worst_slack (12)))) |}]
;;

(* The pcs a refusal names, at their source lines. *)
let refusal source =
  let program, lines =
    Asm.assemble_with_lines source |> Result.map_error ~f:snd |> ok_exn
  in
  match Timed_program.check ~config program with
  | Ok _ -> print_s [%message "accepted"]
  | Error { pcs; verdict; error = _ } ->
    print_s
      [%message
        ""
          (pcs : int list)
          ~lines:(List.map pcs ~f:(List.nth_exn lines) : int list)
          (verdict : Analyser.Verdict.t option)]
;;

let%expect_test "a refusal names its pcs, and the verdict if the analyser passed" =
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
    ((pcs (3)) (lines (6)) (verdict ()))
    ((pcs (11)) (lines (17))
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
