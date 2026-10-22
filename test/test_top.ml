open! Core
open! Hardcaml
open Hardcaml_lws
open! Hardcaml_waveterm
open Protocol_emulator
open Firmware
open Protocol_models
module Harness = Hardcaml_test_harness.Lws_harness.Make (Top.I) (Top.O)
module Reg = Host_port.Reg

(* Cyclesim does not model the asynchronous reset, so registers start at zero, as [rst_n]
   low leaves the reset synchroniser, and only the memories start random. *)

let%expect_test "the host loads and runs the uart transmitter over spi" =
  let period = 16 in
  Harness.run
    ~random_initial_state:`Mems
    ~create:(Top.hierarchical ~memory:Flops ~engines:1)
    (fun (h @ local) ~inputs ~outputs ->
       let cycle ?n () = Lws.step ?n h in
       let o = Before_and_after_edge.after_edge outputs in
       let tx_levels = ref [] in
       let sck = ref Bits.gnd
       and mosi = ref Bits.gnd
       and cs_n = ref Bits.vdd
       and miso = ref Bits.gnd in
       let watch n =
         inputs.ui_in := Bits.concat_msb [ Bits.zero 5; !cs_n; !mosi; !sck ];
         for _ = 1 to n do
           cycle ();
           tx_levels := ((Bits.to_unsigned_int !(o.uo_out) lsr 1) land 1) :: !tx_levels
         done;
         miso := Bits.lsb !(o.uo_out)
       in
       inputs.rst_n := Bits.gnd;
       inputs.ena := Bits.vdd;
       cycle ~n:3 ();
       inputs.rst_n := Bits.vdd;
       cycle ~n:4 ();
       let m = Spi_master.create ~sck ~mosi ~cs_n ~miso ~half:4 in
       let config = Engine.Config.of_program_config Program_config.default in
       Engine.Config.to_list (Engine.Config.map config ~f:Bits.to_unsigned_int)
       |> List.iter2_exn Reg.configs ~f:(fun reg v -> Spi_master.write m ~watch reg [ v ]);
       Spi_master.write m ~watch Reg.program_addr [ 0 ];
       Spi_master.write m ~watch Reg.program (assemble (Uart.tx ~period));
       Spi_certify.certify
         m
         ~watch
         ~assumptions:System_lockstep.Assumptions.none
         ~config:Program_config.default
         (assemble (Uart.tx ~period));
       Spi_master.write m ~watch Reg.tx [ 0x55; 0xa3 ];
       Spi_master.write m ~watch Reg.control [ 1 ];
       tx_levels := [];
       watch 400;
       let levels = List.rev !tx_levels in
       let status = Spi_master.read m ~watch Reg.status ~count:1 in
       print_s
         [%message
           (runs levels : (int * int) list)
             (decode_uart levels ~period : int list)
             (status : int list)]);
  [%expect
    {|
    (("runs levels"
      ((0 16) (1 16) (0 16) (1 16) (0 16) (1 16) (0 16) (1 16) (0 16) (1 22)
       (0 16) (1 32) (0 48) (1 16) (0 16) (1 106)))
     ("decode_uart levels ~period" (85 163)) (status (0)))
    |}]
;;

(* self-test: a transmitter on engine 0 and a receiver on engine 1 over a wire *)
let%expect_test "two engines talk over a wire and the host reads the result" =
  let period = 16 in
  let wire = Isa.num_pins in
  Harness.run
    ~random_initial_state:`Mems
    ~create:(Top.hierarchical ~memory:Flops ~engines:2)
    (fun (h @ local) ~inputs ~outputs ->
       let cycle ?n () = Lws.step ?n h in
       let o = Before_and_after_edge.after_edge outputs in
       let sck = ref Bits.gnd
       and mosi = ref Bits.gnd
       and cs_n = ref Bits.vdd
       and miso = ref Bits.gnd in
       let watch n =
         inputs.ui_in := Bits.concat_msb [ Bits.zero 5; !cs_n; !mosi; !sck ];
         cycle ~n ();
         miso := Bits.lsb !(o.uo_out)
       in
       inputs.rst_n := Bits.gnd;
       inputs.ena := Bits.vdd;
       cycle ~n:3 ();
       inputs.rst_n := Bits.vdd;
       cycle ~n:4 ();
       let m = Spi_master.create ~sck ~mosi ~cs_n ~miso ~half:4 in
       let load engine ~config ~program ~(assumptions : System_lockstep.Assumptions.t) =
         Spi_master.write m ~watch Reg.select [ engine ];
         Engine.Config.of_program_config config
         |> Engine.Config.map ~f:Bits.to_unsigned_int
         |> Engine.Config.to_list
         |> List.iter2_exn Reg.configs ~f:(fun reg v ->
           Spi_master.write m ~watch reg [ v ]);
         Spi_master.write m ~watch Reg.program_addr [ 0 ];
         Spi_master.write m ~watch Reg.program (assemble program);
         Spi_certify.certify m ~watch ~assumptions ~config (assemble program)
       in
       let rx_config =
         { Uart.rx_config with in_base = wire; jmp_pin = wire; capture_pin = wire }
       in
       load
         1
         ~config:rx_config
         ~program:(Uart.rx_on ~pin:wire ~period)
         ~assumptions:{ System_lockstep.Assumptions.none with single_capture_edge = true };
       load
         0
         ~config:{ Program_config.default with set_base = wire; out_base = wire }
         ~program:(Uart.tx ~period)
         ~assumptions:System_lockstep.Assumptions.none;
       Spi_master.write m ~watch Reg.select [ 1 ];
       Spi_master.write m ~watch Reg.control [ 1 ];
       Spi_master.write m ~watch Reg.select [ 0 ];
       Spi_master.write m ~watch Reg.tx [ 0x55; 0xa3 ];
       Spi_master.write m ~watch Reg.control [ 1 ];
       watch 400;
       let sender = Spi_master.read m ~watch Reg.status ~count:1 in
       Spi_master.write m ~watch Reg.select [ 1 ];
       let receiver = Spi_master.read m ~watch Reg.status ~count:1 in
       let received = Spi_master.read m ~watch Reg.rx ~count:2 in
       print_s
         [%message
           (sender : int list)
             (receiver : int list)
             (received : int list)
             ~pins:(Bits.to_unsigned_int !(o.uo_out) lsr 1 : int)]);
  [%expect {| ((sender (0)) (receiver (2048)) (received (85 163)) (pins 0)) |}]
;;

(* a core echoes its input pins to the outputs, each pin through the two synchroniser
   flops on the way in; then [rst_n] falls again and the chip comes back halted. Cyclesim
   has no asynchronous reset, so [Cyclesim.reset] stands in for its fall. *)
let%expect_test "every input pin reaches a core, and a second reset clears the chip" =
  Harness.run_advanced
    ~random_initial_state:`Mems
    ~create:(Top.hierarchical ~memory:Flops ~engines:2)
    (fun (h @ local) context ->
       let sim =
         match Lws_context.simulator_specific context with
         | Cyclesim sim -> Lws_context.Simulator_specific.Cyclesim.simulator sim
         | Evsim _ | Cosim -> assert false
       in
       let inputs = context.inputs in
       let cycle ?n () = Lws.step ?n h in
       let o = Before_and_after_edge.after_edge context.outputs in
       let pins = ref 0
       and sck = ref Bits.gnd
       and mosi = ref Bits.gnd
       and cs_n = ref Bits.vdd
       and miso = ref Bits.gnd in
       let watch n =
         inputs.ui_in
         := Bits.concat_msb
              [ Bits.of_unsigned_int ~width:5 (!pins land 0x1f); !cs_n; !mosi; !sck ];
         inputs.uio_in := Bits.of_unsigned_int ~width:8 (!pins lsr 5);
         cycle ~n ();
         miso := Bits.lsb !(o.uo_out)
       in
       let reset () =
         inputs.rst_n := Bits.gnd;
         Cyclesim.reset sim;
         cycle ~n:3 ();
         inputs.rst_n := Bits.vdd;
         cycle ~n:4 ()
       in
       inputs.ena := Bits.vdd;
       reset ();
       let m = Spi_master.create ~sck ~mosi ~cs_n ~miso ~half:4 in
       (* from pin [in_base] to the outputs from pin 5, which are [uo_out] from bit 1 *)
       let echo ~in_base ~count =
         Spi_master.write m ~watch Reg.control [ 4 ];
         let config =
           { Program_config.default with
             in_base
           ; in_count = count
           ; out_base = 5
           ; out_count = count
           }
         in
         Engine.Config.of_program_config config
         |> Engine.Config.map ~f:Bits.to_unsigned_int
         |> Engine.Config.to_list
         |> List.iter2_exn Reg.configs ~f:(fun reg v ->
           Spi_master.write m ~watch reg [ v ]);
         let program = assemble {|
loop:
    mov pins, pins
    jmp loop
|} in
         Spi_master.write m ~watch Reg.program_addr [ 0 ];
         Spi_master.write m ~watch Reg.program program;
         Spi_certify.certify
           m
           ~watch
           ~assumptions:System_lockstep.Assumptions.none
           ~config
           program;
         Spi_master.write m ~watch Reg.control [ 1 ];
         (* pins 0 to 4 are [ui_in]'s top five bits, pins 12 to 19 [uio_in] *)
         let input k = if in_base + k < 5 then in_base + k else in_base + k - 7 in
         List.init count ~f:(fun k ->
           pins := 1 lsl input k;
           watch 16;
           pins := 0;
           let out = (Bits.to_unsigned_int !(o.uo_out) lsr 1) land ((1 lsl count) - 1) in
           watch 16;
           out)
         [@nontail]
       in
       let ui_in = echo ~in_base:0 ~count:5 in
       let uio_in =
         echo ~in_base:12 ~count:7 @ [ List.last_exn (echo ~in_base:13 ~count:7) ]
       in
       reset ();
       let status = Spi_master.read m ~watch Reg.status ~count:1 in
       let pc = Spi_master.read m ~watch Reg.pc ~count:1 in
       print_s
         [%message
           (ui_in : int list) (uio_in : int list) (status : int list) (pc : int list)]);
  [%expect
    {| ((ui_in (1 2 4 8 16)) (uio_in (1 2 4 8 16 32 64 64)) (status (1)) (pc (0))) |}]
;;

(* The frame receiver listens on the pin the host names: a two-byte frame on an input pin
   lands as one word, and on pins 5 to 11, the outputs, nothing comes in and it stays
   armed. *)
let%expect_test "the frame receiver takes the pin the host names" =
  let random = Random.State.make [| 7 |] in
  let samples =
    Manchester_line.(
      transitions ~random ~ppm:0. ~jitter:0. (bits_of_bytes (preamble @ [ 0x12; 0x34 ]))
      |> sample ~random ~per_bit:8 ~per_cycle:2)
  in
  Harness.run
    ~random_initial_state:`Mems
    ~create:(Top.hierarchical ~memory:Flops ~engines:1)
    (fun (h @ local) ~inputs ~outputs ->
       let cycle ?n () = Lws.step ?n h in
       let o = Before_and_after_edge.after_edge outputs in
       let pins = ref 0
       and sck = ref Bits.gnd
       and mosi = ref Bits.gnd
       and cs_n = ref Bits.vdd
       and miso = ref Bits.gnd in
       let drive () =
         inputs.ui_in
         := Bits.concat_msb
              [ Bits.of_unsigned_int ~width:5 (!pins land 0x1f); !cs_n; !mosi; !sck ];
         inputs.uio_in := Bits.of_unsigned_int ~width:8 (!pins lsr 12)
       in
       let watch n =
         drive ();
         cycle ~n ();
         miso := Bits.lsb !(o.uo_out)
       in
       inputs.rst_n := Bits.gnd;
       inputs.ena := Bits.vdd;
       cycle ~n:3 ();
       inputs.rst_n := Bits.vdd;
       cycle ~n:4 ();
       let m = Spi_master.create ~sck ~mosi ~cs_n ~miso ~half:4 in
       let frames =
         List.init Isa.num_pins ~f:(fun pin ->
           Spi_master.write m ~watch Reg.frame_control [ (pin lsl 2) lor 1 ];
           (* the line on the named pin, or on pin 0 for an output *)
           let line = if pin >= 5 && pin < 12 then 0 else pin in
           List.iter samples ~f:(fun sample ->
             pins := List.hd_exn sample lsl line;
             drive ();
             cycle ());
           pins := 0;
           let status =
             List.hd_exn (Spi_master.read m ~watch Reg.frame_status ~count:1)
           in
           if status land 0x400 <> 0
           then `Words (status land 0x3ff)
           else if status land 0x8000 <> 0
           then `Armed
           else `Status status)
       in
       print_s
         [%message (frames : [ `Words of int | `Armed | `Status of Int.Hex.t ] list)]);
  [%expect {|
    (frames
     ((Words 1) (Words 1) (Words 1) (Words 1) (Words 1) Armed Armed Armed Armed
      Armed Armed Armed (Words 1) (Words 1) (Words 1) (Words 1) (Words 1)
      (Words 1) (Words 1) (Words 1)))
    |}]
;;

let%expect_test "waveform of reset and the first command" =
  let display_rules =
    [ Display_rule.port_name_is "rst_n" ~wave_format:Bit
    ; Display_rule.port_name_is "top$reset_done" ~wave_format:Bit
    ; Display_rule.port_name_is "ui_in" ~wave_format:Unsigned_int
    ; Display_rule.port_name_is
        "top$host_port$sm"
        ~wave_format:(Index Host_port.State.names)
    ; Display_rule.port_name_is "top$host_port$cmd" ~wave_format:Unsigned_int
    ; Display_rule.port_name_is "top$engines$engine_0$halted" ~wave_format:Bit
    ]
  in
  Harness.run
    ~create:(Top.hierarchical ~memory:Flops ~engines:1)
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:30
        ~display_width:98
        ~wave_width:(-1)
        waves)
    (fun (h @ local) ~inputs ~outputs ->
      let cycle ?n () = Lws.step ?n h in
      let o = Before_and_after_edge.after_edge outputs in
      let sck = ref Bits.gnd
      and mosi = ref Bits.gnd
      and cs_n = ref Bits.vdd
      and miso = ref Bits.gnd in
      let watch n =
        inputs.ui_in := Bits.concat_msb [ Bits.zero 5; !cs_n; !mosi; !sck ];
        cycle ~n ();
        miso := Bits.lsb !(o.uo_out)
      in
      inputs.rst_n := Bits.gnd;
      inputs.ena := Bits.vdd;
      cycle ~n:3 ();
      inputs.rst_n := Bits.vdd;
      cycle ~n:4 ();
      let m = Spi_master.create ~sck ~mosi ~cs_n ~miso ~half:1 in
      Spi_master.write m ~watch Reg.control [ 1 ];
      watch 4;
      ());
  [%expect
    {|
    ┌Signals─────────────────────┐┌Waves─────────────────────────────────────────────────────────────┐
    │rst_n                       ││   ┌───────────────────────────────────────────────────────────── │
    │                            ││───┘                                                              │
    │top$reset_done              ││  ┌────────────────────────────────────────────────────────────── │
    │                            ││──┘                                                               │
    │                            ││────────┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬─────── │
    │ui_in                       ││ 0      ││││││││││││││││││││││││││││││││││││││││││││││││││6       │
    │                            ││────────┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴─────── │
    │                            ││───────────────────────────┬───────────────┬───────────────┬───── │
    │top$host_port$sm            ││ C                         │H              │L              │H     │
    │                            ││───────────────────────────┴───────────────┴───────────────┴───── │
    │                            ││───────────────────────────┬───────────────────────────────────── │
    │top$host_port$cmd           ││ 0                         │128                                   │
    │                            ││───────────────────────────┴───────────────────────────────────── │
    │top$engines$engine_0$halted ││ ┌─────────────────────────────────────────────────────────────── │
    │                            ││─┘                                                                │
    └────────────────────────────┘└──────────────────────────────────────────────────────────────────┘
    |}]
;;

let%expect_test "the chip's clock pins" =
  let module C = Circuit.With_interface (Top.I) (Top.O) in
  let scope = Scope.create ~flatten_design:true () in
  let circuit =
    C.create_exn
      ~name:"protocol_emulator"
      (Top.hierarchical ~memory:Ihp_sram ~engines:2 scope)
  in
  Design_rule_checks.verify_clock_pins circuit ~expected_clock_pins:[ "clk" ]
;;

(* [Circuit_utilization] raises on the host port's [cases], so the core alone is sized. *)
let%expect_test "the core's area" =
  let module C = Circuit.With_interface (Engine.I) (Engine.O) in
  let scope = Scope.create ~flatten_design:true () in
  let circuit =
    C.create_exn ~name:"engine" (Engine.hierarchical ~memory:Ihp_sram scope)
  in
  print_s [%message (Circuit_utilization.create circuit : Circuit_utilization.t)];
  [%expect
    {|
    ("Circuit_utilization.create circuit"
     ((name engine) (adders ((count 20) (total_bits 231) (max_instance_bits 24)))
      (subtractors ((count 15) (total_bits 208) (max_instance_bits 24)))
      (and_gates ((count 262) (total_bits 1244)))
      (or_gates ((count 51) (total_bits 351)))
      (xor_gates ((count 19) (total_bits 149)))
      (not_gates ((count 93) (total_bits 597)))
      (equals ((count 123) (total_bits 123) (max_instance_bits 1)))
      (comparators ((count 23) (total_bits 23) (max_instance_bits 1)))
      (multiplexers
       ((count 397) (total_bits 15326)
        (multiplexers
         (((number_of_data_elements 2) (max_instance_bits 64) (total_bits 12566)
           (count 360))
          ((number_of_data_elements 3) (max_instance_bits 72) (total_bits 336)
           (count 6))
          ((number_of_data_elements 4) (max_instance_bits 20) (total_bits 36)
           (count 4))
          ((number_of_data_elements 5) (max_instance_bits 5) (total_bits 80)
           (count 1))
          ((number_of_data_elements 8) (max_instance_bits 224) (total_bits 1816)
           (count 14))
          ((number_of_data_elements 12) (max_instance_bits 12) (total_bits 12)
           (count 1))
          ((number_of_data_elements 16) (max_instance_bits 16) (total_bits 192)
           (count 1))
          ((number_of_data_elements 28) (max_instance_bits 28) (total_bits 224)
           (count 8))
          ((number_of_data_elements 32) (max_instance_bits 32) (total_bits 64)
           (count 2))))))
      (registers ((count 97) (total_bits 757)))
      (memories
       ((count 2) (total_bits 512)
        (memories (((data_width 16) (depth 16) (total_bits 256) (count 2))))))
      (constants ((count 420) (total_bits 3593)))
      (wires ((count 222) (total_bits 1533)))
      (concatenation ((count 246) (total_bits 5496)))
      (part_selects ((count 970) (total_bits 4952)))
      (instantiations ((Instantiation RM_IHPSG13_1P_512x16_c2_bm_bist)))))
    |}]
;;
