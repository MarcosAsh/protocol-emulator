open! Core
open Protocol_emulator

let listing source =
  let program = Asm.assemble source |> ok_exn in
  let words = Asm.Program.words program |> ok_exn in
  List.iteri (List.zip_exn words program.instructions) ~f:(fun address (word, t) ->
    printf
      "%3d  %04x  %s\n"
      address
      word
      (Asm.to_string ~side_set_count:program.side_set_count t))
;;

let%expect_test "listing of a spi master" =
  listing
    {|
    .side_set 1                ; side-set drives SCK
    set p, 8 side 0
idle:
    wait tx side 0
    pull side 0
    set x, 7 side 0
    mov t, now side 0
    add t, p side 0
    wait t+ side 0
    out pins, 1 side 0         ; first bit
bit:
    wait t+ side 0
    in pins, 1 side 1          ; rising edge, data sampled
    wait t+ side 1
    out pins, 1 side 0         ; falling edge, data changes
    jmp x--, bit
    push side 0
    jmp idle
|};
  [%expect
    {|
     0  a088  set p, 8 side 0
     1  20e0  wait tx side 0
     2  e004  pull side 0
     3  a027  set x, 7 side 0
     4  80e6  mov t, now side 0
     5  c0ca  add t, p side 0
     6  20c0  wait t+ side 0
     7  6001  out pins, 1 side 0
     8  20c0  wait t+ side 0
     9  5001  in pins, 1 side 1
    10  30c0  wait t+ side 1
    11  6001  out pins, 1 side 0
    12  0208  jmp x--, 8
    13  e003  push side 0
    14  0001  jmp 1
    |}]
;;

let%expect_test "every operand form" =
  listing
    {|
    jmp 0
    jmp x--, 0x1ff
    jmp y--, 3
    jmp x!=y, 0b101
    jmp pin, 5
    jmp !pin, 5
    jmp !osre, 5
    jmp stuff, 5
    wait 0 pin 3
    wait 1 pin 19 [1]
    wait rise pin 0
    wait fall pin 12
    wait t
    wait t+
    wait tx
    wait rx
    in pins, 1
    in crc, 16
    in capture, 8 [31]
    out pins, 1
    out pindirs, 4
    out t, 16
    mov pins, x
    mov x, !y
    mov isr, ::osr
    mov t, capture
    set pins, 0
    set x, 31
    add t, p
    sub x, 1
    xor y, isr
    nop
    halt
    irq
    push
    pull
    crc_init
    stuff_reset
    capture_arm
|};
  [%expect
    {|
     0  0000  jmp 0
     1  03ff  jmp x--, 511
     2  0403  jmp y--, 3
     3  0605  jmp x!=y, 5
     4  0805  jmp pin, 5
     5  0a05  jmp !pin, 5
     6  0c05  jmp !osre, 5
     7  0e05  jmp stuff, 5
     8  2003  wait 0 pin 3
     9  2193  wait 1 pin 19 [1]
    10  20a0  wait rise pin 0
    11  202c  wait fall pin 12
    12  2040  wait t
    13  20c0  wait t+
    14  20e0  wait tx
    15  2060  wait rx
    16  4001  in pins, 1
    17  40d0  in crc, 16
    18  5fe8  in capture, 8 [31]
    19  6001  out pins, 1
    20  6084  out pindirs, 4
    21  60f0  out t, 16
    22  8001  mov pins, x
    23  802a  mov x, !y
    24  8095  mov isr, ::osr
    25  80e7  mov t, capture
    26  a000  set pins, 0
    27  a03f  set x, 31
    28  c0ca  add t, p
    29  c011  sub x, 1
    30  c06b  xor y, isr
    31  e000  nop
    32  e001  halt
    33  e002  irq
    34  e003  push
    35  e004  pull
    36  e005  crc_init
    37  e006  stuff_reset
    38  e007  capture_arm
    |}]
;;

let%expect_test "errors name the line" =
  let try_ source = print_s [%sexp (Asm.assemble source : Asm.Program.t Or_error.t)] in
  try_ "jmp nowhere";
  try_ "  set pins, 1\n  jmp x--, bit [2]";
  try_ "mov x, z";
  try_ "wait up pin 1";
  try_ "set x, 32";
  try_ "loop:\nloop:";
  try_ ".origin 4";
  try_ "out pins, 1 side 1";
  try_ ".side_set 1\nout pins, 1";
  [%expect
    {|
    (Error ((line 1 "jmp nowhere") ("unknown label" nowhere)))
    (Error ((line 2 "  jmp x--, bit [2]") "jmp takes no side-set or delay"))
    (Error
     ((line 1 "mov x, z")
      ("unknown operand" z (expected (pins x y null isr osr now capture)))))
    (Error ((line 1 "wait up pin 1") ("expected 0 or 1" up)))
    (Error
     ((line 1 "set x, 32") (value "out of range" (value 32) (lo 0) (hi 31))))
    (Error ((line 2 loop:) ("duplicate label" loop)))
    (Error ((line 1 ".origin 4") ("unknown directive" origin (args (4)))))
    (Error
     ((line 1 "out pins, 1 side 1")
      (side_set "out of range" (value 1) (lo 0) (hi 0))))
    (Error
     ((line 2 "out pins, 1")
      "side-set is enabled, so every instruction needs a side"))
    |}]
;;

let%expect_test "an instruction survives printing and parsing" =
  List.iter [ 0; 1; 2 ] ~f:(fun side_set_count ->
    Quickcheck.test
      ~trials:1000
      ~sexp_of:[%sexp_of: Isa.t]
      (Test_isa.Generator.instruction ~side_set_count)
      ~f:(fun t ->
        let source =
          [%string ".side_set %{side_set_count#Int}\n%{Asm.to_string ~side_set_count t}"]
        in
        match Asm.assemble source with
        | Error e -> raise_s [%message "did not assemble" source (e : Error.t)]
        | Ok program ->
          [%test_result: Isa.t list] ~message:source ~expect:[ t ] program.instructions));
  [%expect {| |}]
;;

let%expect_test "wrap directives mark the loop" =
  let wrap source =
    let program = Asm.assemble source |> ok_exn in
    print_s [%message (program.wrap_bottom : int) (program.wrap_top : int)]
  in
  wrap {|
    set p, 2
.wrap_target
    wait t+
    mov pins, !pins
.wrap
    halt
|};
  wrap {|
    set p, 2
.wrap_target
    wait t+
|};
  wrap "    nop";
  print_s [%sexp (Asm.assemble ".wrap\n    nop" : Asm.Program.t Or_error.t)];
  [%expect
    {|
    ((program.wrap_bottom 1) (program.wrap_top 2))
    ((program.wrap_bottom 1) (program.wrap_top 1))
    ((program.wrap_bottom 0) (program.wrap_top 511))
    (Error ((line 1 .wrap) ".wrap before any instruction"))
    |}]
;;

let%expect_test "the words committed for the cocotb test are current" =
  let committed name =
    In_channel.read_lines (name ^ ".hex")
    |> List.map ~f:(fun w -> Int.of_string ("0x" ^ w))
  in
  let assembled name = In_channel.read_all (name ^ ".asm") |> Firmware.assemble in
  List.iter [ "uart_tx"; "wrapped_loop" ] ~f:(fun name ->
    [%test_result: int list] ~message:name (committed name) ~expect:(assembled name));
  (* uart_tx.asm is a copy, because the command line assembles files *)
  [%test_result: int list]
    (assembled "uart_tx")
    ~expect:(Firmware.assemble (Firmware.uart_tx ~period:16));
  [%expect {| |}]
;;
