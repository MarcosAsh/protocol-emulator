open! Core
open! Hardcaml
open Hardcaml_lws
open! Hardcaml_waveterm
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Host_spi.I) (Host_spi.O)

let ( <--. ) = Bits.( <--. )

let%expect_test "bytes cross in both directions" =
  let half = 4 in
  Harness.run
    ~random_initial_state:`All
    ~create:Host_spi.hierarchical
    (fun (h @ local) ~inputs ~outputs ->
       let cycle ?n () = Lws.step ?n h in
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

let%expect_test "waveform of one byte each way" =
  let display_rules =
    List.map
      [ "sck"
      ; "mosi"
      ; "selected"
      ; "sck_rise"
      ; "count"
      ; "shift_in"
      ; "rx_valid"
      ; "rx_byte"
      ]
      ~f:(fun name ->
        Display_rule.port_name_is ("host_spi$" ^ name) ~wave_format:(Bit_or Unsigned_int))
    @ [ Display_rule.port_name_is "miso" ~wave_format:Bit ]
  in
  Harness.run
    ~create:Host_spi.hierarchical
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:20
        ~display_width:90
        ~wave_width:0
        waves)
    (fun (h @ local) ~inputs ~outputs ->
      let cycle ?n () = Lws.step ?n h in
      let outputs = Before_and_after_edge.after_edge outputs in
      let watch n = cycle ~n () in
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
          ~half:1
      in
      inputs.tx_byte <--. 0x5a;
      inputs.cs_n := Bits.gnd;
      watch 2;
      let (_ : int) = Spi_master.byte m ~watch 0xa5 in
      watch 2;
      inputs.cs_n := Bits.vdd;
      watch 4;
      ());
  [%expect
    {|
    ┌Signals───────────┐┌Waves───────────────────────────────────────────────────────────────┐
    │host_spi$sck      ││                ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐                     │
    │                  ││────────────────┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─────────            │
    │host_spi$mosi     ││              ┌───┐   ┌───┐       ┌───┐   ┌─────────────            │
    │                  ││──────────────┘   └───┘   └───────┘   └───┘                         │
    │host_spi$selected ││──────┐   ┌───────────────────────────────────────┐                 │
    │                  ││      └───┘                                       └─────            │
    │host_spi$sck_rise ││                ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐                     │
    │                  ││────────────────┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─────────            │
    │                  ││──────────────────┬───┬───┬───┬───┬───┬───┬───┬─────────            │
    │host_spi$count    ││ 0                │1  │2  │3  │4  │5  │6  │7  │0                    │
    │                  ││──────────────────┴───┴───┴───┴───┴───┴───┴───┴─────────            │
    │                  ││──────────────────┬───┬───┬───┬───┬───┬───┬───┬─────────            │
    │host_spi$shift_in ││ 0                │1  │2  │5  │10 │20 │41 │82 │165                  │
    │                  ││──────────────────┴───┴───┴───┴───┴───┴───┴───┴─────────            │
    │host_spi$rx_valid ││                                              ┌─┐                   │
    │                  ││──────────────────────────────────────────────┘ └───────            │
    │                  ││──────────────────────────────────────────────┬─────────            │
    │host_spi$rx_byte  ││ 0                                            │165                  │
    │                  ││──────────────────────────────────────────────┴─────────            │
    │miso              ││                    ┌───┐   ┌───────┐   ┌───┐                       │
    │                  ││────────────────────┘   └───┘       └───┘   └───────────            │
    └──────────────────┘└────────────────────────────────────────────────────────────────────┘
    |}]
;;
