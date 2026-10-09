open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

let cycle_ns ~clock_hz = 1_000_000_000 / clock_hz

(* what sigrok-cli prints for an instance of a decoder *)
let lines decoder = List.map ~f:(sprintf "%s-1: %s" decoder)

(* The host waits eleven bits after the period before the first frame, as a node joining
   the bus has to: the firmware sends whenever it has words. *)
let can_scenario ?(teeth = []) ~name ~frames ~rejected () =
  let clock_hz = 48_000_000 in
  let send frame =
    [ Step.Write (Reg.tx, Can.words frame)
    ; Run (List.length (Can.line frame) * Can.period)
    ]
  in
  { Scenario.name
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load ~config:Can.config ~program:(Timed_program.words Can.firmware)
      @ [ Scenario.start; Write (Reg.tx, [ Can.period ]); Run (12 * Can.period) ]
      @ List.concat_map frames ~f:send
  ; sigrok =
      Some
        { clock_hz
        ; decoders =
            [ Sigrok.decoder
                "can"
                ~pins:[ "can_rx", Can.tx_pin ]
                ~options:[ "nominal_bitrate", Int.to_string (clock_hz / Can.period) ]
            ]
        ; expect =
            [ ( "can=sof:id:ide:rtr:dlc:data:crc-sequence:ack-slot:eof"
              , List.concat_map frames ~f:(fun (frame : Can.Frame.t) ->
                  [ "Start of frame"
                  ; sprintf "Identifier: %d (0x%x)" frame.id frame.id
                  ; "Identifier extension bit: standard frame"
                  ; sprintf
                      "Remote transmission request: %s frame"
                      (if frame.rtr then "remote" else "data")
                  ; sprintf "Data length code: %d" frame.dlc
                  ]
                  @ List.mapi frame.data ~f:(sprintf "Data byte %d: 0x%02x")
                  @ [ sprintf "CRC-15 sequence: 0x%04x" (Can.crc frame)
                    ; "ACK slot: NACK"
                    ; "End of frame"
                    ])
                |> lines "can" )
            ]
        ; joins_after =
            Some
              ( 11 * Can.period
              , { why =
                    "the pin is dominant from reset until a bit after the period \
                     arrives, which sigrok reads as frames of zeros"
                ; first_difference = 1
                ; reads = "can-1: Identifier: 0 (0x0)"
                } )
        ; rejected
        ; teeth
        }
  }
;;

let can =
  (* edge 1 is the first SOF: a data bit inverted and the CRC left as it was *)
  let tooth =
    [ Sigrok.Corruption.Flip
        { pin = Can.tx_pin; edge = 1; after = 25 * Can.period; cycles = Can.period }
    ]
  in
  can_scenario
    ~name:"can"
    ~frames:
      [ Can.Frame.data ~id:0x123 [ 0xde; 0xad ]
      ; Can.Frame.data ~id:0x555 [ 0x00; 0xff; 0x55; 0xaa; 0x01; 0x80; 0x7f; 0xfe ]
      ; Can.Frame.data ~id:0x000 []
      ]
    ~rejected:None
    ~teeth:[ tooth ]
    ()
;;

let can_remote =
  can_scenario
    ~name:"can_remote"
    ~frames:[ Can.Frame.remote ~id:0x0f0 ~dlc:4; Can.Frame.data ~id:0x123 [ 0xde; 0xad ] ]
    ~rejected:
      (Some
         { why =
             "sigrok 0.5.3 reads a remote frame's DLC of data bytes, though a remote \
              frame carries none"
         ; first_difference = 5 (* the line after the remote frame's DLC *)
         ; reads = "can-1: Data byte 0:"
         })
    ()
;;

(* A unit of 25 cycles, as a 500 kHz clock gives, keeps the simulation short. *)
let cec =
  let clock_hz = 500_000 in
  let unit = clock_hz / 20_000 in
  let frame ~to_ data = { Cec.Frame.initiator = 4; destination = to_; data } in
  let frames =
    [ frame ~to_:0 []
    ; frame ~to_:0 [ 0x04 ]
    ; frame ~to_:0 [ 0x47; Char.to_int 'C'; Char.to_int 'E'; Char.to_int 'C' ]
    ; frame ~to_:15 [ 0x36 ]
    ]
  in
  let peer () =
    let follower = ref (Cec.Follower.create ~cycle_ns:(cycle_ns ~clock_hz) ~address:0) in
    let low = ref false in
    { Peer.inputs = (fun () -> if !low then 0 else 1 lsl Cec.pin)
    ; step =
        (fun ~pin_out:_ ~pin_dir ->
          low := Peer.bit pin_dir Cec.pin = 1 || Cec.Follower.drive_low !follower;
          follower := Cec.Follower.step !follower ~low:!low)
    }
  in
  (* the start bit is 90 units, a block 480, and the line is left free for 336 *)
  let send (frame : Cec.Frame.t) =
    let blocks = 1 + List.length frame.data in
    [ Step.Write (Reg.tx, Cec.words frame)
    ; Run ((90 + (480 * blocks) + 336 + 10) * unit)
    ; Read (Reg.rx, blocks)
    ]
  in
  { Scenario.name = "cec"
  ; peer
  ; script =
      Scenario.load ~config:Cec.config ~program:(Firmware.assemble Cec.firmware)
      @ [ Scenario.start; Write (Reg.tx, [ unit ]) ]
      @ List.concat_map frames ~f:send
  ; sigrok =
      Some
        { clock_hz
        ; decoders = [ Sigrok.decoder "cec" ~pins:[ "cec", Cec.pin ] ]
        ; expect =
            [ ( "cec=frames"
              , List.map frames ~f:(fun frame ->
                  ((frame.initiator lsl 4) lor frame.destination) :: frame.data
                  |> List.map ~f:(sprintf "%02x")
                  |> String.concat ~sep:":")
                |> lines "cec" )
            ; (* the follower at 0 pulls each ACK slot low; nobody refuses a broadcast *)
              ( "cec=ack:nack"
              , List.concat_map frames ~f:(fun frame ->
                  List.init (1 + List.length frame.data) ~f:(fun _ -> "ACK"))
                |> lines "cec" )
            ]
        ; joins_after = None
        ; rejected = None
        ; (* edge 5 ends the low of the header's first one: 0.9 ms, past a one's 0.8 *)
          teeth = [ [ Shift { pin = Cec.pin; edge = 5; cycles = 6 * unit } ] ]
        }
  }
;;

let one_wire =
  let rom = One_wire.rom ~family:0x28 ~serial:0x0123_4567_89ab in
  let unit = One_wire.standard_unit in
  let peer () =
    let slave = ref (One_wire.Slave.create ~cycle_ns:One_wire.cycle_ns ~rom) in
    let low = ref false in
    { Peer.inputs = (fun () -> if !low then 0 else 1 lsl One_wire.pin)
    ; step =
        (fun ~pin_out:_ ~pin_dir ->
          let master_low = Peer.bit pin_dir One_wire.pin = 1 in
          low := master_low || One_wire.Slave.drive_low !slave;
          slave := One_wire.Slave.step !slave ~master_low)
    }
  in
  (* a reset is 160 units and a byte 88 *)
  let read_four =
    [ Step.Write (Reg.tx, List.init 4 ~f:(fun _ -> One_wire.byte 0xff))
    ; Run ((4 * 88 * unit) + 1000)
    ; Read (Reg.rx, 4)
    ]
  in
  { Scenario.name = "one_wire"
  ; peer
  ; script =
      Scenario.load
        ~config:One_wire.config
        ~program:(Timed_program.words One_wire.firmware)
      @ [ Scenario.start
        ; Write (Reg.tx, [ unit; One_wire.reset; One_wire.byte 0x33 ])
        ; Run (((160 + 88) * unit) + 1000)
        ; Read (Reg.rx, 2)
        ]
      @ read_four
      @ read_four
  ; sigrok =
      Some
        { clock_hz = 1_000_000_000 / One_wire.cycle_ns
        ; decoders =
            [ String.concat
                ~sep:","
                [ Sigrok.decoder "onewire_link" ~pins:[ "owr", One_wire.pin ]
                ; Sigrok.decoder "onewire_network"
                ]
            ]
        ; expect =
            [ ( "onewire_link=reset:presence"
              , lines "onewire_link" [ "Reset"; "Presence: true" ] )
            ; ( "onewire_network"
              , lines
                  "onewire_network"
                  [ "Reset/presence: true"
                  ; "ROM command: 0x33 'Read ROM'"
                  ; sprintf
                      "ROM: 0x%016x"
                      (List.fold_right rom ~init:0 ~f:(fun byte rest ->
                         (rest lsl 8) lor byte))
                  ] )
            ]
        ; joins_after = None
        ; rejected = None
        ; (* edge 6 starts the command's second slot: 14 us early, the first is 52 us *)
          teeth =
            [ [ Shift
                  { pin = One_wire.pin; edge = 6; cycles = -14_000 / One_wire.cycle_ns }
              ]
            ]
        }
  }
;;

(* The host lets each frame end, then holds the clock low for 100 us as it takes the byte
   in. That fall is also the twelfth sigrok 0.5.3's ps2 decoder waits for before it reads
   a frame of eleven clocks. *)
let ps2 =
  let quarter = Ps2.standard_quarter in
  let bytes = [ 0x1c; 0xf0; 0x1c ] in
  let peer () =
    let clock = ref 1
    and data = ref 1
    and falls = ref 0
    and inhibit_in = ref None
    and holding = ref 0 in
    { Peer.inputs = (fun () -> (!clock lsl Ps2.clock_pin) lor (!data lsl Ps2.data_pin))
    ; step =
        (fun ~pin_out:_ ~pin_dir ->
          let was = !clock in
          (match !inhibit_in with
           | Some 0 ->
             inhibit_in := None;
             holding := 100_000 / Ps2.cycle_ns
           | Some n -> inhibit_in := Some (n - 1)
           | None -> if !holding > 0 then decr holding);
          clock := if Peer.bit pin_dir Ps2.clock_pin = 1 || !holding > 0 then 0 else 1;
          data := 1 - Peer.bit pin_dir Ps2.data_pin;
          if was = 1 && !clock = 0 && !holding = 0 then incr falls;
          if was = 0 && !clock = 1 && !falls = 11
          then (
            falls := 0;
            inhibit_in := Some quarter))
    }
  in
  (* a frame is a clock period of idle and eleven clocks, 48 quarters *)
  let send byte = [ Step.Write (Reg.tx, [ byte ]); Run ((48 * quarter) + 10_000) ] in
  { Scenario.name = "ps2"
  ; peer
  ; script =
      Scenario.load ~config:Ps2.config ~program:(Timed_program.words Ps2.firmware)
      @ [ Scenario.start; Write (Reg.tx, [ quarter ]) ]
      @ List.concat_map bytes ~f:send
  ; sigrok =
      Some
        { clock_hz = 1_000_000_000 / Ps2.cycle_ns
        ; decoders =
            [ Sigrok.decoder "ps2" ~pins:[ "clk", Ps2.clock_pin; "data", Ps2.data_pin ] ]
        ; expect =
            [ ( "ps2=start-bit:word:parity-ok:stop-bit"
              , List.concat_map bytes ~f:(fun byte ->
                  [ "Start bit"; sprintf "Data: %02x" byte; "Parity OK"; "Stop bit" ])
                |> lines "ps2" )
            ; (* sigrok checks neither the start nor the stop bit, only labels them *)
              ( "ps2=bit"
              , List.concat_map bytes ~f:(fun byte ->
                  let data = List.init 8 ~f:(fun i -> (byte lsr i) land 1) in
                  let parity = 1 - (List.sum (module Int) data ~f:Fn.id % 2) in
                  (0 :: data) @ [ parity; 1 ])
                |> List.map ~f:Int.to_string
                |> lines "ps2" )
            ]
        ; joins_after = None
        ; rejected = None
        ; (* edge 2 is the first byte's fall at bit 5, three bits before its parity *)
          teeth =
            [ [ Flip
                  { pin = Ps2.data_pin
                  ; edge = 2
                  ; after = 12 * quarter
                  ; cycles = 4 * quarter
                  }
              ]
            ; (* edge 3 raises the first byte's stop bit: held low instead *)
              [ Flip { pin = Ps2.data_pin; edge = 3; after = 0; cycles = 4 * quarter } ]
            ]
        }
  }
;;

(* Reset, read the IDCODE, select USER and write it twice, the second scan shifting out
   the first value. *)
let jtag =
  let half_period = 10 in
  let scans =
    [ `Dr, 32, 0, Jtag.Tap.idcode
    ; `Ir, 4, 0x2, 0b0001 (* 1149.1: the two low bits capture 01 *)
    ; `Dr, 8, 0xa5, 0x00
    ; `Dr, 8, 0x3c, 0xa5
    ]
  in
  let clocks =
    Jtag.reset
    @ List.concat_map scans ~f:(fun (register, bits, tdi, _) ->
      match register with
      | `Dr -> Jtag.scan_dr ~bits tdi
      | `Ir -> Jtag.scan_ir ~bits tdi)
  in
  let bitstrings line value =
    List.map scans ~f:(fun ((register, bits, _, _) as scan) ->
      let value = value scan in
      sprintf
        "%s %s: %s (0x%x), %d bits"
        (match register with
         | `Dr -> "DR"
         | `Ir -> "IR")
        line
        (String.init bits ~f:(fun i ->
           if (value lsr (bits - 1 - i)) land 1 = 1 then '1' else '0'))
        value
        bits)
    |> lines "jtag"
  in
  let peer () =
    let tap = ref (Jtag.Tap.create ~cycle_ns:Jtag.cycle_ns) in
    { Peer.inputs = (fun () -> Jtag.Tap.tdo !tap lsl Jtag.tdo_pin)
    ; step =
        (fun ~pin_out ~pin_dir:_ ->
          tap
          := Jtag.Tap.step
               !tap
               ~tck:(Peer.bit pin_out Jtag.tck_pin)
               ~tms:(Peer.bit pin_out Jtag.tms_pin)
               ~tdi:(Peer.bit pin_out Jtag.tdi_pin))
    }
  in
  (* eight clocks a word *)
  let send words =
    [ Step.Write (Reg.tx, words)
    ; Run ((List.length words * 16 * half_period) + 200)
    ; Read (Reg.rx, List.length words)
    ]
  in
  { Scenario.name = "jtag"
  ; peer
  ; script =
      Scenario.load
        ~config:Jtag.config
        ~program:(Firmware.assemble (Jtag.firmware ~half_period))
      @ [ Scenario.start ]
      @ List.concat_map (List.chunks_of (Jtag.words clocks) ~length:4) ~f:send
  ; sigrok =
      Some
        { clock_hz = 1_000_000_000 / Jtag.cycle_ns
        ; decoders =
            [ Sigrok.decoder
                "jtag"
                ~pins:
                  [ "tdi", Jtag.tdi_pin
                  ; "tdo", Jtag.tdo_pin
                  ; "tck", Jtag.tck_pin
                  ; "tms", Jtag.tms_pin
                  ]
            ]
        ; expect =
            [ "jtag=bitstring-tdi", bitstrings "TDI" (fun (_, _, tdi, _) -> tdi)
            ; "jtag=bitstring-tdo", bitstrings "TDO" (fun (_, _, _, tdo) -> tdo)
            ]
        ; joins_after = None
        ; rejected = None
        ; (* a bit of the IDCODE inverted on TDO *)
          teeth =
            [ [ Flip { pin = Jtag.tdo_pin; edge = 0; after = 0; cycles = 2 * half_period }
              ]
            ]
        }
  }
;;

(* A low speed host on D+ and D-: each group of packets at its cycle, three bit times
   apart, and an ACK two bit times after the EOP of each data packet the device sends. *)
let low_speed_host groups () =
  let open Protocol_models.Usb_ls in
  let bit_period = Usb_host.bit_period in
  let dp = Firmware.usb_device_dp_pin
  and dm = Firmware.usb_device_dm_pin in
  let now = ref 0
  and pending = ref groups
  and lines = ref []
  and held = ref 0
  and line = ref Line.J
  and sniffer = ref (Sniffer.create ~bit_period)
  and seen = ref 0
  and device = ref false in
  let levels : Line.t -> int * int = function
    | J -> 0, 1
    | K -> 1, 0
    | Se0 -> 0, 0
  in
  let queue packets =
    List.map packets ~f:encode |> List.intersperse ~sep:[ Line.J; J; J ] |> List.concat
  in
  { Peer.inputs =
      (fun () ->
        let p, m = levels !line in
        (p lsl dp) lor (m lsl dm))
  ; step =
      (fun ~pin_out ~pin_dir ->
        let host_dp, host_dm = levels !line in
        let pin n level = if Peer.bit pin_dir n = 1 then Peer.bit pin_out n else level in
        if Peer.bit pin_dir dp = 1 then device := true;
        sniffer := Sniffer.step !sniffer ~dp:(pin dp host_dp) ~dm:(pin dm host_dm);
        let packets = Sniffer.packets !sniffer in
        if List.length packets > !seen
        then (
          seen := List.length packets;
          (match List.last packets with
           | Some (pid :: _) when !device && (pid = Usb_host.data0 || pid = Usb_host.data1)
             ->
             pending
             := List.sort
                  ((!now + (5 * bit_period), [ [ Usb_host.ack ] ]) :: !pending)
                  ~compare:(Comparable.lift Int.compare ~f:fst)
           | _ -> ());
          device := false);
        incr now;
        if !held > 1
        then decr held
        else (
          (match !pending with
           | (cycle, packets) :: rest when List.is_empty !lines && cycle <= !now ->
             pending := rest;
             lines := queue packets
           | _ -> ());
          match !lines with
          | next :: rest ->
            line := next;
            lines := rest;
            held := bit_period
          | [] ->
            line := J;
            held := 0))
  }
;;

(* The first request of an enumeration, GET_DESCRIPTOR for eight bytes of the device
   descriptor, then a mouse report on the interrupt endpoint, a pixel up and left, whose
   0xff bytes need stuff bits, and an IN with nothing queued, which gets a NAK. *)
let usb =
  let bit_period = Usb_host.bit_period in
  let address = 0 in
  let at bits = 120_000 + (bits * bit_period) in
  let setup = 0x2d
  and in_ = 0x69
  and out = 0xe1 in
  let token pid endpoint = Usb_host.token ~address ~pid ~endpoint in
  let get_descriptor = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x08; 0x00 ] in
  let descriptor = [ 0x12; 0x01; 0x10; 0x01; 0x00; 0x00; 0x00; 0x08 ] in
  let report = [ 0x02; 0x00; 0xff; 0xff ] in
  let packet name endpoint = sprintf "%s ADDR %d EP %d" name address endpoint in
  let data name payload =
    sprintf "%s [ %s]" name (String.concat (List.map payload ~f:(sprintf "%02X ")))
  in
  let hex bytes = String.concat (List.map bytes ~f:(sprintf " %02X")) in
  let host =
    [ at 0, [ token setup 0; Usb_host.data ~pid:Usb_host.data0 get_descriptor ]
    ; at 300, [ token in_ 0 ]
    ; at 600, [ token out 0; Usb_host.data ~pid:Usb_host.data1 [] ]
    ; at 900, [ token in_ 1 ]
    ; at 1200, [ token in_ 1 ]
    ]
  in
  { Scenario.name = "usb"
  ; peer = low_speed_host host
  ; script =
      Scenario.load
        ~config:Firmware.usb_device_config
        ~program:
          (Firmware.assemble (Firmware.usb_device ~address ~half_period:(bit_period / 2)))
      @ [ Write
            ( Reg.tx
            , bit_period :: Usb_host.reply ~endpoint:0 ~pid:Usb_host.data1 descriptor )
        ; Scenario.start
        ; Until (at 280)
        ; Read (Reg.rx, 7)
        ; Until (at 580)
        ; Read (Reg.rx, 1)
        ; Until (at 880)
        ; Read (Reg.rx, 3)
        ; Write (Reg.tx, Usb_host.reply ~endpoint:1 ~pid:Usb_host.data0 report)
        ; Until (at 1180)
        ; Read (Reg.rx, 1)
        ; Until (at 1400)
        ]
  ; sigrok =
      Some
        { clock_hz = 48_000_000
        ; decoders =
            [ String.concat
                ~sep:","
                [ Sigrok.decoder
                    "usb_signalling"
                    ~pins:
                      [ "dp", Firmware.usb_device_dp_pin
                      ; "dm", Firmware.usb_device_dm_pin
                      ]
                    ~options:[ "signalling", "low-speed" ]
                ; Sigrok.decoder "usb_packet" ~options:[ "signalling", "low-speed" ]
                ; Sigrok.decoder "usb_request"
                ]
            ]
        ; expect =
            [ ( (* every packet class, so one more of any kind is a difference *)
                [ "out"
                ; "in"
                ; "sof"
                ; "setup"
                ; "data0"
                ; "data1"
                ; "data2"
                ; "mdata"
                ; "ack"
                ; "nak"
                ; "stall"
                ; "nyet"
                ; "pre"
                ; "err"
                ; "split"
                ; "ping"
                ; "reserved"
                ; "invalid"
                ]
                |> List.map ~f:(( ^ ) "packet-")
                |> String.concat ~sep:":"
                |> ( ^ ) "usb_packet="
              , lines
                  "usb_packet"
                  [ packet "SETUP" 0
                  ; data "DATA0" get_descriptor
                  ; "ACK"
                  ; packet "IN" 0
                  ; data "DATA1" descriptor
                  ; "ACK"
                  ; packet "OUT" 0
                  ; data "DATA1" []
                  ; "ACK"
                  ; packet "IN" 1
                  ; data "DATA0" report
                  ; "ACK"
                  ; packet "IN" 1
                  ; "NAK"
                  ] )
            ; ( "usb_request"
              , lines
                  "usb_request"
                  [ sprintf
                      "SETUP in: [%s ][%s ] : ACK"
                      (hex get_descriptor)
                      (hex descriptor)
                  ; sprintf "BULK in: [%s ] : ACK" (hex report)
                  ] )
            ]
        ; joins_after = None
        ; rejected = None
        ; (* a bit time of the descriptor the device sends inverted on both lines, 46
             cycles past a K to J, edges 152 of D+ and 156 of D- *)
          teeth =
            [ [ Flip
                  { pin = Firmware.usb_device_dp_pin
                  ; edge = 152
                  ; after = 46
                  ; cycles = 32
                  }
              ; Flip
                  { pin = Firmware.usb_device_dm_pin
                  ; edge = 156
                  ; after = 46
                  ; cycles = 32
                  }
              ]
            ; (* the report's second stuff bit a bit time late, edges 349 of D+ and 357 of
                 D-: seven ones in a row *)
              [ Shift { pin = Firmware.usb_device_dp_pin; edge = 349; cycles = 32 }
              ; Shift { pin = Firmware.usb_device_dm_pin; edge = 357; cycles = 32 }
              ]
            ]
        }
  }
;;

let ws2812 =
  let pixel red green blue = { Ws2812.Pixel.red; green; blue } in
  let frames =
    [ [ pixel 0xff 0 0; pixel 0 0xff 0; pixel 0 0 0xff ]
    ; [ pixel 0x12 0x34 0x56; pixel 0xab 0xcd 0xef ]
    ]
  in
  (* a bit is 62 cycles, and 3200 low latch the string *)
  let send pixels =
    [ Step.Write (Reg.tx, List.concat_map pixels ~f:Ws2812.Pixel.words)
    ; Run ((List.length pixels * 24 * 62) + 3200 + 2000)
    ]
  in
  { Scenario.name = "ws2812"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load ~config:Ws2812.config ~program:(Firmware.assemble Ws2812.standard)
      @ [ Scenario.start ]
      @ List.concat_map frames ~f:send
  ; sigrok =
      Some
        { clock_hz = 48_000_000
        ; decoders = [ Sigrok.decoder "rgb_led_ws281x" ~pins:[ "din", Ws2812.pin ] ]
        ; expect =
            [ ( "rgb_led_ws281x=rgb:reset"
              , List.concat_map frames ~f:(fun pixels ->
                  List.map pixels ~f:(fun { red; green; blue } ->
                    sprintf "#%02x%02x%02x" red green blue)
                  @ [ "RESET" ])
                |> lines "rgb_led_ws281x" )
            ]
        ; joins_after = None
        ; rejected = None
        ; (* the first bit's high stretched from T0H to T1H *)
          teeth = [ [ Shift { pin = Ws2812.pin; edge = 1; cycles = 20 } ] ]
        }
  }
;;

(* An RP2040's two DPs woken from dormant and core 0 selected, then SWCLK held for 200 us
   before its DPIDR read, ABORT, CTRL/STAT powered up and read back, and its AP's IDR read
   through RDBUFF, which the AP is still busy for once, at 1 MHz. Each step waits for the
   core, which holds SWCLK high between host words. *)
let swd =
  let half = Swd.standard_half in
  let pause = 10_000 in
  let send words ~bits ~replies =
    [ Step.Write (Reg.tx, words); Run ((bits * 2 * half) + 200) ]
    @ if replies = 0 then [] else [ Step.Read (Reg.rx, replies) ]
  in
  let bits words =
    List.chunks_of words ~length:Machine.fifo_depth
    |> List.concat_map ~f:(fun chunk ->
      send chunk ~bits:(16 * List.length chunk) ~replies:0)
  in
  (* request, turnaround, ACK, turnaround, data, parity and eight idle cycles *)
  let transfer transfer =
    send
      (Swd.Transfer.words transfer)
      ~bits:(8 + 5 + 33 + 8)
      ~replies:(Swd.Transfer.replies transfer)
  in
  let read ?(ap = false) address = Swd.Transfer.Read { ap; address } in
  let write address value = Swd.Transfer.Write { ap = false; address; value } in
  (* each transfer as sigrok names it, its ACK and the data the DP has for it *)
  let transfers =
    [ read 0x0, "IDCODE", Some Swd.rp2040_dpidr
    ; write 0x0 0x1c, "W ABORT", Some 0x1c
    ; write 0x4 0x5000_0000, "W CTRL/STAT", Some 0x5000_0000
    ; read 0x4, "R CTRL/STAT", Some 0xf000_0000
    ; write 0x8 0xf0, "W SELECT", Some 0xf0
    ; read ~ap:true 0xc, "R APc", Some 0
    ; read 0xc, "RDBUFF", None
    ; read 0xc, "RDBUFF", Some 0x0477_0031
    ; write 0x8 0, "W SELECT", Some 0
    ]
  in
  let peer () =
    let bus =
      ref
        (Swd.Bus.create
           (List.map [ Swd.rp2040_core0; Swd.rp2040_core1 ] ~f:(fun targetid ->
              Swd.Dp.create
                ~ap_latency:60
                ~cycle_ns:Swd.cycle_ns
                ~dpidr:Swd.rp2040_dpidr
                ~targetid
                ())))
    in
    { Peer.inputs = (fun () -> Swd.Bus.inputs !bus)
    ; step = (fun ~pin_out ~pin_dir -> bus := Swd.Bus.step !bus ~pin_out ~pin_dir)
    }
  in
  { Scenario.name = "swd"
  ; peer
  ; script =
      Scenario.load
        ~config:(Timed_program.config Swd.firmware)
        ~program:(Timed_program.words Swd.firmware)
      @ [ Scenario.start; Write (Reg.tx, [ half ]); Run 200; Read (Reg.rx, 1) ]
      @ bits Swd.dormant_to_swd
      @ bits Swd.line_reset
      @ transfer (Targetsel Swd.rp2040_core0)
      @ [ Step.Run pause ]
      @ List.concat_map transfers ~f:(fun (t, _, _) -> transfer t)
  ; sigrok =
      Some
        { clock_hz = 1_000_000_000 / Swd.cycle_ns
        ; decoders =
            [ Sigrok.decoder
                "swd"
                ~pins:[ "swclk", Swd.swclk_pin; "swdio", Swd.swdio_pin ]
            ]
        ; expect =
            [ ( "swd=read:write:ack:data"
              , List.concat_map transfers ~f:(fun (_, name, data) ->
                  match data with
                  | Some data -> [ name; "OK"; sprintf "0x%08x" data ]
                  | None -> [ name; "WAIT" ])
                |> lines "swd" )
            ]
        ; joins_after =
            Some
              ( pause * 4 / 5
              , { why =
                    "sigrok 0.5.3's swd decoder knows SWD protocol version 1 only: it \
                     reads requests into the selection alert's bits, and into \
                     TARGETSEL's data"
                ; first_difference = 0
                ; reads = "swd-1: R APc"
                } )
        ; rejected = None
        ; (* edge 99 starts RDATA[0] of the DPIDR read: inverted for its bit *)
          teeth =
            [ [ Flip { pin = Swd.swdio_pin; edge = 99; after = 0; cycles = 2 * half } ] ]
        }
  }
;;

(* The chip-select master in [mode] at 3 MHz against a slave of that mode, three frames:
   sigrok frames each transfer by CS. The decoders join once CS has been high a while. *)
let spi_cs mode =
  let half_period = 8 in
  let frames = [ [ 0x9f; 0x00; 0x00; 0x00 ]; [ 0xa5 ]; [ 0x3c; 0xc3 ] ] in
  let replies frame =
    0x5a :: List.map (List.drop_last_exn frame) ~f:(fun byte -> lnot byte land 0xff)
  in
  let peer () =
    let device = ref (Spi_cs.Device.create ~mode ~first:0x5a) in
    { Peer.inputs = (fun () -> Spi_cs.Device.miso !device lsl Spi_cs.miso_pin)
    ; step =
        (fun ~pin_out ~pin_dir:_ ->
          device
          := Spi_cs.Device.step
               !device
               ~cs:(Peer.bit pin_out Spi_cs.cs_pin)
               ~sck:(Peer.bit pin_out Spi_cs.sck_pin)
               ~mosi:(Peer.bit pin_out Spi_cs.mosi_pin))
    }
  in
  let send frame =
    [ Step.Write (Reg.tx, Spi_cs.words frame)
    ; Run ((List.length frame * 20 * half_period) + 200)
    ; Read (Reg.rx, List.length frame)
    ]
  in
  let transfers bytes =
    lines
      "spi"
      (List.map bytes ~f:(fun b ->
         String.concat ~sep:" " (List.map b ~f:(sprintf "%02X"))))
  in
  { Scenario.name = [%string "spi_mode%{Spi_cs.Mode.to_int mode#Int}"]
  ; peer
  ; script =
      Scenario.load
        ~config:Spi_cs.config
        ~program:
          (Firmware.assemble
             (Spi_cs.master ~mode ~half_period ~setup:4 ~hold:8 ~deselect:0))
      @ [ Scenario.start; Run 200 ]
      @ List.concat_map frames ~f:send
  ; sigrok =
      Some
        { clock_hz = 48_000_000
        ; decoders =
            [ Sigrok.decoder
                "spi"
                ~pins:
                  [ "cs", Spi_cs.cs_pin
                  ; "clk", Spi_cs.sck_pin
                  ; "mosi", Spi_cs.mosi_pin
                  ; "miso", Spi_cs.miso_pin
                  ]
                ~options:
                  [ "cpol", Int.to_string (Bool.to_int mode.cpol)
                  ; "cpha", Int.to_string (Bool.to_int mode.cpha)
                  ]
            ]
        ; expect =
            [ "spi=mosi-transfer", transfers frames
            ; "spi=miso-transfer", transfers (List.map frames ~f:replies)
            ]
        ; joins_after =
            Some
              ( 100
              , { why =
                    "CS is low from reset until the firmware starts, which sigrok reads \
                     as a transfer with no bytes"
                ; first_difference = 0
                ; reads = "spi-1: "
                } )
        ; rejected = None
        ; (* The first bit inverted, and the first frame's CS rise moved two bits early *)
          teeth =
            [ [ Flip
                  { pin = Spi_cs.mosi_pin; edge = 0; after = 0; cycles = 2 * half_period }
              ]
            ; [ Shift { pin = Spi_cs.cs_pin; edge = 2; cycles = -4 * half_period } ]
            ]
        }
  }
;;

let all =
  [ can; can_remote; cec; one_wire; ps2; jtag; usb; ws2812; swd ]
  @ List.map Spi_cs.Mode.all ~f:spi_cs
;;
