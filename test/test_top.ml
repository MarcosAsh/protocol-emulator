open! Core
open! Hardcaml
open Hardcaml_lws
open! Hardcaml_waveterm
open Protocol_emulator
open Firmware
open Protocol_models
module Harness = Hardcaml_test_harness.Lws_harness.Make (Top.I) (Top.O)
module Reg = Host_port.Reg

let%expect_test "the host loads and runs the uart transmitter over spi" =
  let period = 16 in
  Harness.run
    ~random_initial_state:`All
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
       |> List.iteri ~f:(fun n v -> Spi_master.write m ~watch (Reg.config + n) [ v ]);
       Spi_master.write m ~watch Reg.program_addr [ 0 ];
       Spi_master.write m ~watch Reg.program (assemble (uart_tx ~period));
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

let%expect_test "waveform of reset and the first command" =
  let display_rules =
    [ Display_rule.port_name_is "rst_n" ~wave_format:Bit
    ; Display_rule.port_name_is "top$reset_done" ~wave_format:Bit
    ; Display_rule.port_name_is "ui_in" ~wave_format:Unsigned_int
    ; Display_rule.port_name_is
        "top$host_port$sm"
        ~wave_format:(Index Host_port.State.names)
    ; Display_rule.port_name_is "top$host_port$cmd" ~wave_format:Unsigned_int
    ; Display_rule.port_name_is "top$engine_0$halted" ~wave_format:Bit
    ]
  in
  Harness.run
    ~create:(Top.hierarchical ~memory:Flops ~engines:1)
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:22
        ~display_width:90
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
    ┌Signals─────────────┐┌Waves─────────────────────────────────────────────────────────────┐
    │rst_n               ││   ┌───────────────────────────────────────────────────────────── │
    │                    ││───┘                                                              │
    │top$reset_done      ││  ┌────────────────────────────────────────────────────────────── │
    │                    ││──┘                                                               │
    │                    ││────────┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬─────── │
    │ui_in               ││ 0      ││││││││││││││││││││││││││││││││││││││││││││││││││6       │
    │                    ││────────┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴─────── │
    │                    ││───────────────────────────┬───────────────┬───────────────┬───── │
    │top$host_port$sm    ││ C                         │H              │L              │H     │
    │                    ││───────────────────────────┴───────────────┴───────────────┴───── │
    │                    ││───────────────────────────┬───────────────────────────────────── │
    │top$host_port$cmd   ││ 0                         │128                                   │
    │                    ││───────────────────────────┴───────────────────────────────────── │
    │top$engine_0$halted ││ ┌──────────────────────────────────────────────────────────┐     │
    │                    ││─┘                                                          └──── │
    └────────────────────┘└──────────────────────────────────────────────────────────────────┘
    |}]
;;
