open! Core
open! Hardcaml
open Hardcaml_lws
open! Hardcaml_waveterm
open Protocol_emulator
module Reg = Host_port.Reg

let ( <--. ) = Bits.( <--. )

module Bench (Config : Host_port.Config) = struct
  module Dut = Host_port.Make (Config)
  module Harness = Hardcaml_test_harness.Lws_harness.Make (Dut.I) (Dut.O)

  let run ~half f =
    Harness.run
      ~random_initial_state:`All
      ~create:Dut.hierarchical
      (fun (h @ local) ~inputs ~outputs ->
         let cycle ?n () = Lws.step ?n h in
         let o = Before_and_after_edge.after_edge outputs in
         let events = ref [] in
         let watch n =
           for _ = 1 to n do
             cycle ();
             let int r = Bits.to_unsigned_int !r in
             List.iteri o.engines ~f:(fun engine (o : _ Engine.Host.t) ->
               let note e =
                 events
                 := (if Config.engines = 1 then e else [%string "%{engine#Int}: %{e}"])
                    :: !events
               in
               if Bits.to_bool !(o.start) then note "start";
               if Bits.to_bool !(o.clear_irq) then note "clear_irq";
               if Bits.to_bool !(o.stop) then note "stop";
               if Bits.to_bool !(o.flush) then note "flush";
               if Bits.to_bool !(o.program_write.valid)
               then
                 note
                   [%string
                     "program[%{int o.program_write.addr#Int}] <- %{int \
                      o.program_write.data#Int}"];
               if Bits.to_bool !(o.tx.valid)
               then note [%string "tx <- %{int o.tx.value#Int}"];
               if Bits.to_bool !(o.rx_pop) then note "rx_pop")
           done
         in
         inputs.clocking.clear := Bits.vdd;
         cycle ();
         inputs.clocking.clear := Bits.gnd;
         let master =
           Spi_master.create
             ~sck:inputs.sck
             ~mosi:inputs.mosi
             ~cs_n:inputs.cs_n
             ~miso:o.miso
             ~half
         in
         cycle ~n:2 ();
         f master ~watch inputs o;
         let events = List.rev !events in
         print_s [%message (events : string list)])
  ;;
end

module One = Bench (struct
    let engines = 1
  end)

module Two = Bench (struct
    let engines = 2
  end)

let run = One.run

let%expect_test "program load, control and fifo strobes" =
  run ~half:4 (fun m ~watch _ _ ->
    Spi_master.write m ~watch Reg.program_addr [ 3 ];
    Spi_master.write m ~watch Reg.program [ 0xa010; 0x20e0; 0x0001 ];
    let program_addr = Spi_master.read m ~watch Reg.program_addr ~count:1 in
    print_s [%message (program_addr : int list)];
    Spi_master.write m ~watch Reg.tx [ 0x55; 0xa3 ];
    Spi_master.write m ~watch Reg.control [ 1 ];
    Spi_master.write m ~watch Reg.control [ 2 ];
    Spi_master.write m ~watch Reg.control [ 4 ];
    Spi_master.write m ~watch Reg.control [ 8 ]);
  [%expect
    {|
    (program_addr (6))
    (events
     ("program[3] <- 40976" "program[4] <- 8416" "program[5] <- 1" "tx <- 85"
      "tx <- 163" start clear_irq stop flush))
    |}]
;;

let%expect_test "status and fifo reads" =
  run ~half:4 (fun m ~watch inputs _ ->
    let status = List.hd_exn inputs.status in
    status.halted := Bits.vdd;
    status.fault.missed_deadline := Bits.vdd;
    status.tx_level <--. 2;
    status.rx_level <--. 3;
    status.pc <--. 0x1ab;
    status.now <--. 0x123456;
    status.capture <--. 0xabcdef;
    status.rx_head <--. 0xbeef;
    List.iter
      [ "status", Reg.status, 1
      ; "pc", Reg.pc, 1
      ; "now_lo", Reg.now_lo, 1
      ; "now_hi", Reg.now_hi, 1
      ; "capture_lo", Reg.capture_lo, 1
      ; "capture_hi", Reg.capture_hi, 1
      ; "rx", Reg.rx, 2
      ]
      ~f:(fun (name, reg, count) ->
        let words = Spi_master.read m ~watch reg ~count in
        print_s [%message name (words : int list)]);
    ());
  [%expect
    {|
    (status (words (3217)))
    (pc (words (427)))
    (now_lo (words (13398)))
    (now_hi (words (18)))
    (capture_lo (words (52719)))
    (capture_hi (words (171)))
    (rx (words (48879 48879)))
    (events (rx_pop rx_pop))
    |}]
;;

let%expect_test "config registers read back" =
  run ~half:4 (fun m ~watch _ o ->
    let fields = Engine.Config.to_list Engine.Config.port_names in
    List.iteri fields ~f:(fun n _ -> Spi_master.write m ~watch (Reg.config + n) [ n + 1 ]);
    let back =
      List.mapi fields ~f:(fun n _ ->
        List.hd_exn (Spi_master.read m ~watch (Reg.config + n) ~count:1))
    in
    let live =
      Engine.Config.to_list
        (Engine.Config.map (List.hd_exn o.engines).config ~f:(fun r ->
           Bits.to_unsigned_int !r))
    in
    let read_back = List.zip_exn fields back in
    print_s [%message (read_back : (string * int) list) (live : int list)]);
  [%expect
    {|
    ((read_back
      ((side_set_count 1) (side_set_base 2) (side_set_pindirs 1) (in_base 4)
       (in_count 5) (out_base 6) (out_count 7) (set_base 8) (set_count 1)
       (jmp_pin 10) (capture_pin 11) (capture_rising 0) (in_shift_right 1)
       (out_shift_right 0) (autopush 1) (push_threshold 16) (autopull 1)
       (pull_threshold 18) (crc_width 19) (crc_poly 20) (crc_init 21)
       (crc_reflect 0) (stuff_threshold 23) (stuff_level 0) (wrap_bottom 25)
       (wrap_top 26)))
     (live (1 2 1 4 5 6 7 8 1 10 11 0 1 0 1 16 1 18 19 20 21 0 23 0 25 26)))
    (events ())
    |}]
;;

let%expect_test "select routes every register but the program address" =
  Two.run ~half:4 (fun m ~watch inputs o ->
    List.iteri inputs.status ~f:(fun n status ->
      status.pc <--. 0x100 + n;
      status.rx_head <--. 0xbe00 + n);
    (List.nth_exn inputs.status 1).irq := Bits.vdd;
    let read name reg =
      let words = Spi_master.read m ~watch reg ~count:1 in
      print_s [%message name (words : int list)]
    in
    let to_engine n =
      Spi_master.write m ~watch Reg.select [ n ];
      read "select" Reg.select;
      Spi_master.write m ~watch Reg.program_addr [ 8 * (n + 1) ];
      Spi_master.write m ~watch Reg.program [ 0xa010 + n ];
      Spi_master.write m ~watch Reg.tx [ 0x55 + n ];
      Spi_master.write m ~watch Reg.control [ 0xf ];
      Spi_master.write m ~watch (Reg.config + 1) [ 12 + n ];
      read "side_set_base" (Reg.config + 1);
      read "status" Reg.status;
      read "pc" Reg.pc;
      read "rx" Reg.rx
    in
    to_engine 0;
    to_engine 1;
    Spi_master.write m ~watch Reg.select [ 0 ];
    read "side_set_base of engine 0 again" (Reg.config + 1);
    let live =
      List.map o.engines ~f:(fun e -> Bits.to_unsigned_int !(e.config.side_set_base))
    in
    print_s [%message (live : int list)]);
  [%expect
    {|
    (select (words (0)))
    (side_set_base (words (12)))
    (status (words (32768)))
    (pc (words (256)))
    (rx (words (48640)))
    (select (words (1)))
    (side_set_base (words (13)))
    (status (words (2)))
    (pc (words (257)))
    (rx (words (48641)))
    ("side_set_base of engine 0 again" (words (12)))
    (live (12 13))
    (events
     ("0: program[8] <- 40976" "0: tx <- 85" "0: start" "0: clear_irq" "0: stop"
      "0: flush" "0: rx_pop" "1: program[16] <- 40977" "1: tx <- 86" "1: start"
      "1: clear_irq" "1: stop" "1: flush" "1: rx_pop"))
    |}]
;;

let%expect_test "waveform of a control write" =
  let display_rules =
    [ Display_rule.port_name_is "host_port$sm" ~wave_format:(Index Host_port.State.names)
    ]
    @ List.map [ "cmd"; "write" ] ~f:(fun name ->
      Display_rule.port_name_is ("host_port$" ^ name) ~wave_format:(Bit_or Unsigned_int))
    @ [ Display_rule.port_name_is "engines$start_0" ~wave_format:Bit ]
  in
  One.Harness.run
    ~create:One.Dut.hierarchical
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:20
        ~display_width:90
        ~wave_width:(-1)
        waves)
    (fun (h @ local) ~inputs ~outputs ->
      let cycle ?n () = Lws.step ?n h in
      let o = Before_and_after_edge.after_edge outputs in
      let watch n = cycle ~n () in
      inputs.clocking.clear := Bits.vdd;
      cycle ();
      inputs.clocking.clear := Bits.gnd;
      let master =
        Spi_master.create
          ~sck:inputs.sck
          ~mosi:inputs.mosi
          ~cs_n:inputs.cs_n
          ~miso:o.miso
          ~half:1
      in
      cycle ~n:2 ();
      Spi_master.write master ~watch Reg.control [ 1 ];
      watch 4;
      ());
  [%expect
    {|
    ┌Signals───────────┐┌Waves───────────────────────────────────────────────────────────────┐
    │                  ││───────────────────────┬───────────────┬───────────────┬─────       │
    │host_port$sm      ││ C                     │H              │L              │H           │
    │                  ││───────────────────────┴───────────────┴───────────────┴─────       │
    │                  ││───────────────────────┬─────────────────────────────────────       │
    │host_port$cmd     ││ 0                     │128                                         │
    │                  ││───────────────────────┴─────────────────────────────────────       │
    │host_port$write   ││                                                      ┌┐            │
    │                  ││──────────────────────────────────────────────────────┘└─────       │
    │engines$start_0   ││                                                      ┌┐            │
    │                  ││──────────────────────────────────────────────────────┘└─────       │
    └──────────────────┘└────────────────────────────────────────────────────────────────────┘
    |}]
;;
