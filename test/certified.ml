open! Core
open Protocol_emulator

type t =
  { name : string
  ; source : string
  ; config : Program_config.t
  ; period : int option
  ; single_capture_edge : bool
  ; no_wrap : bool
  }

let plain ?period ?(single_capture_edge = false) ?(no_wrap = false) name source config =
  { name; source; config; period; single_capture_edge; no_wrap }
;;

let receiver = plain ~single_capture_edge:true ~no_wrap:true

let all =
  [ plain "uart_tx" (Firmware.uart_tx ~period:8) Program_config.default
    (* the same UART at the slower bit period the tests use, for the deep run *)
  ; plain "uart_tx16" (Firmware.uart_tx ~period:16) Program_config.default
  ; plain
      ~period:434
      ~no_wrap:true
      "uart_tx_host_rate"
      Firmware.uart_tx_host_rate
      Program_config.default
  ; receiver "uart_rx" (Firmware.uart_rx ~period:16) Firmware.rx_config
  ; plain "spi_master" (Firmware.spi_master ~half_period:8) Firmware.spi_config
  ; plain "spi_slave" Firmware.spi_slave Firmware.spi_slave_config
  ; plain ~no_wrap:true "i2c_master" (Firmware.i2c_master ~quarter:10) Firmware.i2c_config
  ; plain "i2c_slave" Firmware.i2c_slave Firmware.i2c_slave_config
  ; plain "i2c_logger" Firmware.i2c_logger Firmware.i2c_logger_config
  ; plain ~period:32 "usb_tx" Firmware.usb_tx Firmware.usb_config
  ; receiver ~period:32 "usb_rx" (Firmware.usb_rx ~half_period:16) Firmware.usb_rx_config
  ; receiver
      ~period:32
      "usb_device"
      (Firmware.usb_device ~address:0 ~half_period:16)
      Firmware.usb_device_config
  ; plain "edge_meter" (Firmware.edge_meter ~period:16) Firmware.edge_meter_config
  ; plain ~no_wrap:true "ws2812" (Ws2812.firmware ~third:6 ~tail:7) Ws2812.config
  ; plain ~period:Ethernet.link_tenth "ethernet" Ethernet.firmware Ethernet.config
  ; plain ~period:One_wire.standard_unit "one_wire" One_wire.firmware One_wire.config
  ; plain ~period:Ps2.standard_quarter "ps2" Ps2.firmware Ps2.config
  ; plain "jtag" (Jtag.firmware ~half_period:Jtag.shortest_half) Jtag.config
  ]
;;

let find_exn name =
  match List.find all ~f:(fun t -> String.equal t.name name) with
  | Some t -> t
  | None -> raise_s [%message "no such firmware" (name : string)]
;;
