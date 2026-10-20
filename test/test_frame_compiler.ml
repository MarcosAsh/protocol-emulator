open! Core
open! Hardcaml
open Hardcaml_lws
open Protocol_emulator

module Harness =
  Hardcaml_test_harness.Lws_harness.Make (Hobby_uart_tx.I) (Hobby_uart_tx.O)

let ( <--. ) = Bits.( <--. )
let clocks_per_bit = 8

module Uart = Hobby_uart_tx.Make (struct
    let clocks_per_bit = clocks_per_bit
  end)

let hobby_ports =
  { Frame_compiler.Ports.reset = Some ("clear", High)
  ; valid = "data_in_valid"
  ; data = "data_in"
  ; pin = "txd"
  ; tied = []
  }
;;

let compile_hobby () =
  let scope = Scope.create ~flatten_design:true () in
  let module C = Circuit.With_interface (Hobby_uart_tx.I) (Hobby_uart_tx.Pin) in
  let circuit = C.create_exn ~name:"hobby_uart_tx" (Uart.pin scope) in
  let%bind.Or_error sim = Bit_sim.create circuit in
  Frame_compiler.compile sim ~ports:hobby_ports
;;

let%expect_test "the hobby uart compiles by its frame, whatever its states" =
  let compiled = compile_hobby () |> ok_exn in
  print_string compiled.firmware.source;
  print_s
    [%message
      (compiled.timing : Frame_compiler.Timing.t)
        (compiled.frame.length : int)
        (Frame_compiler.Frame.runs compiled.frame : (int * Frame_compiler.Symbol.t) list)];
  [%expect
    {|
    ; txd is pin OUT0, data_in comes through the tx fifo
    ; cycles count from the one data_in_valid is taken in
        set p, 8
        set pins, 1     ; the idle level
    idle:
        wait tx         ; until data_in_valid
        pull            ; osr <- data_in
        mov t, now
        add t, 2
        wait t+
        set pins, 0     ; cycles 1-8: 0
        set x, 7        ; loop count
    loop0:
        wait t+
        out pins, 1     ; cycles 9-72: d0-d7
        jmp x--, loop0
        wait t+
        set pins, 1     ; from cycle 73: 1
        jmp idle
    ((compiled.timing
      ((lag 6) (first_take 4) (gap 81) (shortest 81) (settled 81)))
     ("(compiled.frame).length" 81)
     ("Frame_compiler.Frame.runs compiled.frame"
      ((0 (Level true)) (1 (Level false)) (9 (Data 0)) (17 (Data 1))
       (25 (Data 2)) (33 (Data 3)) (41 (Data 4)) (49 (Data 5)) (57 (Data 6))
       (65 (Data 7)) (73 (Level true)))))
    |}]
;;

(* the circuit in Cyclesim, a byte taken in each cycle of [takes] *)
let circuit_pins ~cycles ~takes =
  let trace = ref [] in
  Harness.run
    ~random_initial_state:`All
    ~create:Uart.hierarchical
    (fun (h @ local) ~inputs ~outputs ->
       let outputs = Before_and_after_edge.before_edge outputs in
       inputs.clocking.clear := Bits.vdd;
       Lws.step h;
       inputs.clocking.clear := Bits.gnd;
       for cycle = 0 to cycles - 1 do
         (match List.Assoc.find takes cycle ~equal:Int.equal with
          | Some byte ->
            inputs.data_in <--. byte;
            inputs.data_in_valid := Bits.vdd
          | None -> inputs.data_in_valid := Bits.gnd);
         Lws.step h;
         trace := Bits.to_unsigned_int !(outputs.txd) :: !trace
       done);
  List.rev !trace |> Array.of_list
;;

let engine_pins (firmware : Fsm_compiler.Firmware.t) ~cycles ~takes =
  let words = Asm.Program.words firmware.program |> ok_exn in
  let machine = Machine.create ~config:firmware.config ~program:words |> ok_exn in
  List.folding_map (List.range 0 cycles) ~init:machine ~f:(fun machine cycle ->
    let machine =
      match List.Assoc.find takes cycle ~equal:Int.equal with
      | Some byte -> Machine.write_tx machine byte |> ok_exn
      | None -> machine
    in
    let machine = Machine.step machine ~inputs:0 in
    machine, (machine.pin_out lsr firmware.config.out_base) land 1)
  |> Array.of_list
;;

(* The lag here counts from this harness's clear, not [Timing]'s. *)
let%expect_test "in Cyclesim, the engine's pin is the circuit's a fixed lag later" =
  let compiled = compile_hobby () |> ok_exn in
  let gap = compiled.timing.gap in
  let lags =
    Quickcheck.random_value
      ~seed:(`Deterministic "frame")
      (List.gen_with_length
         20
         (Quickcheck.Generator.list_with_length
            4
            (Quickcheck.Generator.both (Int.gen_incl 0 255) (Int.gen_incl 0 30))))
    |> List.map ~f:(fun bytes ->
      let takes, cycles =
        List.fold_map bytes ~init:20 ~f:(fun at (byte, extra) ->
          at + gap + extra, (at, byte))
        |> Tuple2.swap
      in
      let cycles = cycles + gap in
      let circuit = circuit_pins ~cycles ~takes in
      let engine = engine_pins compiled.firmware ~cycles ~takes in
      (* the lags at which every cycle from the first take on agrees *)
      List.filter (List.range 0 16) ~f:(fun lag ->
        List.for_all
          (List.range 20 (cycles - lag))
          ~f:(fun cycle -> circuit.(cycle) = engine.(cycle + lag))))
    |> List.dedup_and_sort ~compare:[%compare: int list]
  in
  print_s [%message (lags : int list list)];
  [%expect {| (lags ((4))) |}]
;;

(* A transmitter of one-cycle bits for refusals: [k] counts the frame, [sr] shifts the
   byte out from cycle 2, right or [left], and [pin] picks the line from them. *)
let tiny ?(restart = false) ?(left = false) ~pin () =
  let open Signal in
  let clock = input "clock" 1 in
  let clear = input "clear" 1 in
  let valid = input "valid" 1 in
  let data = input "data" 8 in
  let extra = input "extra" 1 in
  let spec = Reg_spec.create ~clock ~clear () in
  let k = wire 4 in
  let idle = k ==:. 0 in
  let take = valid &: (idle |: of_bool restart) in
  let next = mux2 (k ==:. 9) (zero 4) (k +:. 1) in
  k <-- reg spec (mux2 take (one 4) (mux2 idle k next));
  let sr = wire 8 in
  let shifted = if left then sll sr ~by:1 else srl sr ~by:1 in
  sr <-- reg spec (mux2 take data (mux2 (idle |: (k ==:. 1)) sr shifted));
  Circuit.create_exn ~name:"tiny" [ output "pin" (pin ~k ~sr ~extra) ]
;;

let refusal ?restart ?left ~pin () =
  let sim = Bit_sim.create (tiny ?restart ?left ~pin ()) |> ok_exn in
  let ports =
    { Frame_compiler.Ports.reset = Some ("clear", High)
    ; valid = "valid"
    ; data = "data"
    ; pin = "pin"
    ; tied = []
    }
  in
  match Frame_compiler.compile sim ~ports with
  | Ok _ -> print_endline "accepted"
  | Error e -> print_endline (Error.to_string_hum e)
;;

let%expect_test "what is outside the subset is refused by name" =
  let open Signal in
  let line ~k bit = mux2 (k ==:. 0) vdd (mux2 (k ==:. 1) gnd bit) in
  refusal ~pin:(fun ~k ~sr ~extra:_ -> line ~k ~:(sr.:(0))) ();
  refusal ~pin:(fun ~k ~sr ~extra:_ -> line ~k sr.:(0)) ();
  refusal ~left:true ~pin:(fun ~k ~sr ~extra:_ -> line ~k sr.:(7)) ();
  refusal ~pin:(fun ~k ~sr ~extra -> line ~k (sr.:(0) &: extra)) ();
  refusal ~restart:true ~pin:(fun ~k ~sr ~extra:_ -> line ~k sr.:(0)) ();
  [%expect
    {|
    in the first frame: the pin sends bit 0 of the data inverted, at cycle 2
    ("the shortest run, 1 cycles, is too short for the code that sends it"
      "2 of 3 deadline waits may be missed\
     \n 18  wait t+                      phase 2..?  slack ?..-2  MAY MISS\
     \n 21  wait t+                      phase 5..?  slack ?..-5  MAY MISS\
     \na bound of ? means none: the way here has a wait for a pin or a fifo, a capture nothing is assumed about, a period the host loads, or a loop that falls further behind on every pass")
    the pin sends data bit 6 after bit 7: LSB first only
    in the first frame: the pin is unknown at cycle 2: it depends on input extra, which is not reset, valid or data: tie it with -tie extra=VALUE
    in the frame: the pin is unknown at cycle 2: it depends on valid, which it reads while it sends
    |}]
;;
