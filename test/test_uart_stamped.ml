open! Core
open Protocol_emulator
open Firmware

let period = 8
let tx_pin = 5

let%expect_test "the analyser's certificate" =
  let { Certified.source; config; _ } = Certified.stamped in
  let program = Asm.assemble source |> ok_exn in
  let config = Asm.Program.configure program config in
  print_endline
    (Analyser.to_string
       ~side_set_count:config.side_set_count
       (Analyser.analyse ~config program.instructions));
  print_endline (Analyser.check ~config program |> ok_exn |> Analyser.Verdict.to_string);
  [%expect {|
      0  set p, 8                     phase ?..?
      1  set pins, 1                  phase ?..?  edge ?..?  jitter ?  gap ?..?
      2  wait tx                      phase ?..?
      3  pull                         phase ?..?
      4  set x, 7                     phase ?..?
      5  mov y, now                   phase ?..?
      6  add y, 4                     phase ?..?
      7  mov t, now                   phase ?..?
      8  set pins, 0                  phase 1  edge 2  gap 7..?
      9  add t, p                     phase 2
     10  wait t+                      phase -5..-4  slack 4..5
     11  out pins, 1                  phase -7  edge -6  gap 7..9
     12  jmp x--, 10                  phase -6
     13  mov osr, y                   phase -4
     14  set x, 15                    phase -3
     15  wait t+                      phase -4..-2  slack 2..4
     16  out pins, 1                  phase -7  edge -6  gap 6..10
     17  jmp x--, 15                  phase -6
     18  wait t+                      phase -4  slack 4
     19  set pins, 1                  phase -7  edge -6  gap 8
     20  wait t                       phase -6  slack 6
     21  jmp 2                        phase 1
    22 words, 4 deadline waits, worst slack 2
    |}]
;;

(* The host writes each byte at its cycle. Returns [now] and the pin after every step. *)
let run ~cycles ~writes =
  let t =
    Machine.create
      ~config:Program_config.default
      ~program:(assemble (uart_tx_stamped ~period))
    |> ok_exn
  in
  let rec loop t cycle acc =
    if cycle = cycles
    then t, Array.of_list (List.rev acc)
    else (
      let t =
        List.filter writes ~f:(fun (at, _) -> at = cycle)
        |> List.fold ~init:t ~f:(fun t (_, byte) -> Machine.write_tx t byte |> ok_exn)
      in
      let t = Machine.step t ~inputs:0 in
      loop t (cycle + 1) ((t.now, (t.pin_out lsr tx_pin) land 1) :: acc))
  in
  loop t 0 []
;;

(* A falling edge from the idle line starts a frame. Its cycle is [now] in the first step
   that shows it, and the bits are read in the middle of each period. *)
let frames samples =
  let level i = snd samples.(i) in
  let field i ~first ~width =
    List.init width ~f:(fun b -> level (i + ((first + b) * period) + (period / 2)) lsl b)
    |> List.fold ~init:0 ~f:( lor )
  in
  let rec scan i acc =
    if i + (26 * period) > Array.length samples
    then List.rev acc
    else if i > 0 && level i = 0 && level (i - 1) = 1
    then (
      let edge = fst samples.(i) in
      let byte = field i ~first:1 ~width:8 in
      let stamp = field i ~first:9 ~width:16 in
      scan (i + (25 * period) + (period / 2)) ((byte, stamp, edge) :: acc))
    else scan (i + 1) acc
  in
  scan 0 []
;;

let%expect_test "every frame carries the cycle its start bit showed" =
  let t, samples =
    run ~cycles:71_000 ~writes:[ 0, 0x41; 1000, 0xa5; 1000, 0x5a; 70_000, 0x3c ]
  in
  printf "%4s  %6s  %6s  %s\n" "byte" "stamp" "edge" "edge mod 2^16";
  List.iter (frames samples) ~f:(fun (byte, stamp, edge) ->
    [%test_result: int] stamp ~expect:(edge land 0xffff);
    printf "0x%02x  0x%04x  %6d  0x%04x\n" byte stamp edge (edge land 0xffff));
  print_s [%message (t.fault : Machine.Fault.t)];
  [%expect {|
    byte   stamp    edge  edge mod 2^16
    0x41  0x0009       9  0x0009
    0xa5  0x03ef    1007  0x03ef
    0x5a  0x04c7    1223  0x04c7
    0x3c  0x1177   70007  0x1177
    (t.fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    |}]
;;
