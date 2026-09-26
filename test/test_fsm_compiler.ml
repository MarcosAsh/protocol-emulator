open! Core
open! Hardcaml
open Hardcaml_lws
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Uart_tx_fsm.I) (Uart_tx_fsm.O)

let ( <--. ) = Bits.( <--. )

let uart ~clocks_per_bit =
  let module Uart =
    Uart_tx_fsm.Make (struct
      let clocks_per_bit = clocks_per_bit
    end)
  in
  Uart.hierarchical
;;

let circuit ~clocks_per_bit =
  let scope = Scope.create ~flatten_design:true () in
  let module C = Circuit.With_interface (Uart_tx_fsm.I) (Uart_tx_fsm.O) in
  C.create_exn ~name:"uart_tx_fsm" (uart ~clocks_per_bit scope)
;;

let compile ~clocks_per_bit = Fsm_compiler.compile (circuit ~clocks_per_bit)

let%expect_test "the uart state machine compiles to firmware" =
  let firmware = compile ~clocks_per_bit:16 |> ok_exn in
  print_string firmware.source;
  [%expect
    {|
    ; enable_rate counts to 16: the tick is wait t+
    ; txd is pin OUT0
    ; txdata is osr
    ; data_count is x, counting down
        set p, 16
        set pins, 1     ; txd clears to 1
    start:
        wait tx         ; until data_in_valid
        pull            ; txdata <- data_in
        mov t, now      ; restart the tick
        set pins, 0     ; txd <- 0
        add t, p
        set x, 7        ; data_count <- 0, leaving at 7
    data:
        wait t+         ; the tick
        out pins, 1     ; txd <- txdata[0], txdata <- txdata >> 1
        jmp x--, data   ; data_count <- data_count + 1
    stop:
        wait t+         ; the tick
        set pins, 1     ; txd <- 1
    complete:
        wait t+         ; the tick
        jmp start
    |}]
;;

let check_timing (firmware : Fsm_compiler.Firmware.t) =
  let open Or_error.Let_syntax in
  let period = Option.some_if firmware.period_from_host firmware.period in
  let%bind verdict = Analyser.check ?period ~config:firmware.config firmware.program in
  let%map words = Asm.Program.words firmware.program in
  let rows =
    Analyser.analyse ?period ~config:firmware.config firmware.program.instructions
  in
  let kernel =
    Kernel.check ?period ~config:firmware.config ~words (Kernel.Table.of_analyser rows)
  in
  Analyser.Verdict.to_string verdict, kernel
;;

let%expect_test "the analyser and the kernel accept the compiled firmware" =
  let firmware = compile ~clocks_per_bit:16 |> ok_exn in
  print_s [%message (check_timing firmware : (string * unit Or_error.t) Or_error.t)];
  [%expect
    {|
    ("check_timing firmware"
     (Ok ("15 words, 3 deadline waits, worst slack 12" (Ok ()))))
    |}]
;;

(* The circuit sees a byte with [data_in_valid] high for one cycle; the engine sees the
   host write it into the tx fifo before the same edge. *)
let circuit_trace ~clocks_per_bit ~cycles ~arrivals =
  let trace = ref [] in
  Harness.run
    ~random_initial_state:`All
    ~create:(uart ~clocks_per_bit)
    (fun (h @ local) ~inputs ~outputs ->
       let outputs = Before_and_after_edge.after_edge outputs in
       inputs.clocking.clear := Bits.vdd;
       Lws.step h;
       inputs.clocking.clear := Bits.gnd;
       for cycle = 0 to cycles - 1 do
         (match List.Assoc.find arrivals cycle ~equal:Int.equal with
          | Some byte ->
            inputs.data_in <--. byte;
            inputs.data_in_valid := Bits.vdd
          | None -> inputs.data_in_valid := Bits.gnd);
         Lws.step h;
         trace := Bits.to_unsigned_int !(outputs.txd) :: !trace
       done);
  List.rev !trace
;;

let engine_trace (firmware : Fsm_compiler.Firmware.t) ~cycles ~arrivals =
  let words = Asm.Program.words firmware.program |> ok_exn in
  let machine = Machine.create ~config:firmware.config ~program:words |> ok_exn in
  let machine =
    if firmware.period_from_host
    then Machine.write_tx machine firmware.period |> ok_exn
    else machine
  in
  List.folding_map (List.range 0 cycles) ~init:machine ~f:(fun machine cycle ->
    let machine =
      List.filter arrivals ~f:(fun (at, _) -> at = cycle)
      |> List.fold ~init:machine ~f:(fun machine (_, byte) ->
        Machine.write_tx machine byte |> ok_exn)
    in
    let machine = Machine.step machine ~inputs:0 in
    machine, (machine.pin_out lsr Isa.first_output_pin) land 1)
;;

(* The cycles where a high line goes low. *)
let falling_edges trace =
  List.zip_exn (List.drop_last_exn (List.hd_exn trace :: trace)) trace
  |> List.filter_mapi ~f:(fun i (was, level) -> Option.some_if (was = 1 && level = 0) i)
;;

(* How many cycles the engine's pin trails the circuit's, and the first cycle after the
   prologue where it then differs. *)
let compare_traces ~clocks_per_bit ~cycles ~arrivals =
  let firmware = compile ~clocks_per_bit |> ok_exn in
  let circuit = circuit_trace ~clocks_per_bit ~cycles ~arrivals in
  let engine = engine_trace firmware ~cycles ~arrivals in
  let lag = List.hd_exn (falling_edges engine) - List.hd_exn (falling_edges circuit) in
  (* the engine's pin is low until its prologue sets it *)
  let prologue = fst (List.findi_exn engine ~f:(fun _ level -> level = 1)) in
  let mismatch =
    List.zip_exn (List.drop engine lag) (List.take circuit (cycles - lag))
    |> List.findi ~f:(fun i (e, c) -> i + lag >= prologue && e <> c)
    |> Option.map ~f:fst
  in
  lag, mismatch, circuit, engine
;;

let%expect_test "the engine's pin is the circuit's, a fixed few cycles later" =
  let clocks_per_bit = 16 in
  let arrivals = [ 3, 0x55; 200, 0xa3; 390, 0x00; 600, 0xff ] in
  let cycles = 800 in
  let lag, mismatch, circuit, engine = compare_traces ~clocks_per_bit ~cycles ~arrivals in
  print_s
    [%message
      (lag : int)
        (mismatch : int option)
        (Protocol_models.decode_uart circuit ~period:clocks_per_bit : int list)
        (Protocol_models.decode_uart engine ~period:clocks_per_bit : int list)];
  [%expect
    {|
    ((lag 3) (mismatch ())
     ("Protocol_models.decode_uart circuit ~period:clocks_per_bit"
      (85 163 0 255))
     ("Protocol_models.decode_uart engine ~period:clocks_per_bit" (85 163 0 255)))
    |}]
;;

let%expect_test "equal every cycle for random bytes at random times" =
  let clocks_per_bit = 8 in
  let frame = 10 * clocks_per_bit in
  Quickcheck.test
    ~trials:50
    (Quickcheck.Generator.list_non_empty
       (Quickcheck.Generator.both (Int.gen_incl 0 255) (Int.gen_incl 12 40)))
    ~f:(fun bytes ->
      let arrivals, cycles =
        List.fold_map bytes ~init:3 ~f:(fun at (byte, gap) ->
          at + frame + gap, (at, byte))
        |> Tuple2.swap
      in
      let cycles = cycles + frame in
      let lag, mismatch, _, _ = compare_traces ~clocks_per_bit ~cycles ~arrivals in
      [%test_result: int * int option] (lag, mismatch) ~expect:(3, None));
  [%expect {| |}]
;;

let%expect_test "back to back, every frame is the circuit's and the gap is longer" =
  let clocks_per_bit = 16 in
  let bytes = [ 0x55; 0xa3; 0x0f ] in
  let cycles = 600 in
  let firmware = compile ~clocks_per_bit |> ok_exn in
  (* the circuit keeps [data_in_valid] high, so it takes the next byte at once *)
  let circuit =
    let trace = ref [] in
    Harness.run ~create:(uart ~clocks_per_bit) (fun (h @ local) ~inputs ~outputs ->
      let outputs = Before_and_after_edge.after_edge outputs in
      inputs.clocking.clear := Bits.vdd;
      Lws.step h;
      inputs.clocking.clear := Bits.gnd;
      let pending = ref bytes in
      let last_take = ref Int.min_value in
      for cycle = 0 to cycles - 1 do
        (match !pending with
         | byte :: _ when cycle >= 3 ->
           inputs.data_in <--. byte;
           inputs.data_in_valid := Bits.vdd
         | _ -> inputs.data_in_valid := Bits.gnd);
        let was = Bits.to_unsigned_int !(outputs.txd) in
        Lws.step h;
        let level = Bits.to_unsigned_int !(outputs.txd) in
        (* a start bit, not a data bit, takes the byte *)
        if was = 1 && level = 0 && cycle >= !last_take + (10 * clocks_per_bit)
        then (
          last_take := cycle;
          pending := List.tl !pending |> Option.value ~default:[]);
        trace := level :: !trace
      done);
    List.rev !trace
  in
  let engine =
    engine_trace firmware ~cycles ~arrivals:(List.map bytes ~f:(fun b -> 3, b))
  in
  let frame = 10 * clocks_per_bit in
  (* a frame starts at a falling edge at least a frame after the last start *)
  let starts trace =
    List.fold (falling_edges trace) ~init:[] ~f:(fun starts edge ->
      match starts with
      | last :: _ when edge < last + frame -> starts
      | _ -> edge :: starts)
    |> List.rev
  in
  let bits trace =
    let levels = Array.of_list trace in
    List.map (starts trace) ~f:(fun pos -> Array.sub levels ~pos ~len:frame)
  in
  print_s
    [%message
      ""
        ~frames_equal:([%equal: int array list] (bits circuit) (bits engine) : bool)
        (starts circuit : int list)
        (starts engine : int list)];
  [%expect
    {|
    ((frames_equal true) ("starts circuit" (3 164 325))
     ("starts engine" (6 171 336)))
    |}]
;;

let%expect_test "115200 baud from 50 MHz, the period too long to set comes from the host" =
  let clocks_per_bit = 434 in
  let firmware = compile ~clocks_per_bit |> ok_exn in
  print_string
    (String.split_lines firmware.source
     |> List.drop_while ~f:(String.is_prefix ~prefix:";")
     |> List.take_while ~f:(Fn.non (String.equal "start:"))
     |> String.concat_lines);
  let arrivals = [ 20, 0x55; 5000, 0xa3 ] in
  let lag, mismatch, _, engine =
    compare_traces ~clocks_per_bit ~cycles:10_000 ~arrivals
  in
  print_s
    [%message
      (check_timing firmware : (string * unit Or_error.t) Or_error.t)
        (lag : int)
        (mismatch : int option)
        (Protocol_models.decode_uart engine ~period:clocks_per_bit : int list)];
  [%expect
    {|
        wait tx
        pull            ; the host sends the tick, 434
        mov p, osr
        set pins, 1     ; txd clears to 1
    (("check_timing firmware"
      (Ok ("17 words, 3 deadline waits, worst slack 430" (Ok ()))))
     (lag 3) (mismatch ())
     ("Protocol_models.decode_uart engine ~period:clocks_per_bit" (85 163)))
    |}]
;;

let%expect_test "a state that does not fit in the tick is refused" =
  List.iter [ 3; 4 ] ~f:(fun clocks_per_bit ->
    let compiled = compile ~clocks_per_bit |> Or_error.map ~f:(fun _ -> "compiled") in
    print_s [%message (clocks_per_bit : int) (compiled : string Or_error.t)]);
  [%expect
    {|
    ((clocks_per_bit 3)
     (compiled
      (Error
       ("state Start needs 4 cycles, tick is 3"
        "state Data needs 4 cycles, tick is 3"))))
    ((clocks_per_bit 4) (compiled (Ok compiled)))
    |}]
;;

(* The compiler counts the cycles itself; the analyser agrees where the tick runs out. *)
let%expect_test "the analyser draws the same line" =
  let firmware = compile ~clocks_per_bit:16 |> ok_exn in
  List.iter [ 3; 4 ] ~f:(fun period ->
    let source =
      String.substr_replace_first
        firmware.source
        ~pattern:"set p, 16"
        ~with_:[%string "set p, %{period#Int}"]
    in
    let program = Asm.assemble source |> ok_exn in
    let verdict =
      Analyser.check ~config:firmware.config program
      |> Or_error.map ~f:Analyser.Verdict.to_string
    in
    print_s [%message (period : int) (verdict : string Or_error.t)]);
  [%expect
    {|
    ((period 3)
     (verdict
      (Error
        "3 of 3 deadline waits may be missed\
       \n  8  wait t+                      phase 1..?  slack ?..-1  MAY MISS\
       \n 11  wait t+                      phase 2..?  slack ?..-2  MAY MISS\
       \n 13  wait t+                      phase 1..?  slack ?..-1  MAY MISS\
       \na bound of ? means none: the way here has a wait for a pin or a fifo, a capture nothing is assumed about, a period the host loads, or a loop that falls further behind on every pass")))
    ((period 4) (verdict (Ok "15 words, 3 deadline waits, worst slack 0")))
    |}]
;;

let%expect_test "the engine runs the compiled firmware as the model does" =
  let firmware = compile ~clocks_per_bit:16 |> ok_exn in
  let machine =
    Lockstep.lockstep
      ~cycles:400
      ~preload:[ 0x55; 0xa3 ]
      ~config:firmware.config
      ~program:(Asm.Program.words firmware.program |> ok_exn)
      ~inputs:(fun _ -> 0)
      ()
  in
  print_s [%message (machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ("lockstep held" (cycles 400))
    (machine.fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    |}]
;;

(* A toggle is ordinary Hardcaml, but not yet an instruction the compiler knows. *)
module Blink = struct
  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; go : 'a
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = { led : 'a } [@@deriving hardcaml]
  end

  module State = struct
    type t =
      | Idle
      | Blink
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  let create scope (i : _ I.t) =
    let open Signal in
    let spec = Clocking.to_spec i.clocking in
    let%hw.Always.State_machine sm = Always.State_machine.create (module State) spec in
    let%hw_var led = Always.Variable.reg spec ~width:1 in
    let%hw_var count = Always.Variable.reg spec ~width:3 in
    let%hw tick = count.value +:. 1 ==:. 5 in
    Always.(
      compile
        [ count <-- count.value +:. 1
        ; when_ tick [ count <--. 0 ]
        ; sm.switch
            [ Idle, [ count <--. 0; when_ i.go [ led <-- vdd; sm.set_next Blink ] ]
            ; Blink, [ when_ tick [ led <-- ~:(led.value) ] ]
            ]
        ]);
    { O.led = led.value }
  ;;
end

let%expect_test "an assignment outside the subset is refused where it is" =
  let module C = Circuit.With_interface (Blink.I) (Blink.O) in
  let scope = Scope.create ~flatten_design:true () in
  let circuit = C.create_exn ~name:"blink" (Blink.create scope) in
  print_s
    [%message
      (Fsm_compiler.compile circuit |> Or_error.map ~f:(fun _ -> ()) : unit Or_error.t)];
  [%expect
    {|
    ("(Fsm_compiler.compile circuit) |> (Or_error.map ~f:(fun _ -> ()))"
     (Error "state Blink: led <- ~led is outside the subset"))
    |}]
;;
