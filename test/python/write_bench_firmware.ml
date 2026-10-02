open! Core
open Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* The library firmware the outside chip acts in BRINGUP.md load, at the parameters the
   bench's 48 MHz needs, each checked by the analyser and the kernel under the assumption
   it runs with, as the command line does. *)
let bench =
  [ ( "spi_master"
    , "Firmware.spi_master ~half_period:8: SCK at 3 MHz, no chip select"
    , Firmware.spi_master ~half_period:8
    , Firmware.spi_config
    , None )
  ; ( "i2c_master"
    , "Firmware.i2c_master ~quarter:31, fraction 1/2: SCL low 63 cycles, 1.3125 us"
    , Firmware.i2c_master ~quarter:31
    , { Firmware.i2c_config with period_fraction = 0x8000 }
    , None )
  ; ( "one_wire"
    , "One_wire.firmware: the host sends the unit, 288 cycles for 6 us"
    , Timed_program.source One_wire.firmware
    , One_wire.config
    , Some 5 )
  ; ( "can"
    , "Can.firmware: the host sends the bit period, 96 cycles for 500 kbit/s"
    , Timed_program.source Can.firmware
    , Can.config
    , Some Can.shortest_period )
  ; ( "sk6812"
    , "Ws2812.firmware ~third:16 ~tail:7: T0H 333, T1H 667, T0L 813, T1L 479 ns"
    , Ws2812.firmware ~third:16 ~tail:7
    , Ws2812.config
    , None )
  ]
;;

let () =
  print_string
    "# Written by test/python/write_bench_firmware.ml; `dune promote` after a change.\n\
     # The outside chip acts' firmware (BRINGUP.md) as words and the configuration it runs\n\
     # under, at the bench's 48 MHz.\n";
  List.iter bench ~f:(fun (name, what, source, config, period_floor) ->
    let timed = Timed_program.of_source_exn ?period_floor ~config source in
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
    print_string "    ],\n}\n")
;;
