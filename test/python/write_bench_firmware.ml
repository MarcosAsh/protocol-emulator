open! Core
open Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* The library firmware the outside chip acts in BRINGUP.md load, at the parameters the
   bench's clock needs, each checked by the analyser and the kernel under the assumption
   it runs with, as the command line does. The Icepi's USB build drives IO0 and IO1's
   header pins with the USB lines, so I2C moves to IO2 and IO3, 1-Wire to IO4 and 10BASE-T
   to IO6 and IO7. The bench is wired once for every act: CAN's TX keeps OUT1 and SWD
   keeps OUT2 and IO5, so the SK6812 moves to OUT3 and the SPI masters to MOSI on OUT4,
   SCK on OUT5 and CS on OUT6. The CAN node's CRX is on IN1. *)
let neopixel = 8
let mosi = 9
let sck = 10
let sda = 14
let scl = 15
let one_wire = 16
let td_plus = 18

(* side-set bit 0 is SCK and bit 1, for Spi_cs, CS *)
let on_spi_pins (config : Program_config.t) =
  { config with out_base = mosi; set_base = mosi; side_set_base = sck }
;;

(* The library's reset is 80 units, 480 us at the 6 us unit: exactly the least a DS18B20
   takes. One more pass of its low loop makes it 84, 504 us. *)
let one_wire_firmware =
  let source = Timed_program.source One_wire.firmware in
  let pattern = "    set x, 19\n" in
  if List.length (String.substr_index_all source ~may_overlap:false ~pattern) <> 1
  then raise_s [%message "BUG: One_wire.firmware's reset loop has moved"];
  String.substr_replace_first source ~pattern ~with_:"    set x, 20\n"
;;

let bench =
  [ ( "spi_master"
    , "Firmware.spi_master ~half_period:8: SCK at 3 MHz on OUT5, MOSI on OUT4, MISO on \
       IN0, no chip select"
    , Firmware.spi_master ~half_period:8
    , on_spi_pins Firmware.spi_config
    , `None )
  ; ( "i2c_master"
    , "Firmware.i2c_master_host_rate: the host sends the quarter, 48 cycles for 250 kHz, \
       SDA on IO2, SCL on IO3"
    , Firmware.i2c_master_host_rate
    , { Firmware.i2c_config with
        side_set_base = scl
      ; out_base = sda
      ; set_base = sda
      ; in_base = sda
      ; jmp_pin = sda
      }
    , `Floor 31 )
  ; ( "i2c_master_stretch"
    , "Firmware.i2c_master_stretch_host_rate: i2c_master waiting on SCL, SDA on IO2, SCL \
       on IO3"
    , Firmware.i2c_master_stretch_host_rate
    , { Firmware.i2c_stretch_config with
        side_set_base = scl
      ; out_base = sda
      ; set_base = sda
      ; in_base = sda
      ; jmp_pin = scl
      }
    , `Floor 31 )
  ; ( "one_wire"
    , "One_wire.firmware with a reset of 84 units: the host sends the unit, 288 cycles \
       for 6 us, so 504 us, on IO4"
    , one_wire_firmware
    , { One_wire.config with
        in_base = one_wire
      ; out_base = one_wire
      ; set_base = one_wire
      }
    , `Floor 5 )
  ; ( "can"
    , "Can.firmware: the host sends the bit period, 96 cycles for 500 kbit/s"
    , Timed_program.source Can.firmware
    , Can.config
    , `Floor Can.shortest_period )
  ; ( "can_sender"
    , "Can_node.Sender.firmware: Can.firmware reading its ACK slot on IN1, the host \
       sends the bit period, 96 cycles for 500 kbit/s"
    , Timed_program.source Can_node.Sender.firmware
    , Can_node.Sender.config
    , `Floor Can_node.Sender.shortest_period )
  ; ( "can_receiver"
    , "Can_node.Receiver.firmware: 500 kbit/s at 48 MHz sampled 72 cycles in, CRX on \
       IN1, the ACK on OUT1"
    , Timed_program.source Can_node.Receiver.firmware
    , Can_node.Receiver.config
    , `Receiver Can_node.Receiver.period )
  ; ( "sk6812"
    , "Ws2812.firmware ~third:16 ~tail:7: T0H 333, T1H 667, T0L 813, T1L 479 ns, on OUT3"
    , Ws2812.firmware ~third:16 ~tail:7
    , { Ws2812.config with out_base = neopixel; set_base = neopixel }
    , `None )
  ; ( "start_hold"
    , "Firmware.start_hold for engine 1: each START's hold in cycles, SDA on IO2, SCL on \
       IO3, both only listened to"
    , Firmware.start_hold ~sda ~scl
    , Firmware.start_hold_config ~scl
    , `None )
  ; ( "ethernet"
    , "Ethernet.firmware at the Icepi's 40 MHz: the host sends a tenth of the link pulse \
       interval, 64000 cycles for 16 ms, TD+ on IO6, TD- on IO7"
    , Timed_program.source Ethernet.firmware
    , { Ethernet.config with out_base = td_plus; set_base = td_plus }
    , `Period Ethernet.link_tenth )
  ; ( "swd"
    , "Swd.firmware: the host sends the half period, 24 cycles for a 1 MHz SWCLK, SWCLK \
       on OUT2, SWDIO on IO5"
    , Timed_program.source Swd.firmware
    , Swd.config
    , `Floor Swd.shortest_half )
  ]
  @ List.map Spi_cs.Mode.all ~f:(fun mode ->
    let n = Spi_cs.Mode.to_int mode in
    ( [%string "spi_cs_mode%{n#Int}"]
    , [%string
        "Spi_cs.master in mode %{n#Int}, half period 8: SCK at 3 MHz on OUT5, MOSI on \
         OUT4, MISO on IN0, CS on OUT6 4 cycles before the first edge and 8 after the \
         last"]
    , Spi_cs.master ~mode ~half_period:8 ~setup:4 ~hold:8
    , on_spi_pins Spi_cs.config
    , `None ))
;;

let () =
  print_string
    "# Written by test/python/write_bench_firmware.ml; `dune promote` after a change.\n\
     # The outside chip acts' firmware (BRINGUP.md) as words and the configuration it runs\n\
     # under, at the bench's 48 MHz but for 10BASE-T's 40.\n";
  List.iter bench ~f:(fun (name, what, source, config, assumption) ->
    let timed =
      match assumption with
      | `None -> Timed_program.of_source_exn ~config source
      | `Floor period_floor -> Timed_program.of_source_exn ~period_floor ~config source
      | `Period period -> Timed_program.of_source_exn ~period ~config source
      | `Receiver period ->
        Timed_program.of_source_exn ~period ~single_capture_edge:true ~config source
    in
    let loaded, single_edge =
      match assumption with
      | `None -> None, false
      | `Floor period | `Period period -> Some period, false
      | `Receiver period -> Some period, true
    in
    let certificate =
      Load_check.of_table
        ~config:(Timed_program.config timed)
        ~words:(Timed_program.words timed)
        (Kernel.Table.of_analyser (Timed_program.rows timed))
      |> ok_exn
      |> Load_check.to_words
    in
    let fields =
      Engine.Config.map2
        Engine.Config.port_names
        (Engine.Config.of_program_config (Timed_program.config timed))
        ~f:(fun name value -> name, Bits.to_unsigned_int value)
      |> Engine.Config.to_list
    in
    printf "\n# %s\n%s = {\n    \"config\": {\n" what (String.uppercase name);
    List.iter fields ~f:(fun (field, value) -> printf "        \"%s\": %d,\n" field value);
    print_string "    },\n    \"words\": [\n";
    List.chunks_of (Timed_program.words timed) ~length:8
    |> List.iter ~f:(fun chunk ->
      printf
        "        %s,\n"
        (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))));
    print_string "    ],\n    \"certificate\": [\n";
    List.chunks_of certificate ~length:8
    |> List.iter ~f:(fun chunk ->
      printf
        "        %s,\n"
        (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))));
    printf
      "    ],\n    \"loaded\": %s,\n    \"single_edge\": %d,\n}\n"
      (Option.value_map loaded ~default:"None" ~f:Int.to_string)
      (Bool.to_int single_edge))
;;
