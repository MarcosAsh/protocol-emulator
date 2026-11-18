open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* MMA CA-033, MIDI 1.0 Electrical Specification Update (issued 1 August 2014), page 2 of
   6, "Hardware": 31.25 kbaud +-1%, a start bit, 8 data bits LSB first and a stop bit, 10
   bits and 320 us a byte. A bit is 1536 cycles at 48 MHz. *)
let pin = 5
let period = 48_000_000 / 31_250

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  }
;;

(* The bit in cycles, once, then a word a byte. *)
let firmware =
  [%firmware
    {|
    set pins, 1              ; idle high
    wait tx
    pull
    mov p, osr
idle:
    wait tx
    pull
    set x, 7
    mov t, now
    set pins, 0              ; start bit
    add t, p
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1              ; stop bit
    wait t
    jmp idle
|}
      ~config
      ~period]
;;

(* [wait tx] can hold the core indefinitely, far behind its last deadline *)
let certified = [ Certified.of_firmware ~no_wrap:true "midi" firmware ]

(* a note on, a second note under running status, a note off, a program change and the
   volume controller *)
let messages =
  [ [ 0x90; 0x3c; 0x40 ]
  ; [ 0x3e; 0x40 ]
  ; [ 0x80; 0x3c; 0x00 ]
  ; [ 0xc0; 0x05 ]
  ; [ 0xb0; 0x07; 0x64 ]
  ]
;;

(* Every low is one bit: 0x55 alternates. *)
let bench =
  { Bench.name = "midi"
  ; what =
      [%string
        "Midi.firmware: the host sends the bit, %{period#Int} cycles for 31.25 kbaud, \
         then bytes on OUT0"]
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Period period
  ; clock_hz = Bench.clock_hz
  ; load = Some period
  ; stimulus = Some { bursts = [ [ 0x55; 0x55 ] ]; quiet = 0; cycles = 25 * period }
  }
;;

let limits =
  let sheet =
    { Datasheet.Sheet.part = "MIDI 1.0"
    ; document =
        "MMA, CA-033 MIDI 1.0 Electrical Specification Update, issued 1 August 2014"
    ; page = "page 2, Hardware"
    }
  in
  let row parameter limit bound =
    { Datasheet.firmware = bench.name; parameter; limit; sheet; margin = Cycle; bound }
  in
  (* 31.25 kbaud plus and less 1% *)
  [ row
      "bit at 31.25 kbaud +1%"
      (At_least (1e9 /. (31_250. *. 1.01)))
      (Datasheet.level ~pin:Datasheet.set_pin ~high:false ())
  ; row
      "bit at 31.25 kbaud -1%"
      (At_most (1e9 /. (31_250. *. 0.99)))
      (Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz:_ levels ->
         Datasheet.lows levels))
  ]
;;

(* sigrok's midi on its uart at 31250 baud, 8N1. It prints a line a message, and expands
   the status the second note leaves out. The program and controller names are its own.
   The teeth flip the first byte's bit 4, so 0x90 reads 0x80, and the first byte's stop
   bit, a framing error. *)
let sigrok =
  let names = [| "C"; "C#"; "D"; "D#"; "E"; "F"; "F#"; "G"; "G#"; "A"; "A#"; "B" |] in
  let note n = sprintf "note = %d '%s%d'" n names.(n % 12) ((n / 12) - 1) in
  let line = sprintf "midi-1: Channel 1: %s" in
  { Sigrok.clock_hz = 48_000_000
  ; decoders =
      [ Sigrok.decoder "uart" ~pins:[ "tx", pin ] ~options:[ "baudrate", "31250" ]
        ^ ","
        ^ Sigrok.decoder "midi"
      ]
  ; expect =
      [ "uart=tx-data", List.map (List.concat messages) ~f:(sprintf "uart-1: %02X")
      ; ( "midi=text-verbose"
        , [ line (sprintf "note on (%s, velocity = 64)" (note 0x3c))
          ; line (sprintf "note on (%s, velocity = 64)" (note 0x3e))
          ; line (sprintf "note off (%s, velocity = 0)" (note 0x3c))
          ; line "program change to instrument 6 (assuming Electric Piano 2)"
          ; line
              "control change 'channel volume MSB (formerly main volume)' (param = 0x64)"
          ] )
      ]
  ; joins_after = None
  ; rejected = None
  ; teeth =
      [ [ Flip { pin; edge = 2; after = 0; cycles = period } ]
      ; [ Flip { pin; edge = 4; after = period; cycles = period } ]
      ]
  }
;;

let scenario =
  { Scenario.name = "midi"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ [ Scenario.start
        ; Write (Reg.tx, period :: List.concat messages)
        ; Run (14 * 10 * period)
        ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "midi"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept = [ "midi", "a byte waits on the host, so there is no fixed edge to stamp" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
