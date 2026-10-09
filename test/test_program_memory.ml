open! Core
open! Hardcaml
open Hardcaml_lws
open Protocol_emulator

module Harness =
  Hardcaml_test_harness.Lws_harness.Make (Program_memory.I) (Program_memory.O)

let ( <--. ) = Bits.( <--. )

(* as the macro: a read or a write needs [men] beside its own enable, and dout holds
   between reads *)
let%expect_test "dout moves only on a read with the memory enabled" =
  Harness.run
    ~random_initial_state:`All
    ~create:Program_memory.hierarchical
    (fun (h @ local) ~inputs:i ~outputs ->
       let dout = (Before_and_after_edge.after_edge outputs).dout in
       let access ?(print = true) ?(data = 0) ~men ~wen ~ren addr =
         i.men := Bits.of_bool men;
         i.wen := Bits.of_bool wen;
         i.ren := Bits.of_bool ren;
         i.addr <--. addr;
         i.din <--. data;
         i.bm <--. 0xffff;
         Lws.cycle h;
         if print
         then
           print_s
             [%message
               ""
                 (men : bool)
                 (wen : bool)
                 (ren : bool)
                 (addr : int)
                 ~dout:(!dout : Bits.Hex.t)]
       in
       access ~print:false ~men:true ~wen:true ~ren:false ~data:0x1234 1;
       access ~print:false ~men:true ~wen:true ~ren:false ~data:0xabcd 2;
       access ~men:true ~wen:false ~ren:true 1;
       access ~men:true ~wen:false ~ren:false 2;
       access ~men:false ~wen:false ~ren:true 2;
       access ~men:true ~wen:false ~ren:true 2;
       access ~men:false ~wen:true ~ren:false ~data:0x5555 2;
       access ~men:true ~wen:false ~ren:true 2;
       ());
  [%expect
    {|
    ((men true) (wen false) (ren true) (addr 1) (dout 16'h1234))
    ((men true) (wen false) (ren false) (addr 2) (dout 16'h1234))
    ((men false) (wen false) (ren true) (addr 2) (dout 16'h1234))
    ((men true) (wen false) (ren true) (addr 2) (dout 16'habcd))
    ((men false) (wen true) (ren false) (addr 2) (dout 16'habcd))
    ((men true) (wen false) (ren true) (addr 2) (dout 16'habcd))
    |}]
;;
