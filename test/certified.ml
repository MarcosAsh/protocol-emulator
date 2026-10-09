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

let others =
  [ plain ~period:32 "usb_tx" (Timed_program.source Firmware.usb_tx) Firmware.usb_config
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
  ]
;;
