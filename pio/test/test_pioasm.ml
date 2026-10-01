open! Core
open Pio

let demo =
  {|
.define public T 3
.program demo
.side_set 1 opt   ; one pin, optional, so three delay bits

.wrap_target
top:
    out x, 1       side 0 [T - 1]  ; comment
    jmp !x top     side 1
public mid: nop [7]
    jmp x--, top
.wrap
    wait 1 pin, 2
    irq wait 0 rel
    mov pins, !null
    in pins, 1 [1] side 0

% c-sdk {
static inline void ignored(void) { }
%}
|}
;;

let%expect_test "labels, defines, side-set, delay and wrap" =
  let program = Pioasm.parse demo |> ok_exn |> List.hd_exn in
  print_s
    [%message
      program.name
        (program.side_set : Pioasm.Side_set.t)
        (program.wrap_target : int)
        (program.wrap : int)
        (program.labels : (string * int) list)];
  Array.iter program.instructions ~f:(fun { op; delay; side; text } ->
    print_s [%message text (op : Pioasm.Op.t) (delay : int) (side : int option)]);
  [%expect
    {|
    (demo (program.side_set ((count 1) (optional true) (pindirs false)))
     (program.wrap_target 0) (program.wrap 3) (program.labels ((top 0) (mid 2))))
    ("out x, 1 side 0 [T - 1]" (op (Out (destination X) (bits 1))) (delay 2)
     (side (0)))
    ("jmp !x top side 1" (op (Jmp (condition X_zero) (target 0))) (delay 0)
     (side (1)))
    ("nop [7]" (op (Mov (destination Y) (op Copy) (source Y))) (delay 7)
     (side ()))
    ("jmp x--, top" (op (Jmp (condition X_post_decrement) (target 0))) (delay 0)
     (side ()))
    ("wait 1 pin, 2" (op (Wait (polarity true) (source (Pin 2)))) (delay 0)
     (side ()))
    ("irq wait 0 rel" (op (Irq (mode Raise_and_wait) (index 0))) (delay 0)
     (side ()))
    ("mov pins, !null" (op (Mov (destination Pins) (op Invert) (source Null)))
     (delay 0) (side ()))
    ("in pins, 1 [1] side 0" (op (In (source Pins) (bits 1))) (delay 1)
     (side (0)))
    |}]
;;

let%expect_test "what pioasm refuses is refused, with the line" =
  List.iter
    [ ".program a\n.side_set 1 opt\nnop [8]"
    ; ".program a\n.side_set 1\nnop"
    ; ".program a\nset x, 32"
    ; ".program a\njmp nowhere"
    ; ".program a\nfrobnicate x"
    ; "nop"
    ; ".program a\nnop\n.wrap_target"
    ; ".program a\n.wrap\nnop"
    ]
    ~f:(fun text ->
      print_s [%sexp (Pioasm.parse text : Pioasm.Program.t list Or_error.t)]);
  [%expect
    {|
    (Error ("line 3" ("delay out of range" (delay 8) (max_delay 7))))
    (Error ("line 3" ("side-set is not optional" (text nop))))
    (Error ("line 2" ("set value out of range" (value 32))))
    (Error ("line 2" ("unknown name" (token nowhere))))
    (Error ("line 2" ("unknown instruction" (mnemonic frobnicate))))
    (Error ("line 1" "instruction before .program"))
    (Error ("line 3" ".wrap_target after the last instruction"))
    (Error ("line 2" ".wrap before the first instruction"))
    |}]
;;

let%expect_test "every vendored pico-examples program parses" =
  List.iter
    [ "uart_rx.pio"
    ; "uart_tx.pio"
    ; "ws2812.pio"
    ; "i2c.pio"
    ; "onewire_library.pio"
    ; "manchester_encoding.pio"
    ]
    ~f:(fun file ->
      In_channel.read_all ("pico_examples/" ^ file)
      |> Pioasm.parse
      |> ok_exn
      |> List.iter ~f:(fun (program : Pioasm.Program.t) ->
        printf
          "%-20s %2d words, wrap %d..%d\n"
          program.name
          (Array.length program.instructions)
          program.wrap_target
          program.wrap));
  [%expect
    {|
    uart_rx_mini          4 words, wrap 0..3
    uart_rx               9 words, wrap 0..8
    uart_tx               4 words, wrap 0..3
    ws2812                4 words, wrap 0..3
    ws2812_parallel       4 words, wrap 0..3
    i2c                  18 words, wrap 12..17
    set_scl_sda           4 words, wrap 0..3
    onewire              17 words, wrap 8..16
    manchester_tx         6 words, wrap 0..5
    manchester_rx         6 words, wrap 3..5
    |}]
;;
