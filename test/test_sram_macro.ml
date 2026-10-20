open! Core
open! Hardcaml
open Protocol_emulator

(* Cyclesim black-boxes the macro and the test/models SRAM reads neither DLY nor the BIST
   port, so the ties are checked in the verilog: DLY high, BIST idle. *)
let%expect_test "the macro's port map" =
  let module C = Circuit.With_interface (Program_memory.I) (Program_memory.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit = C.create_exn ~name:"sram_top" (Sram_macro.hierarchical scope) in
  Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  |> Rtl.full_hierarchy
  |> Rope.to_string
  |> String.split_lines
  |> List.filter ~f:(String.is_substring ~substring:".A_")
  |> List.iter ~f:(fun line -> print_endline (String.strip line));
  [%expect
    {|
    ( .A_CLK(signal_wire_6),
    .A_MEN(signal_wire_5),
    .A_WEN(signal_wire_4),
    .A_REN(signal_wire_3),
    .A_ADDR(signal_wire_2),
    .A_DIN(signal_wire_1),
    .A_DLY(vdd),
    .A_BM(signal_wire),
    .A_BIST_CLK(gnd),
    .A_BIST_EN(gnd),
    .A_BIST_MEN(gnd),
    .A_BIST_WEN(gnd),
    .A_BIST_REN(gnd),
    .A_BIST_ADDR(signal_const_2),
    .A_BIST_DIN(signal_const),
    .A_BIST_BM(signal_const),
    .A_DOUT(signal_inst[15:0]) );
    |}]
;;
