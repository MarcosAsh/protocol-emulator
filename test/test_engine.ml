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
  let program = assemble {|
loop:
    add x, 1
    mov isr, x
    push
    jmp loop
|} in
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
  [%expect
    {|
    ("lockstep held" (cycles 120))
    ((tx 15) (rx (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)) (overflow true))
    |}]
;;

(* The host pops a full rx fifo now and then, so some pushes meet a pop at fifteen: the
   push lands, as in the model. *)
let%expect_test "a push beside a pop at fifteen lands" =
  let program = assemble {|
loop:
    add x, 1
    mov isr, x
    push
    jmp loop
|} in
  let random = Splittable_random.of_int 4 in
  let level = ref 0 in
  let host _ =
    { Host.idle with
      pop_rx = !level = Machine.fifo_depth && Splittable_random.int random ~lo:0 ~hi:3 = 0
    }
  in
  let m =
    lockstep
      ~cycles:600
      ~config:Program_config.default
      ~program
      ~inputs:(fun _ -> 0)
      ~host
      ~react:(fun m -> level := List.length m.rx_fifo)
      ()
  in
  print_s [%message (List.length m.rx_fifo : int) (m.fault.overflow : bool)];
  [%expect
    {|
    ("lockstep held" (cycles 600))
    (("List.length m.rx_fifo" 15) ("(m.fault).overflow" true))
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

(* registered beside [instruction], so they agree with it from the cycle after a clear, as
   formal/issue_timing.sv asserts; the core runs into a word that does not decode *)
let%expect_test "decode_ok and opcode_onehot agree with the instruction from a clear" =
  Harness.run
    ~random_initial_state:`All
    ~create:(Solo.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
       let cycle () = Hardcaml_lws.Lws.cycle h in
       let disagree = ref [] in
       let check n =
         let o = Before_and_after_edge.after_edge outputs in
         let instruction = Bits.to_unsigned_int !(o.instruction) in
         let decodes = Result.is_ok (Isa.of_word ~side_set_count:0 instruction) in
         let opcode = Isa.Field.extract Isa.Field.op instruction in
         if Bool.( <> ) (Bits.to_bool !(o.decode_ok)) decodes
            || Bits.to_unsigned_int !(o.opcode_onehot) <> 1 lsl opcode
         then disagree := n :: !disagree
       in
       i.clocking.clear := Bits.vdd;
       cycle ();
       i.clocking.clear := Bits.gnd;
       Engine.Config.iter2
         i.config
         (Engine.Config.of_program_config Program_config.default)
         ~f:( := );
       check 0;
       List.iteri [ 0xa000; 0xe0ff ] ~f:(fun addr word ->
         i.program_write.valid := Bits.vdd;
         i.program_write.addr <--. addr;
         i.program_write.data <--. word;
         cycle ();
         check (addr + 1));
       i.program_write.valid := Bits.gnd;
       i.start := Bits.vdd;
       cycle ();
       i.start := Bits.gnd;
       List.iter (List.range 3 12) ~f:(fun n ->
         check n;
         cycle ());
       let o = Before_and_after_edge.after_edge outputs in
       print_s
         [%message
           ""
             ~disagree:(List.rev !disagree : int list)
             ~decode_fault:(Bits.to_bool !(o.fault.decode) : bool)
             ~halted:(Bits.to_bool !(o.halted) : bool)]);
  [%expect {| ((disagree ()) (decode_fault true) (halted true)) |}]
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

(* clears the core, writes [config] and [program] and starts it *)
let load (i : _ Solo.I.t) ~cycle ~config program =
  i.clocking.clear := Bits.vdd;
  cycle ();
  i.clocking.clear := Bits.gnd;
  Engine.Config.iter2 i.config config ~f:( := );
  List.iteri program ~f:(fun addr word ->
    i.program_write.valid := Bits.vdd;
    i.program_write.addr <--. addr;
    i.program_write.data <--. word;
    cycle ());
  i.program_write.valid := Bits.gnd;
  i.start := Bits.vdd;
  cycle ();
  i.start := Bits.gnd
;;

(* [Program_config] stops at 2, but the host port writes the field's two bits as given *)
let%expect_test "a side-set count of 3, which only the host can write, acts as 2" =
  let program =
    assemble
      {|
    .side_set 2
loop:
    set x, 2 side 1 [7]
    set pins, 1 side 2 [3]
more:
    set pins, 0 side 3 [1]
    jmp x--, more
    set y, 0 side 0 [6]
    jmp loop
|}
  in
  let config =
    Engine.Config.of_program_config
      { Program_config.default with side_set_count = 2; side_set_base = 5; set_base = 7 }
  in
  let pins side_set_count =
    let pins = Queue.create () in
    Harness.run
      ~create:(Solo.hierarchical ~memory:Flops)
      (fun (h @ local) ~inputs:i ~outputs ->
         let cycle () = Lws.cycle h in
         load
           i
           ~cycle
           ~config:
             { config with side_set_count = Bits.of_unsigned_int ~width:2 side_set_count }
           program;
         for _ = 1 to 120 do
           cycle ();
           Queue.enqueue
             pins
             (Bits.to_unsigned_int !((Before_and_after_edge.after_edge outputs).pin_out))
         done);
    Queue.to_list pins
  in
  let two = pins 2 in
  let edges = List.length (List.remove_consecutive_duplicates two ~equal:Int.equal) - 1 in
  print_s [%message "" ~same:(List.equal Int.equal two (pins 3) : bool) (edges : int)];
  [%expect {| ((same true) (edges 15)) |}]
;;

(* the core empties a full tx fifo, then overfills rx, which the host then drains *)
let%expect_test "a push into a full rx fifo faults overflow" =
  let program =
    assemble
      {|
    set x, 7
drain:
    pull
    jmp x--, drain
    set x, 8
fill:
    push
    jmp x--, fill
    halt
|}
  in
  let m =
    lockstep
      ~cycles:100
      ~config:Program_config.default
      ~program
      ~preload:(List.init Machine.fifo_depth ~f:Fn.id)
      ~inputs:(fun _ -> 0)
      ~host:(fun n -> { Host.idle with pop_rx = n >= 80 })
      ()
  in
  print_s
    [%message
      (m.fault : Machine.Fault.t)
        (List.length m.tx_fifo : int)
        (List.length m.rx_fifo : int)];
  [%expect
    {|
    ("lockstep held" (cycles 100))
    ((m.fault
      ((underflow false) (overflow true) (missed_deadline false) (decode false)))
     ("List.length m.tx_fifo" 0) ("List.length m.rx_fifo" 0))
    |}]
;;

(* every fault is sticky until a clear, which lets go of all four *)
let%expect_test "a clear lets go of every fault" =
  let program =
    assemble
      {|
    pull
    mov t, now
    wait t
    set x, 8
fill:
    push
    jmp x--, fill
|}
    @ [ 0xe0ff ]
  in
  Harness.run
    ~create:(Solo.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
       let cycle () = Lws.cycle h in
       let faults () =
         let o = Before_and_after_edge.after_edge outputs in
         Engine.Fault.map o.fault ~f:(fun r -> Bits.to_bool !r), Bits.to_bool !(o.faulted)
       in
       load
         i
         ~cycle
         ~config:(Engine.Config.of_program_config Program_config.default)
         program;
       for _ = 1 to 40 do
         cycle ()
       done;
       let held = faults () in
       i.clocking.clear := Bits.vdd;
       cycle ();
       i.clocking.clear := Bits.gnd;
       cycle ();
       print_s
         [%message
           (held : bool Engine.Fault.t * bool)
             ~cleared:(faults () : bool Engine.Fault.t * bool)]);
  [%expect
    {|
    ((held
      (((underflow true) (overflow true) (missed_deadline true) (decode true))
       true))
     (cleared
      (((underflow false) (overflow false) (missed_deadline false)
        (decode false))
       false)))
    |}]
;;

(* sets [now] in the simulator a few cycles short of each carry into its top six bits,
   which a run takes 2^24 cycles to reach; every carry and the wrap are the counter's own *)
let%expect_test "now and capture carry into their top bits" =
  Harness.run_advanced
    ~trace:`Everything
    ~create:(Solo.hierarchical ~memory:Flops)
    (fun (h @ local) context ->
       let sim =
         match Lws_context.simulator_specific context with
         | Cyclesim sim -> Lws_context.Simulator_specific.Cyclesim.simulator sim
         | Evsim _ | Cosim -> assert false
       in
       let traced = (Cyclesim.traced sim).internal_signals in
       let now =
         List.find_map_exn traced ~f:(fun { signal; mangled_names } ->
           if List.mem mangled_names "solo$engine$now" ~equal:String.equal
           then Signal.Type.wire_driver signal
           else None)
       in
       let now =
         List.find_map_exn traced ~f:(fun traced ->
           if Signal.Type.Uid.equal (Signal.uid traced.signal) (Signal.uid now)
           then Cyclesim.lookup_reg sim traced
           else None)
       in
       let i = context.inputs in
       let run n = Lws.step ~n h in
       let o = Before_and_after_edge.after_edge context.outputs in
       load
         i
         ~cycle:(fun () -> run 1)
         ~config:
           (Engine.Config.of_program_config
              { Program_config.default with capture_pin = 0; capture_rising = true })
         (assemble
            {|
loop:
    capture_arm
    wait 1 pin 0
    wait 0 pin 0
    jmp loop
|});
       let int r = Bits.to_unsigned_int !r in
       let set_now v =
         Cyclesim.Reg.of_bits now (Bits.of_unsigned_int ~width:Isa.timer_bits v)
       in
       (* past the start, which zeroes [now] the cycle after *)
       run 2;
       List.iter (List.range 18 24) ~f:(fun bit ->
         set_now ((1 lsl bit) - 3);
         run 6;
         print_s [%message "" ~now:(int o.now : Int.Hex.t)]);
       set_now ((1 lsl Isa.timer_bits) - 40);
       run 4;
       i.inputs := Bits.of_unsigned_int ~width:Isa.pin_space 1;
       run 4;
       let high = int o.capture in
       run 40;
       i.inputs := Bits.zero Isa.pin_space;
       run 4;
       i.inputs := Bits.of_unsigned_int ~width:Isa.pin_space 1;
       run 4;
       print_s
         [%message
           ""
             ~capture:(high : Int.Hex.t)
             ~then_:(int o.capture : Int.Hex.t)
             ~now:(int o.now : Int.Hex.t)]);
  [%expect
    {|
    (now 0x40003)
    (now 0x80003)
    (now 0x100003)
    (now 0x200003)
    (now 0x400003)
    (now 0x800003)
    ((capture 0xffffdc) (then_ 0xc) (now 0x10))
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

(* [halted] stays high through a start's second cycle, which prefetches the word after pc
   0 under the config of the time. A wrap written then has the core run [set x, 1] again
   at pc 1. The host port never writes there (formal/host_spacing.sv). *)
let%expect_test "a config written in a start's second cycle runs the wrong word" =
  let program = assemble {|
    set x, 1
    set y, 7
    halt
|} in
  let wrap ~top =
    Engine.Config.of_program_config
      { Program_config.default with wrap_bottom = 0; wrap_top = top }
  in
  Harness.run
    ~create:(Solo.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
       let cycle () = Lws.cycle h in
       i.clocking.clear := Bits.vdd;
       cycle ();
       i.clocking.clear := Bits.gnd;
       Engine.Config.iter2 i.config (wrap ~top:0) ~f:( := );
       List.iteri program ~f:(fun addr word ->
         i.program_write.valid := Bits.vdd;
         i.program_write.addr <--. addr;
         i.program_write.data <--. word;
         cycle ());
       i.program_write.valid := Bits.gnd;
       i.start := Bits.vdd;
       cycle ();
       i.start := Bits.gnd;
       let o = Before_and_after_edge.after_edge outputs in
       let halted_after_start = Bits.to_bool !(o.halted) in
       cycle ();
       Engine.Config.iter2 i.config (wrap ~top:511) ~f:( := );
       List.iter (List.range 0 4) ~f:(fun _ ->
         cycle ();
         let o = Before_and_after_edge.after_edge outputs in
         print_s
           [%message
             ""
               ~pc:(Bits.to_unsigned_int !(o.pc) : int)
               ~instruction:(Bits.to_unsigned_int !(o.instruction) : Int.Hex.t)
               ~word_at_pc:
                 (List.nth program (Bits.to_unsigned_int !(o.pc)) : Int.Hex.t option)
               ~x:(Bits.to_unsigned_int !(o.x) : int)
               ~y:(Bits.to_unsigned_int !(o.y) : int)]);
       print_s [%message (halted_after_start : bool)]);
  [%expect
    {|
    ((pc 1) (instruction 0xa021) (word_at_pc (0xa047)) (x 1) (y 0))
    ((pc 2) (instruction 0xe001) (word_at_pc (0xe001)) (x 1) (y 0))
    ((pc 3) (instruction 0x0) (word_at_pc ()) (x 1) (y 0))
    ((pc 3) (instruction 0x0) (word_at_pc ()) (x 1) (y 0))
    (halted_after_start true)
    |}]
;;

(* the captures land all over the 128 cycles, so every bit of [capture] and of [t] after
   it moves both ways *)
let%expect_test "a 7-bit capture and the deadline after it take every bit" =
  let program =
    assemble
      {|
    set p, 3
loop:
    capture_arm
    wait 1 pin 0
    mov t, capture
    add t, p
    wait 0 pin 0
    jmp loop
|}
  in
  Narrow_harness.run
    ~create:(Narrow.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
       let cycle () = Lws.cycle h in
       let after () = Before_and_after_edge.after_edge outputs in
       i.clocking.clear := Bits.vdd;
       cycle ();
       i.clocking.clear := Bits.gnd;
       Engine.Config.iter2
         i.config
         (Engine.Config.of_program_config
            { Program_config.default with capture_pin = 0; capture_rising = true })
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
       let random = Splittable_random.of_int 5 in
       let pairs =
         List.init 24 ~f:(fun _ ->
           let wait = Splittable_random.int random ~lo:6 ~hi:60 in
           for _ = 1 to wait do
             cycle ()
           done;
           i.inputs := Bits.of_unsigned_int ~width:Isa.pin_space 1;
           for _ = 1 to 6 do
             cycle ()
           done;
           i.inputs := Bits.zero Isa.pin_space;
           cycle ();
           let int r = Bits.to_unsigned_int !r in
           int (after ()).capture, int (after ()).t)
       in
       let t_is_capture_plus_3 =
         List.for_all pairs ~f:(fun (capture, t) -> t = (capture + 3) land 0x7f)
       in
       let distinct =
         List.length (List.dedup_and_sort pairs ~compare:[%compare: int * int])
       in
       print_s [%message (t_is_capture_plus_3 : bool) (distinct : int)]);
  [%expect {| ((t_is_capture_plus_3 true) (distinct 24)) |}]
;;
