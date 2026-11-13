open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* MODBUS over Serial Line Specification and Implementation Guide V1.02 (Modbus.org, 20
   December 2006): the RTU character of 11 bits with even parity as the default, section
   2.5.1 (p.12); frames separated by 3.5 character times and no gap over 1.5 inside one,
   section 2.5.1.1 (p.13); CRC-16 with the low byte first, section 2.5.1.2 (p.14). 19200
   baud is the required default (section 3.2, p.20) and a bit is 2500 cycles at 48 MHz. *)
let pin = 5
let period = 48_000_000 / 19_200

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  }
;;

(* The bit in cycles, once. Then per frame a word with its characters less one, and a word
   a character: the byte and, in bit 8, its parity bit, sent LSB first. The wait before a
   frame is 39 bits, over the 38.5 that 3.5 characters are. *)
let firmware =
  [%firmware
    {|
    set pins, 1              ; idle high
    wait tx
    pull
    mov p, osr
frame:
    wait tx
    pull
    mov y, osr               ; characters, less one
    mov t, now
    add t, p
    set x, 18
silence:
    wait t+
    wait t+
    jmp x--, silence         ; 38 bits
    wait t+
char:
    wait tx
    pull
    mov t, now
    set pins, 0              ; start bit
    add t, p
    set x, 8
bit:
    wait t+
    out pins, 1              ; the byte, then its parity bit
    jmp x--, bit
    wait t+
    set pins, 1              ; stop bit
    wait t
    jmp y--, char
    jmp frame
|}
      ~config
      ~period]
;;

(* [wait tx] can hold the core indefinitely, far behind its last deadline *)
let certified = [ Certified.of_firmware ~no_wrap:true "modbus_rtu" firmware ]

(* 2.5.1.2: the register starts at all ones and takes each byte's bits LSB first *)
let crc bytes =
  List.fold bytes ~init:0xffff ~f:(fun crc byte ->
    List.fold (List.range 0 8) ~init:crc ~f:(fun crc i ->
      Crc.step ~width:16 ~poly:0xa001 ~reflect:true crc ~bit:((byte lsr i) land 1)))
;;

let frame bytes =
  let bytes = bytes @ [ crc bytes land 0xff; crc bytes lsr 8 ] in
  (List.length bytes - 1)
  :: List.map bytes ~f:(fun byte -> byte lor ((Int.popcount byte land 1) lsl 8))
;;

(* read 10 holding registers from server 1 from address 0, write register 1 of server 17 *)
let requests =
  [ [ 0x01; 0x03; 0x00; 0x00; 0x00; 0x0a ]; [ 0x11; 0x06; 0x00; 0x01; 0x00; 0x03 ] ]
;;

let bench =
  { Bench.name = "modbus_rtu"
  ; what =
      [%string
        "Modbus_rtu.firmware: the host sends the bit, %{period#Int} cycles for 19200 \
         baud, then frames, on OUT0: 8E1 characters, 3.5 characters of silence before \
         each frame"]
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Period period
  ; clock_hz = Bench.clock_hz
  ; load = Some period
  ; stimulus =
      Some { bursts = [ List.concat_map requests ~f:frame ]; quiet = 0; cycles = 700_000 }
  }
;;

(* The gaps between characters in the run, from one character's end, 11 bits after its
   start edge, to the next start edge. The first is from the run's start. A gap of two
   characters or more is between frames. *)
let gaps ~clock_hz levels =
  let character = 11 * clock_hz / 19_200 in
  let _, _, gaps =
    List.fold levels ~init:(0, 0, []) ~f:(fun (at, ends, gaps) (high, n) ->
      let gaps =
        if (not high) && at >= ends && at > 0 then (at - ends) :: gaps else gaps
      in
      let ends = if (not high) && at >= ends && at > 0 then at + character else ends in
      at + n, ends, gaps)
  in
  List.rev gaps
;;

let limits =
  let sheet page =
    { Datasheet.Sheet.part = "MODBUS RTU"
    ; document =
        "Modbus.org, MODBUS over Serial Line Specification and Implementation Guide \
         V1.02, 20 December 2006"
    ; page
    }
  in
  let between ~inside ~clock_hz levels =
    List.filter (gaps ~clock_hz levels) ~f:(fun gap ->
      inside (gap > 2 * 11 * clock_hz / 19_200))
  in
  let row parameter ~page limit bound =
    { Datasheet.firmware = bench.name
    ; parameter
    ; limit
    ; sheet = sheet page
    ; margin = Cycle
    ; bound
    }
  in
  let run widths = Datasheet.run ~pin:Datasheet.set_pin widths in
  (* 11 bits a character at 19200 baud: 1.5 of them are 859375 ns, 3.5 are 2005208 ns *)
  [ row
      "silent interval between frames, t3,5"
      ~page:"2.5.1.1, p.13"
      (At_least (3.5 *. 11. *. 1e9 /. 19_200.))
      (run (between ~inside:Fn.id))
  ; row
      "silent interval between characters of a frame, t1,5"
      ~page:"2.5.1.1, p.13"
      (At_most (1.5 *. 11. *. 1e9 /. 19_200.))
      (run (between ~inside:not))
  ]
;;

(* sigrok's modbus stacks on its uart at 19200 baud with even parity, reading the client's
   frames on TX. It shows each frame's server, function, fields and CRC, and a frame under
   its 28-bit gap (framegap) is one with the one before. The teeth flip the first data bit
   of the first frame, so its parity fails, and pull the second frame in by 25 bits. *)
let sigrok =
  let hex byte = sprintf "uart-1: %02X" byte in
  let frames =
    List.map requests ~f:(fun bytes ->
      let crc = crc bytes in
      bytes @ [ crc land 0xff; crc lsr 8 ])
  in
  let line = sprintf "modbus-1: %s" in
  let fields = function
    | [ server; 0x03; hi; lo; count_hi; count_lo ] ->
      let address = (hi lsl 8) lor lo in
      [ line (sprintf "Slave ID: %d" server)
      ; line "Function 3: Read Holding Registers"
      ; line (sprintf "Start at address 0x%X / %d" address (address + 30001))
      ; line (sprintf "Read %d units of data" ((count_hi lsl 8) lor count_lo))
      ; line "CRC correct"
      ]
    | [ server; 0x06; hi; lo; value_hi; value_lo ] ->
      let address = (hi lsl 8) lor lo
      and value = (value_hi lsl 8) lor value_lo in
      [ line (sprintf "Slave ID: %d" server)
      ; line "Function 6: Write Single Register"
      ; line (sprintf "Address 0x%X / %d" address (address + 30000))
      ; line (sprintf "Register Value 0x%X / %d" value value)
      ; line "CRC correct"
      ]
    | bytes -> raise_s [%message "BUG: no fields for" (bytes : int list)]
  in
  { Sigrok.clock_hz = 48_000_000
  ; decoders =
      [ Sigrok.decoder
          "uart"
          ~pins:[ "tx", pin ]
          ~options:[ "baudrate", "19200"; "parity", "even" ]
        ^ ","
        ^ Sigrok.decoder "modbus"
      ]
  ; expect =
      [ "uart=tx-data", List.concat_map frames ~f:(List.map ~f:hex)
      ; ( "modbus=cs-server-id:cs-function:cs-crc:cs-address:cs-data:cs-length"
        , List.concat_map requests ~f:fields )
      ]
  ; joins_after = None
  ; rejected = None
  ; teeth =
      [ [ Flip { pin; edge = 2; after = 0; cycles = period } ]
      ; [ Shift { pin; edge = 35; cycles = -25 * period } ]
      ]
  }
;;

(* The bit, then a frame, and the second once the first is out. *)
let scenario =
  let frame_cycles = 330_000 in
  { Scenario.name = "modbus_rtu"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ List.concat
          [ [ Scenario.start; Write (Reg.tx, period :: frame (List.nth_exn requests 0)) ]
          ; [ Run frame_cycles ]
          ; [ Write (Reg.tx, frame (List.nth_exn requests 1)); Run frame_cycles ]
          ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "modbus_rtu"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "modbus_rtu"
        , "a frame is 127 bits of 2500 cycles, past the 65536 a stamp tells apart" )
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
