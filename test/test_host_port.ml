open! Core
open! Hardcaml
open Hardcaml_lws
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Host_port.I) (Host_port.O)
module Reg = Host_port.Reg

let ( <--. ) = Bits.( <--. )

let run ~half f =
  Harness.run
    ~random_initial_state:`All
    ~create:Host_port.hierarchical
    (fun (h @ local) ~inputs ~outputs ->
       let cycle ?n () = Lws.step ?n h in
       let o = Before_and_after_edge.after_edge outputs in
       let events = ref [] in
       let note e = events := e :: !events in
       let watch n =
         for _ = 1 to n do
           cycle ();
           let int r = Bits.to_unsigned_int !r in
           if Bits.to_bool !(o.start) then note "start";
           if Bits.to_bool !(o.clear_irq) then note "clear_irq";
           if Bits.to_bool !(o.program_write.valid)
           then
             note
               [%string
                 "program[%{int o.program_write.addr#Int}] <- %{int \
                  o.program_write.data#Int}"];
           if Bits.to_bool !(o.tx.valid) then note [%string "tx <- %{int o.tx.value#Int}"];
           if Bits.to_bool !(o.rx_pop) then note "rx_pop"
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

let%expect_test "program load, control and fifo strobes" =
  run ~half:4 (fun m ~watch _ _ ->
    Spi_master.write m ~watch Reg.program_addr [ 3 ];
    Spi_master.write m ~watch Reg.program [ 0xa010; 0x20e0; 0x0001 ];
    let program_addr = Spi_master.read m ~watch Reg.program_addr ~count:1 in
    print_s [%message (program_addr : int list)];
    Spi_master.write m ~watch Reg.tx [ 0x55; 0xa3 ];
    Spi_master.write m ~watch Reg.control [ 1 ];
    Spi_master.write m ~watch Reg.control [ 2 ]);
  [%expect
    {|
    (program_addr (6))
    (events
     ("program[3] <- 40976" "program[4] <- 8416" "program[5] <- 1" "tx <- 85"
      "tx <- 163" start clear_irq))
    |}]
;;

let%expect_test "status and fifo reads" =
  run ~half:4 (fun m ~watch inputs _ ->
    inputs.status.halted := Bits.vdd;
    inputs.status.fault.missed_deadline := Bits.vdd;
    inputs.status.tx_level <--. 2;
    inputs.status.rx_level <--. 3;
    inputs.status.pc <--. 0x1ab;
    inputs.status.now <--. 0x123456;
    inputs.status.capture <--. 0xabcdef;
    inputs.status.rx_head <--. 0xbeef;
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
    (status (words (1681)))
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
        (Engine.Config.map o.config ~f:(fun r -> Bits.to_unsigned_int !r))
    in
    let read_back = List.zip_exn fields back in
    print_s [%message (read_back : (string * int) list) (live : int list)]);
  [%expect
    {|
    ((read_back
      ((side_set_count 1) (side_set_base 2) (side_set_pindirs 1) (in_base 4)
       (out_base 5) (out_count 6) (set_base 7) (set_count 0) (jmp_pin 9)
       (capture_pin 10) (capture_rising 1) (in_shift_right 0) (out_shift_right 1)
       (autopush 0) (push_threshold 15) (autopull 0) (pull_threshold 17)
       (crc_width 18) (crc_poly 19) (crc_init 20) (crc_reflect 1)
       (stuff_threshold 22) (stuff_level 1)))
     (live (1 2 1 4 5 6 7 0 9 10 1 0 1 0 15 0 17 18 19 20 1 22 1)))
    (events ())
    |}]
;;
