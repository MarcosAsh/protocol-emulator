open! Core
open! Hardcaml
open Protocol_emulator
open Firmware
open Protocol_models
module Harness = Hardcaml_test_harness.Lws_harness.Make (Top.I) (Top.O)
module Reg = Host_port.Reg

let%expect_test "the host loads and runs the uart transmitter over spi" =
  let period = 16 in
  Harness.run
    ~create:(Top.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs ~outputs ->
       let cycle ?n () = Hardcaml_lws.Lws.cycle ?n h in
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
         miso := Bits.select !(o.uo_out) ~high:0 ~low:0
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
      ((0 15) (1 16) (0 16) (1 16) (0 16) (1 16) (0 16) (1 16) (0 16) (1 22)
       (0 16) (1 32) (0 48) (1 16) (0 16) (1 107)))
     ("decode_uart levels ~period" (85 163)) (status (0)))
    |}]
;;
