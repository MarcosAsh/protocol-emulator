open! Core
open Protocol_emulator
open Pio

let program file name =
  In_channel.read_all ("pico_examples/" ^ file)
  |> Pioasm.parse
  |> ok_exn
  |> List.find_exn ~f:(fun (p : Pioasm.Program.t) -> String.equal p.name name)
;;

let certify program ~k =
  match Census.certify program ~k with
  | Ok certified -> certified
  | Error verdict -> raise_s [%sexp (verdict : Census.Verdict.t)]
;;

let every_program () =
  Sys_unix.ls_dir "pico_examples"
  |> List.filter ~f:(String.is_suffix ~suffix:".pio")
  |> List.sort ~compare:String.compare
  |> List.concat_map ~f:(fun file ->
    In_channel.read_all ("pico_examples/" ^ file)
    |> Pioasm.parse
    |> ok_exn
    |> List.map ~f:(fun program -> file, program))
;;

let%expect_test "uart_tx at k = 8: side-set shares the pin with out, so comes by set" =
  let t, timed = certify (program "uart_tx.pio" "uart_tx") ~k:8. in
  List.iter t.contract ~f:print_endline;
  print_string t.source;
  print_s [%sexp (Timed_program.verdict timed : Analyser.Verdict.t)];
  [%expect {|
    tx words fit 16 bits
        set p, 8
        set pins, 1
        mov t, now
        add t, p
        add t, 7
    n0:
        jmp tx, m0
    m0s:
        wait t+                  ; pull side 1 [7]
        set pins, 1
        wait tx
        mov t, now
        pull
        add t, p
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
    n1:
    m1:
        wait t+                  ; set x, 7 side 0 [7]
        set pins, 0
        set x, 7
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
    n2:
    m2:
        wait t+                  ; out pins, 1
        out pins, 1
    n3:
    m3:
        wait t+                  ; jmp x-- bitloop [6]
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        jmp x--, n2
        jmp tx, m0
    m0sl1:
        wait t+                  ; pull side 1 [7]
        set pins, 1
        wait tx
        mov t, now
        pull
        add t, p
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        jmp n1
    m0:
        wait t+                  ; pull side 1 [7]
        set pins, 1
        pull
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        wait t+
        jmp n1
    ((words 65) (deadline_waits 40) (worst_slack (3)))
    |}]
;;

let%expect_test "census of pico-examples at 0d62f75" =
  print_string
    (Census.to_string
       (List.map (every_program ()) ~f:(fun (file, program) -> Census.row ~file program)));
  [%expect {|
    | file | program | verdict | least k | words | k at 50 MHz, certified |
    |---|---|---|---|---|---|
    | addition.pio | addition | refused: mov ~ into a register (32-bit invert) |  |  |  |
    | apa102.pio | apa102_mini | certified | 6 | 35 |  |
    | apa102.pio | apa102_rgb555 | refused: isr loaded whole, then shifted, isr read whole under a right shift, mov :: (32-bit reverse) |  |  |  |
    | blink.pio | blink | refused: 32-bit shift |  |  |  |
    | clocked_input.pio | clocked_input | certified | 5 | 17 |  |
    | differential_manchester.pio | differential_manchester_tx | certified | 5 | 112 |  |
    | differential_manchester.pio | differential_manchester_rx | certified | 5 | 57 |  |
    | hello.pio | hello | certified | 5 | 23 |  |
    | hub75.pio | hub75_row | refused: 27-bit shift, pull threshold 32 |  |  |  |
    | hub75.pio | hub75_data_rgb888 | refused: 26-bit shift, mov :: (32-bit reverse), pull threshold 24, pull with autopull |  |  |  |
    | i2c.pio | i2c | certified | 15 | 474 | 15.625 yes |
    | i2c.pio | set_scl_sda | certified | 3 | 41 | 15.625 yes |
    | manchester_encoding.pio | manchester_tx | certified | 5 | 86 |  |
    | manchester_encoding.pio | manchester_rx | certified | 5 | 43 |  |
    | nec_carrier_burst.pio | nec_carrier_burst | refused: wait irq |  |  |  |
    | nec_carrier_control.pio | nec_carrier_control | refused: pull threshold 32 |  |  |  |
    | nec_receive.pio | nec_receive | refused: push threshold 32 |  |  |  |
    | onewire_library.pio | onewire | certified | 5 | 108 | 50.000 yes |
    | pio_serialiser.pio | pio_serialiser | certified | 9 | 22 |  |
    | pwm.pio | pwm | certified | 7 | 36 |  |
    | quadrature_encoder.pio | quadrature_encoder | refused: isr loaded whole, then shifted, isr read whole under a right shift, mov pc, mov ~ into a register (32-bit invert) |  |  |  |
    | quadrature_encoder_substep.pio | quadrature_encoder_substep | refused: 32-bit shift, isr loaded whole, then shifted, isr read whole under a right shift, mov :: (32-bit reverse), mov pc, mov status, mov ~ into a register (32-bit invert) |  |  |  |
    | resistor_dac.pio | resistor_dac_5bit | certified | 9 | 22 |  |
    | spi.pio | spi_cpha0 | certified | 5 | 41 |  |
    | spi.pio | spi_cpha1 | certified | 6 | 27 |  |
    | spi.pio | spi_cpha0_cs | certified | 9 | 136 |  |
    | spi.pio | spi_cpha1_cs | certified | 9 | 100 |  |
    | squarewave.pio | squarewave | certified | 3 | 13 |  |
    | squarewave_fast.pio | squarewave_fast | certified | 4 | 11 |  |
    | squarewave_wrap.pio | squarewave_wrap | certified | 3 | 13 |  |
    | st7789_lcd.pio | st7789_lcd | certified | 6 | 35 |  |
    | uart_rx.pio | uart_rx_mini | certified | 5 | 32 | 54.253 yes |
    | uart_rx.pio | uart_rx | certified | 5 | 59 | 54.253 yes |
    | uart_tx.pio | uart_tx | certified | 5 | 65 | 54.253 yes |
    | ws2812.pio | ws2812 | certified | 5 | 73 | 6.250 yes |
    | ws2812.pio | ws2812_parallel | refused: 32-bit shift |  |  |  |

    36 programs: 25 certified, 11 refused, 0 not certified
    |}]
;;

let%expect_test "the source printed assembles to the words translated" =
  let certified =
    List.filter_map (every_program ()) ~f:(fun (_, program) ->
      match Census.least program with
      | Certified { k; _ } ->
        let t, _ = certify program ~k:(Float.of_int k) in
        let assembled = Asm.assemble t.source |> ok_exn in
        let words t = Asm.Program.words t |> ok_exn in
        let ours =
          List.map t.words ~f:(fun w ->
            Isa.to_word ~side_set_count:t.config.side_set_count w |> ok_exn)
        in
        if not ([%equal: int list] (words assembled) ours)
        then raise_s [%message "differ" program.name];
        Some program.name
      | Refused _ | Not_certified _ -> None)
  in
  print_s [%message "agree" ~programs:(List.length certified : int)];
  [%expect {| (agree (programs 25)) |}]
;;

(* pico-examples#796: the START holds SDA low 10 PIO cycles before SCL falls, 3.125 us at
   the 3.2 MHz pio_i2c.c runs, where UM10204 table 10 asks 4.0 us. At 50 MHz that rate is
   k = 15.625, the deadlines certify, and the kernel bounds the hold below 200 cycles. *)
let%expect_test "i2c certifies at its own rate, and the kernel refuses its START hold" =
  let i2c = program "i2c.pio" "i2c" in
  let _, timed = certify i2c ~k:15.625 in
  let config = Timed_program.config timed in
  let scl = config.side_set_base
  and sda = config.set_base in
  (* SCL falling while SDA is held low, since SDA's last edge *)
  let bound =
    Census.least_apart timed ~dirs:true ~a:scl ~b:sda ~apart:(fun ~own ~other ->
      (not own) && other)
  in
  let needed = 4_000 * Census.clock_hz / 1_000_000_000 in
  print_s
    [%message
      (bound : int option)
        ~us:(Option.map bound ~f:(fun n -> Float.of_int n /. 50.) : float option)
        (needed : int)];
  [%expect {| ((bound (149)) (us (2.98)) (needed 200)) |}]
;;

let%expect_test "refused features are named" =
  let refused text =
    let program = Pioasm.parse (".program p\n" ^ text) |> ok_exn |> List.hd_exn in
    match Translate.translate (Translate.Setup.default program ~period:8) program with
    | Ok _ -> printf "%-28s translates\n" text
    | Error refusals ->
      printf
        "%-28s %s\n"
        text
        (List.map refusals ~f:(fun r -> r.feature) |> String.concat ~sep:", ")
  in
  List.iter
    ~f:refused
    [ "irq clear 3"
    ; "wait 1 irq 2"
    ; "wait 0 gpio 4"
    ; "mov pc, x"
    ; "out pc, 5"
    ; "mov x, status"
    ; "mov x, ~y"
    ; "mov pins, ::x"
    ; "out exec, 16"
    ; "push iffull"
    ; "pull ifempty noblock"
    ; "out x, 32"
    ; "in pins, 24"
    ; "irq 3"
    ; "irq wait 0"
    ; "out null, 32"
    ];
  [%expect {|
    irq clear 3                  irq clear
    wait 1 irq 2                 wait irq
    wait 0 gpio 4                wait gpio
    mov pc, x                    mov pc
    out pc, 5                    out pc
    mov x, status                mov status
    mov x, ~y                    mov ~ into a register (32-bit invert)
    mov pins, ::x                mov :: (32-bit reverse)
    out exec, 16                 out exec without an exec table
    push iffull                  push iffull
    pull ifempty noblock         pull ifempty noblock
    out x, 32                    32-bit shift
    in pins, 24                  24-bit shift
    irq 3                        translates
    irq wait 0                   translates
    out null, 32                 translates
    |}]
;;
