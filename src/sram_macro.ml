open! Core
open! Hardcaml
open! Signal

let name = "RM_IHPSG13_1P_512x16_c2_bm_bist"

let create (_ : Scope.t) (i : Signal.t Program_memory.I.t) =
  let inst =
    Instantiation.create
      ()
      ~instance:"sram"
      ~name
      ~inputs:
        [ "A_CLK", i.clock
        ; "A_MEN", i.men
        ; "A_WEN", i.wen
        ; "A_REN", i.ren
        ; "A_ADDR", i.addr
        ; "A_DIN", i.din
        ; "A_DLY", vdd
        ; "A_BM", i.bm
        ; "A_BIST_CLK", gnd
        ; "A_BIST_EN", gnd
        ; "A_BIST_MEN", gnd
        ; "A_BIST_WEN", gnd
        ; "A_BIST_REN", gnd
        ; "A_BIST_ADDR", zero Isa.pc_bits
        ; "A_BIST_DIN", zero Isa.word_bits
        ; "A_BIST_BM", zero Isa.word_bits
        ]
      ~outputs:[ "A_DOUT", Isa.word_bits ]
  in
  { Program_memory.O.dout = Instantiation.output inst "A_DOUT" }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (Program_memory.I) (Program_memory.O) in
  H.hierarchical ?instance ~scope ~name:"sram_macro" create i
;;
