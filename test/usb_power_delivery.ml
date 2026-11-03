open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* USB Power Delivery Specification r3.2 v1.2, Aug 2026: packet format (Figure 5.1 p.88,
   5.3.1.1 p.89-90), BMC (5.3.3 p.95, 5.3.4 p.96), the transmitter's timing (Tables 5.9
   and 5.10 p.110). OUT0 is the BMC level on CC: high while driving vSwing, low while
   driving low or released, as the line has no third state here. *)

let pin = 5

(* 300 kbps at 48 MHz: 160 cycles a bit, four waits of [p] a half *)
let bit_cycles = 160

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  ; autopull = true
  ; pull_threshold = 16
  }
;;

(* The host's first word is the line bits after the preamble less one, then the bits, 16 a
   word, first bit in bit 0. The firmware sends 26.7 us of low (tInterFrameGap), the
   preamble, the bits in BMC, and the trailing edge of 5.3.4 p.96 rules 4-6. The level is
   in the program counter: [low] and [high] start a bit from that level, so every edge is
   a [set]. *)
let firmware =
  [%firmware
    {|
    set pins, 0              ; released
    set p, 20
frame:
    wait tx
    pull
    mov y, osr               ; line bits less one
    out null, 16             ; the next out pulls the first of them
    mov t, now
    add t, p
    set x, 31
gap:
    wait t+
    wait t+
    jmp x--, gap
    set x, 15                ; the preamble, 0101 sixteen times, low to low
preamble:
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 1
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 0
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 1
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 0
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 1
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 0
    jmp x--, preamble
    jmp low_next
high_next:
    out x, 1
high:
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 0              ; the bit's start
    jmp x--, high_one
    wait t+
    wait t+
    wait t+
    wait t+
    jmp y--, low_next
    jmp end_low
high_one:
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 1              ; a one's middle
    jmp y--, high_next
    jmp end_high
low_next:
    out x, 1
low:
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 1              ; the bit's start
    jmp x--, low_one
    wait t+
    wait t+
    wait t+
    wait t+
    jmp y--, high_next
    jmp end_high
low_one:
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 0              ; a one's middle
    jmp y--, low_next
end_low:
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 1              ; the trailing edge, then high a UI
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 0              ; low, tHoldLowBMC and on
    jmp frame
end_high:
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 0              ; the trailing edge
    jmp frame
|}
      ~config]
;;

(* The period is a constant in the firmware, so the certificate assumes nothing. *)
let certified = [ Certified.of_firmware "usb_power_delivery" firmware ]

(* Table 5.2 p.89: the 5b symbol of each nibble, b0 first on the line *)
let data_symbols =
  [| 0b11110
   ; 0b01001
   ; 0b10100
   ; 0b10101
   ; 0b01010
   ; 0b01011
   ; 0b01110
   ; 0b01111
   ; 0b10010
   ; 0b10011
   ; 0b10110
   ; 0b10111
   ; 0b11010
   ; 0b11011
   ; 0b11100
   ; 0b11101
  |]
;;

let sync_1 = 0b11000
let sync_2 = 0b10001
let eop = 0b01101

module Message = struct
  type t =
    { header : int
    ; data_objects : int list
    }
  [@@deriving sexp_of, compare, equal]

  (* Table 6.2 p.117: Revision 3.x, a Source and DFP; type 00001b, Table 6.5 p.125 *)
  let source_capabilities ~message_id data_objects =
    { header =
        (List.length data_objects lsl 12)
        lor (message_id lsl 9)
        lor (1 lsl 8)
        lor (0b10 lsl 6)
        lor (1 lsl 5)
        lor 0b00001
    ; data_objects
    }
  ;;

  (* Table 6.8 p.127-128: 5 V in 50 mV units, 3 A in 10 mA units *)
  let fixed_5v_3a = (100 lsl 10) lor 300

  let payload { header; data_objects } =
    let little ~bytes n = List.init bytes ~f:(fun i -> (n lsr (8 * i)) land 0xff) in
    little ~bytes:2 header @ List.concat_map data_objects ~f:(little ~bytes:4)
  ;;

  (* 5.3.1.1.4 p.90: the CRC-32 of USB3 and Ethernet, sent LSB first *)
  let crc t = Ethernet.Frame.crc32 (payload t)

  (* Figure 5.1 p.88: SOP, then payload and CRC low nibble first, then EOP *)
  let symbols t =
    let crc = crc t in
    let bytes = payload t @ List.init 4 ~f:(fun i -> (crc lsr (8 * i)) land 0xff) in
    [ sync_1; sync_1; sync_1; sync_2 ]
    @ List.concat_map bytes ~f:(fun byte ->
      [ data_symbols.(byte land 0xf); data_symbols.(byte lsr 4) ])
    @ [ eop ]
  ;;

  let line_bits t =
    List.concat_map (symbols t) ~f:(fun symbol ->
      List.init 5 ~f:(fun i -> (symbol lsr i) land 1))
  ;;

  let words t =
    let bits = line_bits t in
    (List.length bits - 1)
    :: List.map (List.chunks_of bits ~length:16) ~f:(fun chunk ->
      List.foldi chunk ~init:0 ~f:(fun i word bit -> word lor (bit lsl i)))
  ;;

  (* the gap, the preamble, the bits and at most two UI of trailing edge *)
  let cycles t = (64 * 20) + 100 + ((64 + List.length (line_bits t) + 2) * bit_cycles)
end

let sent =
  [ Message.source_capabilities ~message_id:0 [ Message.fixed_5v_3a ]
  ; Message.source_capabilities ~message_id:1 [ Message.fixed_5v_3a ]
  ]
;;

let bench =
  { Bench.name = "usb_power_delivery"
  ; what =
      "Usb_power_delivery.firmware: USB PD packets in BMC at 300 kbps, the line on OUT0"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus =
      Some
        { bursts = List.map sent ~f:Message.words
        ; quiet = 0
        ; cycles = List.sum (module Int) sent ~f:Message.cycles + 2_000
        }
  }
;;

(* Each packet's bit cells in cycles: a level under 2.5 us, 3/4 UI, is a half and pairs
   with the next, a longer one is a whole cell, a low past 5 us is idle. *)
let cells ~clock_hz levels =
  let ns n = n * 1_000_000_000 / clock_hz in
  let idle (high, n) = (not high) && ns n > 5_000 in
  let rec packet cells = function
    | [] -> List.rev cells, []
    | run :: rest when idle run -> List.rev cells, rest
    | (_, a) :: ((_, b) as next) :: rest when ns a < 2_500 && not (idle next) ->
      packet ((a + b) :: cells) rest
    | (_, n) :: rest -> packet (n :: cells) rest
  in
  let rec packets acc = function
    | [] -> List.rev acc
    | run :: rest when idle run -> packets acc rest
    | levels ->
      let cells, rest = packet [] levels in
      packets (cells :: acc) rest
  in
  packets [] levels
;;

(* Tables 5.9 and 5.10, p.110, the transmitter's. Not here: tStartDrive and tEndDriveBMC,
   as OUT0 has no third state to start or stop driving from; tRise and tFall, the slew of
   the driver or an RC after it (5.3.4 rule 1, p.96). *)
let limits =
  let sheet page =
    { Datasheet.Sheet.part = "USB PD BMC transmitter"
    ; document = "USB Power Delivery Specification r3.2 v1.2, Aug 2026"
    ; page
    }
  in
  let limit parameter limit page bound =
    { Datasheet.firmware = bench.name
    ; parameter
    ; limit
    ; sheet = sheet page
    ; margin = Cycle
    ; bound
    }
  in
  let every_cell =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.concat (cells ~clock_hz levels))
  in
  (* each window of 32 bits from the preamble's last on, against the preamble's last 32 *)
  let drift =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.concat_map (cells ~clock_hz levels) ~f:(fun cells ->
        let cells = Array.of_list cells in
        let sum ~last =
          Array.sub cells ~pos:(last - 31) ~len:32 |> Array.sum (module Int) ~f:Fn.id
        in
        if Array.length cells < 64
        then []
        else (
          let reference = sum ~last:63 in
          List.range 64 (Array.length cells)
          |> List.map ~f:(fun last -> abs (sum ~last - reference)))))
  in
  let gaps =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter (Datasheet.lows levels) ~f:(fun n ->
        n * 1_000_000_000 / clock_hz > 5_000))
  in
  let table_9 = "Table 5.9, p.110"
  and table_10 = "Table 5.10, p.110" in
  [ limit
      "fBitRate max 330 kbps: each bit cell"
      (At_least (1e6 /. 330.))
      table_9
      every_cell
  ; limit
      "fBitRate min 270 kbps: each bit cell"
      (At_most (1e6 /. 270.))
      table_9
      every_cell
  ; limit "tUnitInterval min" (At_least 3_030.) table_9 every_cell
  ; limit "tUnitInterval max" (At_most 3_700.) table_9 every_cell
  ; limit
      "pBitRate 0.25 %: 32 bits against the preamble's last 32, of 32 UI at 300 kbps"
      (At_most (0.0025 *. 32. *. (1e6 /. 300.)))
      (table_10 ^ ", and 5.3.4.8 p.108; 300 kbps nominal, Table 5.9")
      drift
  ; limit
      "tHoldLowBMC: every low"
      (At_least 1_000.)
      table_10
      (Datasheet.level ~pin:Datasheet.set_pin ~high:false ())
  ; limit "tInterFrameGap: each idle low" (At_least 25_000.) table_10 gaps
  ]
;;

(* What sigrok's usb_power_delivery prints for a Source_Capabilities of Fixed 5 V 3 A
   PDOs: each symbol, then each field it ends; the EOP comes as a symbol and a part. *)
let reading ({ Message.header; data_objects } as message) =
  let nibbles n ~count =
    List.init count ~f:(fun i -> sprintf "0x%X" ((n lsr (4 * i)) land 0xf))
  in
  [ "Preamble"; "SYNC-1"; "SYNC-1"; "SYNC-1"; "SYNC-2"; "SOP" ]
  @ nibbles header ~count:4
  @ [ sprintf "H:%04x" header
    ; sprintf "(r3) SRC[%d]: SOURCE CAP" ((header lsr 9) land 7)
    ]
  @ List.concat_mapi data_objects ~f:(fun i pdo ->
    nibbles pdo ~count:8
    @ [ sprintf "[%d]%08x" i pdo; sprintf "[%d] [Fixed] 5V 3A (15W)" (i + 1) ])
  @ nibbles (Message.crc message) ~count:8
  @ [ sprintf "CRC:%08x" (Message.crc message); "EOP"; "EOP" ]
;;

(* The pin inverted for 80 cycles from 40 into a line bit: a stray half bit. Edges count
   from the preamble's first, 96 of them, then one a bit and one more a 1. *)
let glitch message ~bit =
  let bits = Message.line_bits message in
  let edge = 96 + List.sum (module Int) (List.take bits bit) ~f:(fun b -> 1 + b) in
  [ Sigrok.Corruption.Flip { pin; edge; after = 40; cycles = 80 } ]
;;

let sigrok =
  let message = List.hd_exn sent in
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "usb_power_delivery" ~pins:[ "cc1", pin ] ]
  ; expect =
      [ ( "usb_power_delivery=preamble:sop:header:data:crc:eop:sym:warnings:src:payload"
        , reading message |> Sigrok.lines "usb_power_delivery" )
      ]
  ; joins_after = None
  ; rejected = None
  ; (* in the header, the PDO and the CRC *)
    teeth = List.map [ 22; 50; 90 ] ~f:(fun bit -> glitch message ~bit)
  }
;;

(* One Source_Capabilities. sigrok's decoder ends a packet only after 1 ms of quiet, so
   the run goes on 1.2 ms past it. *)
let scenario =
  let message = List.hd_exn sent in
  { Scenario.name = "usb_power_delivery"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ [ Scenario.start
        ; Write (Reg.tx, Message.words message)
        ; Run (Message.cycles message + 57_600)
        ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "usb_power_delivery"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "usb_power_delivery"
        , "the host computes each packet's CRC-32, which a stamp the engine put in would \
           break" )
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
