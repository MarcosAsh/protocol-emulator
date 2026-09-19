open! Core
open! Hardcaml
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Host_spi.I) (Host_spi.O)

let ( <--. ) = Bits.( <--. )

let%expect_test "bytes cross in both directions" =
  let half = 4 in
  Harness.run ~create:Host_spi.hierarchical (fun (h @ local) ~inputs ~outputs ->
    let cycle ?n () = Hardcaml_lws.Lws.cycle ?n h in
    let outputs = Before_and_after_edge.after_edge outputs in
    let received = ref [] in
    let watch n =
      for _ = 1 to n do
        cycle ();
        if Bits.to_bool !(outputs.rx_valid)
        then received := Bits.to_unsigned_int !(outputs.rx_byte) :: !received
      done
    in
    inputs.clocking.clear := Bits.vdd;
    inputs.cs_n := Bits.vdd;
    cycle ();
    inputs.clocking.clear := Bits.gnd;
    cycle ~n:2 ();
    let transfer mosi_bytes tx_bytes =
      inputs.tx_byte <--. List.hd_exn tx_bytes;
      inputs.cs_n := Bits.gnd;
      watch half;
      let miso_bytes =
        List.map2_exn
          mosi_bytes
          (List.tl_exn tx_bytes @ [ 0 ])
          ~f:(fun byte next_tx ->
            let sampled =
              List.fold (List.range 7 (-1) ~stride:(-1)) ~init:0 ~f:(fun acc b ->
                inputs.mosi <--. (byte lsr b) land 1;
                watch half;
                let bit = Bits.to_unsigned_int !(outputs.miso) in
                inputs.sck := Bits.vdd;
                watch half;
                inputs.sck := Bits.gnd;
                (acc lsl 1) lor bit)
            in
            inputs.tx_byte <--. next_tx;
            sampled)
      in
      watch half;
      inputs.cs_n := Bits.vdd;
      watch 3;
      miso_bytes
    in
    let miso = transfer [ 0xa5; 0x3c; 0xff; 0x00 ] [ 0x11; 0x22; 0x33; 0x44 ] in
    print_s [%message (List.rev !received : int list) (miso : int list)]);
  [%expect {| (("List.rev (!received)" (165 60 255 0)) (miso (17 34 51 68))) |}]
;;
