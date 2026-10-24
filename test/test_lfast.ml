open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Lfast.firmware));
  [%expect {| 64 words, 27 deadline waits, worst slack 6 |}]
;;

(* The line, level by level with the cycles each lasted, for one host word: what to hold
   against the spec's timing diagram. TODO a model of the far end, fed the pins every
   cycle, that reads back what the host sent. *)
let%expect_test "the line for one host word" =
  let machine =
    Machine.create
      ~config:(Timed_program.config Lfast.firmware)
      ~program:(Timed_program.words Lfast.firmware)
    |> ok_exn
  in
  let machine = Machine.write_tx machine 0x55 |> ok_exn in
  let levels =
    List.folding_map (List.range 0 400) ~init:machine ~f:(fun machine _ ->
      let machine = Machine.step machine ~inputs:0 in
      machine, (machine.pin_out lsr Lfast.pin) land 1 = 1)
  in
  let runs =
    List.group levels ~break:Bool.( <> )
    |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
  in
  print_s [%message (runs : (bool * int) list)];
  [%expect {|
    (runs
     ((false 16) (true 10) (false 10) (true 10) (false 10) (true 10) (false 40)
      (true 10) (false 20) (true 10) (false 10) (true 20) (false 40) (true 10)
      (false 20) (true 10) (false 10) (true 10) (false 10) (true 10) (false 10)
      (true 10) (false 10) (true 20) (false 54)))
    |}]
;;

(* The far end: a receiver that finds each frame's first rising edge on the idle-low line
   and samples every bit in the middle of its period, as the spec's receiver does from the
   sync pattern. *)
module Far_end = struct
  type frame =
    { sync : int
    ; header : int
    ; payload : int
    ; stop : int
    }
  [@@deriving sexp_of]

  let frame_bits = 16 + 8 + 8 + 1

  let decode ~period (levels : bool array) =
    let sample start k = Bool.to_int levels.(start + (period * k) + (period / 2)) in
    let field start ~first ~count =
      List.fold
        (List.range first (first + count))
        ~init:0
        ~f:(fun acc k -> (acc lsl 1) lor sample start k)
    in
    let rec go i frames =
      if i + (period * frame_bits) > Array.length levels
      then List.rev frames
      else if (not levels.(i)) && levels.(i + 1)
      then (
        let start = i + 1 in
        let frame =
          { sync = field start ~first:0 ~count:16
          ; header = field start ~first:16 ~count:8
          ; payload = field start ~first:24 ~count:8
          ; stop = field start ~first:32 ~count:1
          }
        in
        go (start + (period * frame_bits)) (frame :: frames))
      else go (i + 1) frames
    in
    go 0 []
  ;;
end

let line_after ~words ~cycles =
  let machine =
    Machine.create
      ~config:(Timed_program.config Lfast.firmware)
      ~program:(Timed_program.words Lfast.firmware)
    |> ok_exn
  in
  let machine =
    List.fold words ~init:machine ~f:(fun machine word ->
      Machine.write_tx machine word |> ok_exn)
  in
  List.folding_map (List.range 0 cycles) ~init:machine ~f:(fun machine _ ->
    let machine = Machine.step machine ~inputs:0 in
    machine, (machine.pin_out lsr Lfast.pin) land 1 = 1)
  |> Array.of_list
;;

let%expect_test "the far end reads each host byte back in a frame" =
  let frames = Far_end.decode ~period:10 (line_after ~words:[ 0x55; 0xa3 ] ~cycles:900) in
  List.iter frames ~f:(fun (frame : Far_end.frame) ->
    [%test_result: int] frame.sync ~message:"sync pattern" ~expect:0xa84b;
    [%test_result: int] frame.stop ~message:"stop bit" ~expect:1);
  print_s
    [%message
      (frames : Far_end.frame list)
        ~payloads:(List.map frames ~f:(fun frame -> frame.payload) : int list)];
  [%expect {|
    ((frames
      (((sync 43083) (header 9) (payload 85) (stop 1))
       ((sync 43083) (header 9) (payload 163) (stop 1))))
     (payloads (85 163)))
    |}]
;;
