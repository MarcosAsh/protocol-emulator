open! Core
open Protocol_emulator
open Ppxlib

(* Runs [%firmware] on [source] as the build does, and prints each error the compiler
   would report, under the line it points at. *)
let build source =
  let lexbuf = Lexing.from_string source in
  Lexing.set_filename lexbuf "demo.ml";
  let lines = String.split source ~on:'\n' |> Array.of_list in
  let errors = ref [] in
  (object
     inherit Ast_traverse.iter as super

     method! extension ((name, payload) as extension) =
       (match name.txt, payload with
        | ( "ocaml.error"
          , PStr
              ({ pstr_desc =
                   Pstr_eval
                     ({ pexp_desc = Pexp_constant (Pconst_string (message, _, _)); _ }, _)
               ; _
               }
              :: _) ) -> errors := (name.loc, message) :: !errors
        | _ -> ());
       super#extension extension
  end)
    #structure
    (Driver.map_structure (Parse.implementation lexbuf));
  match List.rev !errors with
  | [] -> print_endline "builds"
  | errors ->
    List.iter errors ~f:(fun ((loc : Location.t), message) ->
      let line = loc.loc_start.pos_lnum in
      let first = loc.loc_start.pos_cnum - loc.loc_start.pos_bol in
      let last = loc.loc_end.pos_cnum - loc.loc_start.pos_bol in
      printf
        "line %d, characters %d-%d:\n%3d | %s\n      %s%s\n%s\n"
        line
        first
        last
        line
        lines.(line - 1)
        (String.make first ' ')
        (String.make (last - first) '^')
        message)
;;

let uart_tx16 ~out =
  String.substr_replace_first
    {ocaml|
let uart_tx16 =
  [%firmware
    {|
    set p, 16
    set pins, 1              ; idle high
idle:
    wait tx
    pull
    set x, 7
    mov t, now               ; anchor the frame
    set pins, 0              ; start bit
    add t, p
bit:
    wait t+
    OUT
    jmp x--, bit
    wait t+
    set pins, 1              ; stop bit
    wait t
    jmp idle
|}]
;;
|ocaml}
    ~pattern:"OUT"
    ~with_:out
;;

let%expect_test "a bit loop one cycle too long fails the build at its deadline wait" =
  (* each pass of the bit loop is the wait, the out with its delay and the jmp: 16 cycles
     with [12], one more than the period with [13] *)
  build (uart_tx16 ~out:"out pins, 1 [12]");
  [%expect {| builds |}];
  build (uart_tx16 ~out:"out pins, 1 [13]");
  [%expect
    {|
    line 15, characters 4-11:
     15 |     wait t+
              ^^^^^^^
    uart_tx16 is refused by the analyser: this deadline wait can be reached late, by more on each pass of a loop or after an untimed wait
    line 18, characters 4-11:
     18 |     wait t+
              ^^^^^^^
    and here
    line 20, characters 4-10:
     20 |     wait t
              ^^^^^^
    and here
    |}]
;;

let%expect_test "firmware the analyser passes and the kernel refuses" =
  build
    [%string
      {ocaml|
let gap_adding_x =
  [%firmware
    {|%{In_channel.read_all "assemble/gap_adding_x.asm"}|}]
;;
|ocaml}];
  [%expect
    {|
    line 20, characters 4-10:
     20 |     wait t
              ^^^^^^
    gap_adding_x is refused by the proved kernel: the analyser passed this row, and the kernel refuses it: in time, next phase
    |}]
;;

let%expect_test "the settings are worked out at compile time, from names bound above" =
  build
    {ocaml|
let pin = 6

let config =
  { Program_config.default with out_base = pin; set_base = pin + 1 }
;;

let ok =
  [%firmware
    {|
    set p, 8
    out pins, 1
|}
      ~config
      ~period:(2 * 4)]
;;

let elsewhere =
  [%firmware
    {|
    nop
|}
      ~config:Firmware.spi_config]
;;

let not_a_field =
  [%firmware
    {|
    nop
|}
      ~config:{ config with out_bass = 2 }]
;;

let typo =
  [%firmware
    {|
    nop
    frob pins, 1
|}]
;;

let nested = Some [%firmware {| nop |}]

let first_line = [%firmware {fw|  frob ; on the opening line
    nop|fw}]

let rec pin = 7

let shadowed =
  [%firmware
    {|
    nop
|}
      ~config:{ Program_config.default with out_base = pin }]
;;

open Program_config

let behind_open =
  [%firmware
    {|
    nop
|}
      ~config:{ default with out_base = 1 }]
;;
|ocaml};
  [%expect
    {xxx|
    line 23, characters 14-33:
     23 |       ~config:Firmware.spi_config]
                        ^^^^^^^^^^^^^^^^^^^
    [%firmware] checks at compile time, so this has to be a literal, integer arithmetic, a record or a name bound by a top-level let above
    line 31, characters 28-36:
     31 |       ~config:{ config with out_bass = 2 }]
                                      ^^^^^^^^
    [%firmware] no field out_bass
    line 38, characters 4-16:
     38 |     frob pins, 1
              ^^^^^^^^^^^^
    typo does not assemble: cannot parse frob (args (pins 1))
    line 42, characters 20-28:
     42 | let nested = Some [%firmware {| nop |}]
                              ^^^^^^^^
    [%firmware] has to be the whole of a top-level [let name = ...]
    line 44, characters 34-38:
     44 | let first_line = [%firmware {fw|  frob ; on the opening line
                                            ^^^^
    first_line does not assemble: cannot parse frob (args ())
    line 54, characters 55-58:
     54 |       ~config:{ Program_config.default with out_base = pin }]
                                                                 ^^^
    [%firmware] cannot follow pin, bound by more than a plain top-level let
    line 64, characters 16-23:
     64 |       ~config:{ default with out_base = 1 }]
                          ^^^^^^^
    [%firmware] cannot tell what default is, past an open or include above
    |xxx}]
;;

(* The library's literal firmwares, checked as they compiled and again as they load. *)
let%expect_test "the literal firmwares" =
  List.iter
    [ "uart_tx16", Firmware.uart_tx16
    ; "spi_slave", Firmware.spi_slave
    ; "i2c_slave", Firmware.i2c_slave
    ; "i2c_logger", Firmware.i2c_logger
    ; "usb_tx", Firmware.usb_tx
    ; "ethernet", Ethernet.firmware
    ; "one_wire", One_wire.firmware
    ; "ps2", Ps2.firmware
    ; "can", Can.firmware
    ]
    ~f:(fun (name, timed) ->
      print_s [%message name ~_:(Timed_program.verdict timed : Analyser.Verdict.t)]);
  (* the demo's literal is the library's uart_tx at period 16, word for word *)
  [%test_result: int list]
    (Timed_program.words Firmware.uart_tx16)
    ~expect:(Firmware.assemble (Firmware.uart_tx ~period:16));
  [%expect
    {|
    (uart_tx16 ((words 15) (deadline_waits 3) (worst_slack (12))))
    (spi_slave ((words 6) (deadline_waits 0) (worst_slack ())))
    (i2c_slave ((words 72) (deadline_waits 0) (worst_slack ())))
    (i2c_logger ((words 73) (deadline_waits 25) (worst_slack (1))))
    (usb_tx ((words 65) (deadline_waits 11) (worst_slack (16))))
    (ethernet ((words 24) (deadline_waits 1) (worst_slack (63987))))
    (one_wire ((words 48) (deadline_waits 15) (worst_slack (0))))
    (ps2 ((words 65) (deadline_waits 12) (worst_slack (0))))
    (can ((words 56) (deadline_waits 10) (worst_slack (0))))
    |}]
;;
