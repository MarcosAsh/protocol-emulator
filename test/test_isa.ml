open! Core
open! Hardcaml
open Protocol_emulator

let samples : Isa.t list =
  [ Jmp { cond = Always; target = 0 }
  ; Jmp { cond = X_dec; target = 0x1ff }
  ; Jmp { cond = Stuff_pending; target = 42 }
  ; Op { op = Wait (Pin_level { pin = 3; level = false }); delay = 0; side_set = 0 }
  ; Op { op = Wait (Pin_edge { pin = 19; rising = true }); delay = 1; side_set = 0 }
  ; Op { op = Wait (Deadline { advance = true }); delay = 0; side_set = 1 }
  ; Op { op = Wait (Fifo Tx_not_empty); delay = 0; side_set = 0 }
  ; Op { op = In { source = Pins; count = 1 }; delay = 7; side_set = 1 }
  ; Op { op = In { source = Crc; count = 16 }; delay = 0; side_set = 0 }
  ; Op { op = Out { dest = Pins; count = 1 }; delay = 3; side_set = 0 }
  ; Op { op = Out { dest = P; count = 16 }; delay = 0; side_set = 0 }
  ; Op { op = Mov { dest = T; op = Copy; source = Now }; delay = 0; side_set = 0 }
  ; Op { op = Mov { dest = Pins; op = Invert; source = X }; delay = 0; side_set = 1 }
  ; Op { op = Set { dest = X; value = 7 }; delay = 0; side_set = 0 }
  ; Op { op = Set { dest = Pindirs; value = 31 }; delay = 15; side_set = 0 }
  ; Op { op = Alu { dest = T; op = Add; operand = Reg P }; delay = 0; side_set = 0 }
  ; Op { op = Alu { dest = X; op = Sub; operand = Imm 1 }; delay = 0; side_set = 0 }
  ; Op { op = Sys Pull; delay = 0; side_set = 0 }
  ; Op { op = Sys Halt; delay = 0; side_set = 0 }
  ]
;;

let%expect_test "encoding of representative instructions" =
  let side_set_count = 1 in
  List.iter samples ~f:(fun t ->
    let word = Isa.to_word ~side_set_count t |> ok_exn in
    printf "%04x  %s\n" word (Sexp.to_string_hum ~indent:1 [%sexp (t : Isa.t)]));
  [%expect
    {|
    0000  (Jmp (cond Always) (target 0))
    03ff  (Jmp (cond X_dec) (target 511))
    0e2a  (Jmp (cond Stuff_pending) (target 42))
    2003  (Op (op (Wait (Pin_level (pin 3) (level false)))) (delay 0) (side_set 0))
    21b3  (Op (op (Wait (Pin_edge (pin 19) (rising true)))) (delay 1) (side_set 0))
    30c0  (Op (op (Wait (Deadline (advance true)))) (delay 0) (side_set 1))
    20e0  (Op (op (Wait (Fifo Tx_not_empty))) (delay 0) (side_set 0))
    5701  (Op (op (In (source Pins) (count 1))) (delay 7) (side_set 1))
    40d0  (Op (op (In (source Crc) (count 16))) (delay 0) (side_set 0))
    6301  (Op (op (Out (dest Pins) (count 1))) (delay 3) (side_set 0))
    60d0  (Op (op (Out (dest P) (count 16))) (delay 0) (side_set 0))
    80e6  (Op (op (Mov (dest T) (op Copy) (source Now))) (delay 0) (side_set 0))
    9009  (Op (op (Mov (dest Pins) (op Invert) (source X))) (delay 0) (side_set 1))
    a027  (Op (op (Set (dest X) (value 7))) (delay 0) (side_set 0))
    af7f  (Op (op (Set (dest Pindirs) (value 31))) (delay 15) (side_set 0))
    c0ca  (Op (op (Alu (dest T) (op Add) (operand (Reg P)))) (delay 0) (side_set 0))
    c011  (Op (op (Alu (dest X) (op Sub) (operand (Imm 1)))) (delay 0) (side_set 0))
    e004  (Op (op (Sys Pull)) (delay 0) (side_set 0))
    e001  (Op (op (Sys Halt)) (delay 0) (side_set 0))
    |}]
;;

let%expect_test "rejected instructions" =
  let side_set_count = 1 in
  let try_ t = print_s [%sexp (Isa.to_word ~side_set_count t : int Or_error.t)] in
  try_ (Jmp { cond = Always; target = 512 });
  try_ (Op { op = Wait (Pin_level { pin = 28; level = true }); delay = 0; side_set = 0 });
  try_ (Op { op = In { source = Pins; count = 0 }; delay = 0; side_set = 0 });
  try_ (Op { op = Sys Nop; delay = 16; side_set = 0 });
  try_ (Op { op = Sys Nop; delay = 0; side_set = 2 });
  try_ (Op { op = Alu { dest = X; op = Add; operand = Imm 8 }; delay = 0; side_set = 0 });
  [%expect
    {|
    (Error (target "out of range" (value 512) (lo 0) (hi 511)))
    (Error (pin "out of range" (value 28) (lo 0) (hi 27)))
    (Error (count "out of range" (value 0) (lo 1) (hi 16)))
    (Error (delay "out of range" (value 16) (lo 0) (hi 15)))
    (Error (side_set "out of range" (value 2) (lo 0) (hi 1)))
    (Error (imm "out of range" (value 8) (lo 0) (hi 7)))
    |}]
;;

let%expect_test "rejected words" =
  let side_set_count = 0 in
  let try_ word = print_s [%sexp (Isa.of_word ~side_set_count word : Isa.t Or_error.t)] in
  try_ 0x1800;
  try_ 0x2041;
  try_ 0x4000;
  try_ 0x4011;
  try_ 0x8018;
  try_ 0xa0a0;
  try_ 0xc035;
  try_ 0xe010;
  try_ 0x10000;
  [%expect
    {|
    (Error ("no such enum code" (i 12)))
    (Error (index "out of range" (value 1) (lo 0) (hi 0)))
    (Error (count "out of range" (value 0) (lo 1) (hi 16)))
    (Error (count "out of range" (value 17) (lo 1) (hi 16)))
    (Error ("no such enum code" (i 3)))
    (Error ("no such enum code" (i 5)))
    (Error ("no such enum code" (i 3)))
    (Error ("reserved bits set" (word 16) (mask -16)))
    (Error (word "out of range" (value 65536) (lo 0) (hi 65535)))
    |}]
;;

module Generator = struct
  open Quickcheck.Generator
  open Let_syntax

  let enum all = of_list all
  let pin = Int.gen_incl 0 (Isa.pin_space - 1)
  let count = Int.gen_incl 1 Isa.max_shift_count

  let wait =
    union
      [ (let%map pin
         and level = bool in
         Isa.Wait.Pin_level { pin; level })
      ; (let%map pin
         and rising = bool in
         Isa.Wait.Pin_edge { pin; rising })
      ; (let%map advance = bool in
         Isa.Wait.Deadline { advance })
      ; (let%map fifo = enum [ Isa.Fifo_wait.Tx_not_empty; Rx_not_full ] in
         Isa.Wait.Fifo fifo)
      ]
  ;;

  let alu_operand =
    union
      [ (let%map imm = Int.gen_incl 0 (Isa.Field.mask Isa.Field.alu_operand) in
         Isa.Alu_operand.Imm imm)
      ; (let%map reg = enum Isa.Alu_reg.Cases.all in
         Isa.Alu_operand.Reg reg)
      ]
  ;;

  let op =
    union
      [ (let%map wait in
         Isa.Op.Wait wait)
      ; (let%map source = enum Isa.In_source.Cases.all
         and count in
         Isa.Op.In { source; count })
      ; (let%map dest = enum Isa.Out_dest.Cases.all
         and count in
         Isa.Op.Out { dest; count })
      ; (let%map dest = enum Isa.Mov_dest.Cases.all
         and op = enum Isa.Mov_op.Cases.all
         and source = enum Isa.Mov_source.Cases.all in
         Isa.Op.Mov { dest; op; source })
      ; (let%map dest = enum Isa.Set_dest.Cases.all
         and value = Int.gen_incl 0 (Isa.Field.mask Isa.Field.set_value) in
         Isa.Op.Set { dest; value })
      ; (let%map dest = enum Isa.Alu_dest.Cases.all
         and op = enum Isa.Alu_op.Cases.all
         and operand = alu_operand in
         Isa.Op.Alu { dest; op; operand })
      ; (let%map sys = enum Isa.Sys_op.Cases.all in
         Isa.Op.Sys sys)
      ]
  ;;

  let instruction ~side_set_count =
    union
      [ (let%map cond = enum Isa.Jmp_cond.Cases.all
         and target = Int.gen_incl 0 (Isa.Field.mask Isa.Field.jmp_target) in
         Isa.Jmp { cond; target })
      ; (let%map op
         and delay = Int.gen_incl 0 ((1 lsl (Isa.delay_bits - side_set_count)) - 1)
         and side_set = Int.gen_incl 0 ((1 lsl side_set_count) - 1) in
         Isa.Op { op; delay; side_set })
      ]
  ;;
end

let side_set_counts = List.init (Isa.max_side_set + 1) ~f:Fn.id

let%expect_test "every instruction survives a round trip through its word" =
  List.iter side_set_counts ~f:(fun side_set_count ->
    Quickcheck.test
      ~trials:2000
      ~sexp_of:[%sexp_of: Isa.t]
      (Generator.instruction ~side_set_count)
      ~f:(fun t ->
        let word = Isa.to_word ~side_set_count t |> ok_exn in
        [%test_result: Isa.t]
          ~message:"decode of encode"
          ~expect:t
          (Isa.of_word ~side_set_count word |> ok_exn)));
  [%expect {| |}]
;;

let%expect_test "every word that decodes encodes back to itself" =
  List.iter side_set_counts ~f:(fun side_set_count ->
    let valid =
      List.init (1 lsl Isa.word_bits) ~f:Fn.id
      |> List.count ~f:(fun word ->
        match Isa.of_word ~side_set_count word with
        | Error _ -> false
        | Ok t ->
          [%test_result: int]
            ~message:"encode of decode"
            ~expect:word
            (Isa.to_word ~side_set_count t |> ok_exn);
          true)
    in
    print_s [%message (side_set_count : int) (valid : int)]);
  [%expect
    {|
    ((side_set_count 0) (valid 34592))
    ((side_set_count 1) (valid 34592))
    ((side_set_count 2) (valid 34592))
    |}]
;;
