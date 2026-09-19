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
    let m =
      Spi_master.create
        ~sck:inputs.sck
        ~mosi:inputs.mosi
        ~cs_n:inputs.cs_n
        ~miso:outputs.miso
        ~half
    in
    let transfer mosi_bytes tx_bytes =
      let tx = Array.of_list (List.tl_exn tx_bytes @ [ 0 ]) in
      let replies = ref [] in
      inputs.tx_byte <--. List.hd_exn tx_bytes;
      inputs.cs_n := Bits.gnd;
      watch half;
      for n = 0 to List.length mosi_bytes - 1 do
        replies := Spi_master.byte m ~watch (List.nth_exn mosi_bytes n) :: !replies;
        inputs.tx_byte <--. tx.(n)
      done;
      watch half;
      inputs.cs_n := Bits.vdd;
      watch 3;
      List.rev !replies
    in
    let miso = transfer [ 0xa5; 0x3c; 0xff; 0x00 ] [ 0x11; 0x22; 0x33; 0x44 ] in
    let received = List.rev !received in
    print_s [%message (received : int list) (miso : int list)]);
  [%expect {| ((received (165 60 255 0)) (miso (17 34 51 68))) |}]
;;
