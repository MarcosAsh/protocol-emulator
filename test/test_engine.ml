open! Core
open! Hardcaml
open Hardcaml_lws
open! Hardcaml_test_harness
open! Hardcaml_waveterm
open Protocol_emulator
open Firmware
open Lockstep
module Harness = Hardcaml_test_harness.Lws_harness.Make (Solo.I) (Solo.O)

let ( <--. ) = Bits.( <--. )

let%expect_test "wait rx blocks on a full fifo" =
  let program =
    assemble {|
loop:
    wait rx
    push
    add x, 1
    mov isr, x
    jmp loop
|}
  in
  let random = Splittable_random.of_int 9 in
  let host _ =
    { Host.idle with tx = None; pop_rx = Splittable_random.int random ~lo:0 ~hi:3 = 0 }
  in
  let (_ : Machine.t) =
    lockstep ~config:Program_config.default ~program ~inputs:(fun _ -> 0) ~host ()
  in
  [%expect {| ("lockstep held" (cycles 400)) |}]
;;

(* The host fills the tx fifo as far as it takes words; the core pushes a count with no
   one reading, and the sixteenth push faults. *)
let%expect_test "both fifos hold fifteen words" =
  let program =
    assemble {|
loop:
    add x, 1
    mov isr, x
    push
    jmp loop
|}
  in
  let level = ref 0 in
  let host _ =
    { Host.idle with tx = Option.some_if (!level < Machine.fifo_depth) 0x1234 }
  in
  let m =
    lockstep
      ~cycles:120
      ~config:Program_config.default
      ~program
      ~inputs:(fun _ -> 0)
      ~host
      ~react:(fun m -> level := List.length m.tx_fifo)
      ()
  in
  print_s
    [%message
      ""
        ~tx:(List.length m.tx_fifo : int)
        ~rx:(m.rx_fifo : int list)
        ~overflow:(m.fault.overflow : bool)];
  [%expect {|
    ("lockstep held" (cycles 120))
    ((tx 15) (rx (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)) (overflow true))
    |}]
;;

let%expect_test "a jump tests the fifos without stalling or faulting" =
  List.iter Fifo_poll.programs ~f:(fun program ->
    let random = Splittable_random.of_int 7 in
    let level = ref 0 in
    let host _ =
      let int hi = Splittable_random.int random ~lo:0 ~hi in
      { Host.idle with
        tx =
          (if !level < Machine.fifo_depth && int 9 = 0 then Some (int 0xffff) else None)
      ; pop_rx = int 40 = 0
      }
    in
    let m =
      lockstep
        ~cycles:600
        ~config:{ Program_config.default with in_base = 5 }
        ~program:(assemble program)
        ~inputs:(fun _ -> 0)
        ~host
        ~react:(fun m -> level := List.length m.tx_fifo)
        ()
    in
    print_s [%message (m.fault : Machine.Fault.t)]);
  [%expect
    {|
    ("lockstep held" (cycles 600))
    (m.fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)
      (assumption false)))
    ("lockstep held" (cycles 600))
    (m.fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)
      (assumption false)))
    |}]
;;

let%expect_test "the host stops the core and starts it again" =
  let program = assemble {|
loop:
    mov pins, !pins [3]
    add x, 1
    jmp loop
|} in
  let m =
    lockstep
      ~cycles:60
      ~config:{ Program_config.default with in_base = 5 }
      ~program
      ~inputs:(fun _ -> 0)
      ~host:(fun n -> { Host.idle with stop = n = 21 || n = 22 || n = 40 })
      ()
  in
  print_s [%message (m.halted : bool) (m.x : int)];
  [%expect {|
    ("lockstep held" (cycles 60))
    ((m.halted true) (m.x 3))
    |}]
;;

let%expect_test "a flush empties both fifos of a halted core and no others" =
  let program =
    assemble {|
loop:
    add x, 1
    mov isr, x
    push [3]
    jmp loop
|}
  in
  let levels = Queue.create () in
  let watch = [ 10; 11; 31; 32; 33; 34; 36 ] in
  let cycle = ref 0 in
  let m =
    lockstep
      ~cycles:60
      ~config:Program_config.default
      ~program
      ~inputs:(fun _ -> 0)
      ~host:(fun n ->
        { Host.idle with
          tx = (if n < 3 || n = 32 || n = 35 then Some (0x100 + n) else None)
        ; stop = n = 30
        ; flush = n = 10 || n = 30 || n = 32
        })
      ~react:(fun m ->
        if List.mem watch !cycle ~equal:Int.equal
        then
          Queue.enqueue
            levels
            (!cycle, m.halted, List.length m.tx_fifo, List.length m.rx_fifo);
        Int.incr cycle)
      ()
  in
  print_s
    [%message
      (levels : (int * bool * int * int) Queue.t) (m.tx_fifo : int list) (m.x : int)];
  [%expect
    {|
    ("lockstep held" (cycles 60))
    ((levels
      ((10 false 3 2) (11 false 3 2) (31 true 3 4) (32 true 0 0) (33 true 0 0)
       (34 true 0 0) (36 true 1 0)))
     (m.tx_fifo (291)) (m.x 4))
    |}]
;;

let%expect_test "a program signals itself over the wires" =
  let program =
    assemble
      {|
    set pins, 1
    wait 1 pin 20
    set pins, 2
    wait 0 pin 20
    jmp pin, seen
    halt
seen:
    in pins, 3
    push
    wait 1 pin 22
    add x, 1
    halt
|}
  in
  let m =
    lockstep
      ~cycles:60
      ~config:
        { Program_config.default with
          set_base = 20
        ; set_count = 2
        ; in_base = 20
        ; jmp_pin = 21
        }
      ~program
      ~inputs:(fun n -> if n >= 30 then 1 lsl 22 else 0)
      ()
  in
  print_s
    [%message
      (m.rx_fifo : int list)
        (m.x : int)
        ~wires:(m.pin_out lsr Isa.num_pins : int)
        ~pin_dir:(m.pin_dir : int)];
  [%expect
    {|
    ("lockstep held" (cycles 60))
    ((m.rx_fifo (16384)) (m.x 1) (wires 2) (pin_dir 0))
    |}]
;;

let%expect_test "the host clears the interrupt" =
  let program = assemble {|
loop:
    irq [7]
    jmp loop
|} in
  let random = Splittable_random.of_int 4 in
  let host _ =
    { Host.idle with clear_irq = Splittable_random.int random ~lo:0 ~hi:5 = 0 }
  in
  let (_ : Machine.t) =
    lockstep
      ~cycles:200
      ~config:Program_config.default
      ~program
      ~inputs:(fun _ -> 0)
      ~host
      ()
  in
  [%expect {| ("lockstep held" (cycles 200)) |}]
;;

let%expect_test "the osr is empty once the pull threshold has gone out" =
  let program =
    assemble
      {|
    pull
    out null, 7
    jmp !osre, more
    halt
more:
    out null, 1
    jmp !osre, more
    halt
|}
  in
  let m =
    lockstep
      ~cycles:12
      ~config:{ Program_config.default with pull_threshold = 8 }
      ~program
      ~preload:[ 0xa5 ]
      ~inputs:(fun _ -> 0)
      ()
  in
  print_s [%message (m.pc : int) (m.osr_count : int) (m.halted : bool)];
  [%expect
    {|
    ("lockstep held" (cycles 12))
    ((m.pc 7) (m.osr_count 8) (m.halted true))
    |}]
;;

let%expect_test "faults and halt" =
  let program = assemble {|
    pull
    mov t, now
    wait t
    halt
|} in
  let m =
    lockstep ~cycles:12 ~config:Program_config.default ~program ~inputs:(fun _ -> 0) ()
  in
  print_s [%message (m.fault : Machine.Fault.t) (m.halted : bool)];
  [%expect
    {|
    ("lockstep held" (cycles 12))
    ((m.fault
      ((underflow true) (overflow false) (missed_deadline true) (decode false)
       (assumption false)))
     (m.halted true))
    |}]
;;

let%expect_test "a deadline wait carries the fraction once while a delay holds it" =
  let program = assemble {|
    set p, 4
    set x, 0 [3]
    wait t+
    halt
|} in
  let (_ : Machine.t) =
    lockstep
      ~cycles:12
      ~config:{ Program_config.default with period_fraction = 0x8000 }
      ~program
      ~inputs:(fun _ -> 0)
      ()
  in
  [%expect {| ("lockstep held" (cycles 12)) |}]
;;

let%expect_test "a decode fault halts the core" =
  let m =
    lockstep
      ~cycles:4
      ~config:Program_config.default
      ~program:[ 0xa000; 0xe0ff ]
      ~inputs:(fun _ -> 0)
      ()
  in
  print_s [%message (m.fault : Machine.Fault.t) (m.pc : int)];
  [%expect
    {|
    ("lockstep held" (cycles 4))
    ((m.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode true)
       (assumption false)))
     (m.pc 1))
    |}]
;;

let%expect_test "waveform of a short loop" =
  let program =
    assemble
      {|
    set p, 4
    mov t, now
loop:
    wait t+
    mov pins, !pins
    jmp loop
|}
  in
  let config = { Program_config.default with in_base = 5; out_base = 5; out_count = 1 } in
  let display_rules =
    List.map [ "pc"; "now"; "t"; "stall"; "issue"; "word"; "pin_out" ] ~f:(fun name ->
      Display_rule.port_name_is ("solo$engine$" ^ name) ~wave_format:(Bit_or Unsigned_int))
  in
  Harness.run
    ~create:(Solo.hierarchical ~memory:Flops)
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:22
        ~display_width:102
        ~wave_width:0
        waves)
    (fun (h @ local) ~inputs:i ~outputs:_ ->
      let cycle ?n () = Lws.step ?n h in
      i.clocking.clear := Bits.vdd;
      cycle ();
      i.clocking.clear := Bits.gnd;
      Engine.Config.iter2 i.config (Engine.Config.of_program_config config) ~f:( := );
      List.iteri program ~f:(fun addr word ->
        i.program_write.valid := Bits.vdd;
        i.program_write.addr <--. addr;
        i.program_write.data <--. word;
        cycle ());
      i.program_write.valid := Bits.gnd;
      i.start := Bits.vdd;
      cycle ();
      i.start := Bits.gnd;
      cycle ();
      cycle ~n:24 ();
      ());
  [%expect
    {|
    ┌Signals─────────────┐┌Waves─────────────────────────────────────────────────────────────────────────┐
    │                    ││──────────────────┬─┬─┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─            │
    │solo$engine$pc      ││ 0                │1│2│3│4│2  │3│4│2  │3│4│2  │3│4│2  │3│4│2  │3│4            │
    │                    ││──────────────────┴─┴─┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─            │
    │                    ││────┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─            │
    │solo$engine$now     ││ 0  │1│2│3│4│5│6│0│1│2│3│4│5│6│7│8│9│.│.│.│.│.│.│.│.│.│.│.│.│.│.│.            │
    │                    ││────┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─            │
    │                    ││────────────────────┬─┬───────┬───────┬───────┬───────┬───────┬───            │
    │solo$engine$t       ││ 0                  │1│5      │9      │13     │17     │21     │25             │
    │                    ││────────────────────┴─┴───────┴───────┴───────┴───────┴───────┴───            │
    │                    ││──────────────────────────┬─┬─────┬─┬─────┬─┬─────┬─┬─────┬─┬─────            │
    │solo$engine$stall   ││ 0                        │1│0    │1│0    │1│0    │1│0    │1│0                │
    │                    ││──────────────────────────┴─┴─────┴─┴─────┴─┴─────┴─┴─────┴─┴─────            │
    │solo$engine$issue   ││──┐             ┌─────────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────            │
    │                    ││  └─────────────┘         └─┘     └─┘     └─┘     └─┘     └─┘                 │
    │                    ││────────────────┬─┬─┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬───┬─┬─┬─            │
    │solo$engine$word    ││ 0              │.│.│.│.│2  │.│.│2  │.│.│2  │.│.│2  │.│.│2  │.│.│2            │
    │                    ││────────────────┴─┴─┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴───┴─┴─┴─            │
    │                    ││────────────────────────┬───────┬───────┬───────┬───────┬───────┬─            │
    │solo$engine$pin_out ││ 0                      │32     │0      │32     │0      │32     │0            │
    │                    ││────────────────────────┴───────┴───────┴───────┴───────┴───────┴─            │
    └────────────────────┘└──────────────────────────────────────────────────────────────────────────────┘
    |}]
;;

let%expect_test "random programs" =
  random_programs ~programs:64 ~cycles:1000 (fun random ~config ->
    Random_program.program random ~config);
  [%expect {| ((programs 64) (failed ())) |}]
;;

let%expect_test "random programs with the host stopping the core" =
  random_programs ~stops:true ~programs:64 ~cycles:400 (fun random ~config ->
    Random_program.program random ~config);
  [%expect {| ((programs 64) (failed ())) |}]
;;

let%expect_test "every mov and alu form" =
  random_programs ~wrap:false ~programs:4 ~cycles:300 (fun _ ~config:_ ->
    Sweep_program.words);
  [%expect {| ((programs 4) (failed ())) |}]
;;

module Narrow = Engine.Make (struct
    let timer_bits = 7
  end)

module Narrow_harness = Hardcaml_test_harness.Lws_harness.Make (Engine.I) (Narrow.O)

let%expect_test "a 7-bit timer wraps and its deadlines keep their spacing" =
  let program =
    assemble
      {|
    set p, 20
    mov t, now
    add t, p
loop:
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    jmp loop
|}
  in
  Narrow_harness.run
    ~random_initial_state:`All
    ~create:(Narrow.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
       let cycle () = Lws.cycle h in
       let after () = Before_and_after_edge.after_edge outputs in
       i.clocking.clear := Bits.vdd;
       cycle ();
       i.clocking.clear := Bits.gnd;
       Engine.Config.iter2
         i.config
         (Engine.Config.of_program_config Program_config.default)
         ~f:( := );
       List.iteri program ~f:(fun addr word ->
         i.program_write.valid := Bits.vdd;
         i.program_write.addr <--. addr;
         i.program_write.data <--. word;
         cycle ());
       i.program_write.valid := Bits.gnd;
       i.start := Bits.vdd;
       cycle ();
       i.start := Bits.gnd;
       (* each edge of the pin, with the cycle since the start and [now] then *)
       let edges =
         List.range 1 300
         |> List.filter_map ~f:(fun n ->
           let before = Bits.to_unsigned_int !((after ()).pin_out) in
           cycle ();
           let o = after () in
           Option.some_if
             (Bits.to_unsigned_int !(o.pin_out) <> before)
             (n, Bits.to_unsigned_int !(o.now)))
       in
       let gaps =
         List.map2_exn
           (List.drop_last_exn edges)
           (List.tl_exn edges)
           ~f:(fun (a, _) (b, _) -> b - a)
         |> List.dedup_and_sort ~compare:Int.compare
       in
       let missed_deadline = Bits.to_bool !((after ()).fault.missed_deadline) in
       print_s
         [%message (edges : (int * int) list) (gaps : int list) (missed_deadline : bool)]);
  [%expect
    {|
    ((edges
      ((24 23) (44 43) (64 63) (84 83) (104 103) (124 123) (144 15) (164 35)
       (184 55) (204 75) (224 95) (244 115) (264 7) (284 27)))
     (gaps (20)) (missed_deadline false))
    |}]
;;
