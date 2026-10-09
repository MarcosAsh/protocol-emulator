open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* each wait carries the level SCK already has *)
let master ~half_period =
  [%string
    {|
    .side_set 1
    set p, %{half_period#Int} side 0
idle:
    wait tx side 0
    pull side 0
    out null, 8 side 0
    set x, 7 side 0
    mov t, now side 0
    add t, p side 0
    wait t+ side 0
    out pins, 1 side 0       ; first bit, half a period before the first edge
bit:
    wait t+ side 0
    in pins, 1 side 1        ; rising edge
    wait t+ side 1
    out pins, 1 side 0       ; falling edge, next bit
    jmp x--, bit
    push side 0
    jmp idle
|}]
;;

(* Time-triggered: SCK runs from one anchor, a byte every eight bits with no gap, by
   autopull on falling edges and autopush on rising ones. *)
let master_stream ~half_period =
  [%string
    {|
    .side_set 1
    set p, %{half_period#Int} side 0
    mov t, now side 0        ; the only anchor
    add t, p side 0
    wait t+ side 0
    out pins, 1 side 0       ; first bit, half a period before the first edge
bit:
    wait t+ side 0
    in pins, 1 side 1        ; rising edge
    wait t+ side 1
    out pins, 1 side 0       ; falling edge, next bit
    jmp bit
|}]
;;

let sck_pin = 6
let mosi_pin = 5
let miso_pin = 0

let config =
  { Program_config.default with
    side_set_count = 1
  ; side_set_base = sck_pin
  ; out_base = mosi_pin
  ; in_base = miso_pin
  ; out_shift = Left
  ; in_shift = Left
  }
;;

let stream_config =
  { config with autopull = true; pull_threshold = 8; autopush = true; push_threshold = 8 }
;;

let slave_sck_pin = 1
let slave_mosi_pin = 2
let slave_miso_pin = 5

let slave_config =
  { Program_config.default with
    in_base = slave_mosi_pin
  ; out_base = slave_miso_pin
  ; in_shift = Left
  ; out_shift = Left
  ; autopush = true
  ; push_threshold = 8
  ; autopull = true
  ; pull_threshold = 8
  }
;;

(* Mode 0 slave, no chip select. Replies come from the host as [byte lsl 8]. Needs sck
   half periods of at least four cycles. *)
let slave =
  [%firmware
    {|
    out pins, 1              ; first bit of the first reply
bit:
    wait 1 pin 1             ; rising edge
    in pins, 1
    wait 0 pin 1             ; falling edge
    out pins, 1
    jmp bit
|}
      ~config:slave_config]
;;

let bench =
  { Bench.name = "spi_master"
  ; what =
      [%string
        "Firmware.spi_master ~half_period:%{Bench.spi_half#Int}: SCK at %{Bench.rate (2 \
         * Bench.spi_half)} on OUT5, MOSI on OUT4, MISO on IN0, no chip select"]
  ; source = master ~half_period:Bench.spi_half
  ; config = Bench.on_spi_pins config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus = None
  }
;;

let scenario =
  let sent = [ 0xa5; 0x3c; 0x0f ]
  and replies = [ 0x81; 0x7e; 0x42 ] in
  let peer () =
    let slave = ref (Protocol_models.Spi_slave.create replies) in
    { Peer.inputs = (fun () -> Protocol_models.Spi_slave.miso !slave lsl miso_pin)
    ; step =
        (fun ~pin_out ~pin_dir:_ ->
          slave
          := Protocol_models.Spi_slave.step
               !slave
               ~sck:(Peer.bit pin_out sck_pin)
               ~mosi:(Peer.bit pin_out mosi_pin))
    }
  in
  { Scenario.name = "spi_master"
  ; peer
  ; script =
      Scenario.load ~config ~program:(Firmware.assemble (master ~half_period:8))
      @ [ Write (Reg.tx, sent)
        ; Scenario.start
        ; Run 600
        ; Read (Reg.rx, 2)
        ; Read (Reg.status, 1)
        ]
  ; sigrok =
      Some
        { clock_hz = 48_000_000
        ; decoders =
            [ Sigrok.decoder
                "spi"
                ~pins:[ "clk", sck_pin; "mosi", mosi_pin; "miso", miso_pin ]
            ]
        ; expect =
            [ "spi=mosi-data", List.map sent ~f:(sprintf "spi-1: %02X")
            ; "spi=miso-data", List.map replies ~f:(sprintf "spi-1: %02X")
            ]
        ; joins_after = None
        ; rejected = None
        ; (* a bit of the first reply inverted *)
          teeth = [ [ Flip { pin = miso_pin; edge = 0; after = 0; cycles = 16 } ] ]
        }
  }
;;

let protocol =
  { Protocol.name = "spi"
  ; certified =
      [ Certified.plain "spi_master" (master ~half_period:8) config
      ; Certified.plain "spi_slave" (Timed_program.source slave) slave_config
      ]
  ; time_triggered =
      [ Certified.plain "spi_master_stream" (master_stream ~half_period:8) stream_config ]
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits = []
  ; unlimited = [ "spi_master", "no demo loads it" ]
  ; scenarios = [ scenario ]
  }
;;
