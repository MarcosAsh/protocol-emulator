open! Core
open Protocol_emulator

type t =
  { name : string
  ; source : string
  ; config : Program_config.t
  ; period : int option
  ; period_floor : int option
  ; single_capture_edge : bool
  ; no_wrap : bool
  }

let plain
  ?period
  ?period_floor
  ?(single_capture_edge = false)
  ?(no_wrap = false)
  name
  source
  config
  =
  { name; source; config; period; period_floor; single_capture_edge; no_wrap }
;;

let receiver = plain ~single_capture_edge:true ~no_wrap:true

let all =
  [ plain "uart_tx" (Firmware.uart_tx ~period:8) Program_config.default
    (* the same UART at the slower bit period the tests use *)
  ; plain "uart_tx16" (Timed_program.source Firmware.uart_tx16) Program_config.default
  ; plain
      ~period:434
      ~period_floor:4
      ~no_wrap:true
      "uart_tx_host_rate"
      Firmware.uart_tx_host_rate
      Program_config.default
  ; receiver "uart_rx" (Firmware.uart_rx ~period:16) Firmware.rx_config
  ; plain "spi_master" (Firmware.spi_master ~half_period:8) Firmware.spi_config
  ; plain "spi_slave" (Timed_program.source Firmware.spi_slave) Firmware.spi_slave_config
    (* the smallest Fast-mode Plus quarter at 50 MHz (test_i2c.ml): assumes zero rise
       time, with tHD;STA, tSU;STA and tSU;STO exactly at their limits *)
  ; plain ~no_wrap:true "i2c_master" (Firmware.i2c_master ~quarter:13) Firmware.i2c_config
  ; plain "i2c_slave" (Timed_program.source Firmware.i2c_slave) Firmware.i2c_slave_config
  ; plain
      "i2c_logger"
      (Timed_program.source Firmware.i2c_logger)
      Firmware.i2c_logger_config
  ; plain ~period:32 "usb_tx" (Timed_program.source Firmware.usb_tx) Firmware.usb_config
  ; receiver ~period:32 "usb_rx" (Firmware.usb_rx ~half_period:16) Firmware.usb_rx_config
  ; receiver
      ~period:32
      "usb_device"
      (Firmware.usb_device ~address:0 ~half_period:16)
      Firmware.usb_device_config
  ; plain "edge_meter" (Firmware.edge_meter ~period:16) Firmware.edge_meter_config
  ; plain ~no_wrap:true "ws2812" (Ws2812.firmware ~third:6 ~tail:7) Ws2812.config
  ; plain
      ~period:Ethernet.link_tenth
      ~no_wrap:true
      "ethernet"
      (Timed_program.source Ethernet.firmware)
      Ethernet.config
  ; plain
      ~period:One_wire.standard_unit
      ~period_floor:5
      "one_wire"
      (Timed_program.source One_wire.firmware)
      One_wire.config
  ; plain
      ~period:Ps2.standard_quarter
      ~period_floor:8
      "ps2"
      (Timed_program.source Ps2.firmware)
      Ps2.config
  ; plain "jtag" (Jtag.firmware ~half_period:Jtag.shortest_half) Jtag.config
  ; plain
      ~period:Can.period
      ~period_floor:Can.shortest_period
      ~no_wrap:true
      "can"
      (Timed_program.source Can.firmware)
      Can.config
  ; plain ~no_wrap:true "dshot600" Dshot.dshot600 Dshot.config
  ; plain
      ~period:Sent.standard_tick
      ~period_floor:Sent.shortest_tick
      ~no_wrap:true
      "sent"
      Sent.firmware
      Sent.config
  ; plain
      ~period:Cec.standard_unit
      ~period_floor:Cec.shortest_unit
      ~no_wrap:true
      "cec"
      Cec.firmware
      Cec.config
    (* half the bit at 115200 baud and 48 MHz *)
  ; receiver
      ~period:208
      ~period_floor:4
      "uart_rx_host_rate"
      Firmware.uart_rx_host_rate
      Firmware.rx_config
    (* Standard-mode and Fast-mode at 48 MHz, test/rates.ml *)
  ; plain
      ~period:121
      ~period_floor:8
      ~no_wrap:true
      "i2c_master_standard"
      (Firmware.i2c_master_host_rate_held ~quarters:3 ())
      Firmware.i2c_config
  ; plain
      ~period:32
      ~period_floor:8
      ~no_wrap:true
      "i2c_master_fast"
      (Firmware.i2c_master_host_rate_held ~quarters:2 ())
      Firmware.i2c_config
    (* each as test/both_roles.ml runs it on wires *)
  ; plain
      ~period:121
      ~period_floor:8
      ~no_wrap:true
      "i2c_controller_wire"
      Both_roles.I2c.controller
      Both_roles.I2c.controller_config
  ; plain "i2c_target_wire" Both_roles.I2c.target Both_roles.I2c.target_config
  ]
  (* the flash demo's master, 3 MHz at 48, which holds CS low as long as the host is slow,
     and a target in each mode *)
  @ List.concat_map Spi_cs.Mode.all ~f:(fun mode ->
    let n = Spi_cs.Mode.to_int mode in
    [ plain
        ~no_wrap:true
        [%string "spi_cs_mode%{n#Int}"]
        (Spi_cs.master ~mode ~half_period:8 ~setup:4 ~hold:8 ~deselect:144)
        Spi_cs.config
    ; plain
        [%string "spi_target_mode%{n#Int}"]
        (Spi_target.firmware ~mode Spi_target.pads)
        (Spi_target.config Spi_target.pads)
    ])
;;

let time_triggered =
  [ plain "uart_tx_stream" (Firmware.uart_tx_stream ~period:8) Firmware.stream_config
  ; plain
      "spi_master_stream"
      (Firmware.spi_master_stream ~half_period:8)
      Firmware.spi_stream_config
  ]
;;

let stamped =
  plain "uart_tx_stamped" (Firmware.uart_tx_stamped ~period:8) Program_config.default
;;

let find_exn name =
  match
    List.find ((stamped :: all) @ time_triggered) ~f:(fun t -> String.equal t.name name)
  with
  | Some t -> t
  | None -> raise_s [%message "no such firmware" (name : string)]
;;
