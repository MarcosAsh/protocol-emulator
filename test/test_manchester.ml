open! Core
open Protocol_emulator
open Firmware

(* One byte, least significant bit first, through the Manchester assist on IO0 and IO1:
   the [out] and its delay are the first half of each bit, the jump the second, so every
   bit is four cycles and every half two, with an edge in the middle of every bit. *)
let%expect_test "a byte in Manchester, four cycles a bit" =
  let config =
    { Program_config.default with out_base = Isa.first_bidir_pin; manchester = true }
  in
  let halves = ref [] in
  let react (m : Machine.t) =
    let pair = (m.pin_out lsr Isa.first_bidir_pin) land 3 in
    halves := pair :: !halves
  in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:40
      ~preload:[ 0xa5 ]
      ~config
      ~program:
        (assemble
           {|
    set y, 7
    pull
bit:
    out pins, 1 [1]
    jmp y--, bit
    halt
|})
      ~inputs:(fun _ -> 0)
      ~react
      ()
  in
  (* each cycle IO1 then IO0: a 1 is 10 then 01, a 0 is 01 then 10 *)
  List.rev !halves
  |> List.map ~f:(fun pair -> sprintf "%d%d" (pair lsr 1) (pair land 1))
  |> String.concat ~sep:" "
  |> print_endline;
  [%expect
    {|
    ("lockstep held" (cycles 40))
    00 00 10 10 01 01 01 01 10 10 10 10 01 01 01 01 10 10 01 01 10 10 10 10 01 01 01 01 10 10 10 10 01 01 01 01 01 01 01 01
    |}]
;;

(* The certificate for the same loop names both halves of every bit: the [out] puts the
   first on the pins and the jump the second. No deadline wait fits in four cycles, so the
   phase is only bounded from the start, but each edge is exactly two cycles after the one
   before. The model under random pins and host traffic keeps inside what it says. *)
let%expect_test "the certificate names both halves of every bit" =
  let config =
    { Program_config.default with out_base = Isa.first_bidir_pin; manchester = true }
  in
  let source =
    {|
    set p, 16
    wait tx
    pull
    mov t, now
    add t, p
    set y, 7
    wait t
bit:
    out pins, 1 [1]
    jmp y--, bit
    halt
|}
  in
  Timing_report.print ~config source;
  let { Soundness.issues; flips; violations; _ } =
    Soundness.check
      ~config
      (List.init 4 ~f:(fun n -> Soundness.Stimulus.random ~seed:(n + 1) ~cycles:200))
      (assemble source)
  in
  print_s
    [%message (issues : int) (flips : int) (violations : (int * int * int * int) list)];
  [%expect
    {|
      7  out pins, 1 [1]              phase 1..?  edge 2..?  jitter ?  gap 2 from 8, ?..? from 6
      8  jmp y--, 7                   phase 3..?  flip 4..?  jitter ?  gap 2
    ((words 10) (edge_jitter unbounded) (sample_jitter 0) (side_jitter 0)
     (may_miss 0))
    ((issues 96) (flips 32) (violations ()))
    |}]
;;
