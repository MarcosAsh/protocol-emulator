open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* DMX512, Wikipedia oldid 1380777110, one page; numbers are its line numbers. 250 kbit/s,
   a slot is a start bit, 8 bits LSB first and two stop bits (line 291). A packet is a
   break, a mark after break, the start code and 512 channels (lines 292-297), the timing
   table at lines 303-310. Bits of 192 cycles at 48 MHz. *)
let pin = 5

(* The analyser takes [add p, p] for a load, so the four instructions that make it are
   given as the period they make. *)
let period = 24 * 8

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  }
;;

(* A packet a host word with the start code in its low byte, then 256 words of two
   channels, low byte first. Break 25 bits (100 us), mark after break 4 (16 us). A late
   word stretches the mark before a channel's start bit, which the spec leaves free (line
   311). *)
let firmware =
  [%firmware
    {|
    set p, 24
    add p, p
    add p, p
    add p, p                 ; a bit, 192 cycles
    set pins, 1              ; mark while idle
packet:
    wait tx                  ; the start code's word
    pull
    mov t, now
    set pins, 0              ; break
    add t, p
    set x, 23
break:
    wait t+
    jmp x--, break
    wait t+
    set pins, 1              ; mark after break
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 0              ; the start code's start bit
    set x, 7
code:
    wait t+
    out pins, 1
    jmp x--, code
    wait t+
    set pins, 1              ; two stop bits
    out null, 8              ; the word's high byte is not sent
    set y, 16
    add y, y
    add y, y
    add y, y
    add y, y
    add y, y
    sub y, 1                 ; 512 channels
    wait t+
    wait t
channel:
    jmp !osre, slot          ; the word's second channel
    wait tx
    pull
slot:
    mov t, now
    set pins, 0              ; start bit
    add t, p
    set x, 7
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1              ; two stop bits
    wait t+
    wait t
    jmp y--, channel
    jmp packet
|}
      ~config
      ~period]
;;

(* TODO the certificates, under the assumptions [%firmware] checked: give ~period, the
   period the host loads, to firmware checked at a ~period_floor, and ~no_wrap:true where
   a wait can fall far behind, as a receiver's can *)
let certified = [ Certified.of_firmware "dmx512" firmware ]

(* TODO the copy python/bench_firmware.py holds for the bench, at its clock, with a run
   long enough to bound [limits]; for a period the host loads, [Floor] the least and
   [load] the one the bench loads *)
let bench =
  { Bench.name = "dmx512"
  ; what = "Dmx512.firmware: TODO what the bench sees, on OUT0"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus = Some { bursts = [ [ 0x55 ] ]; quiet = 0; cycles = 400 }
  }
;;

(* TODO a row for each parameter of the spec's timing table, then [unlimited] empty. Each
   is bounded by the kernel over every path, [Datasheet.level] or [Datasheet.spacing], or
   by [bench]'s run, [Datasheet.run], which a loop of waits needs as the kernel counts one
   pass of it. For example
   { Datasheet.firmware = bench.name
   ; parameter = "tLOW"
   ; limit = At_least 4700.
   ; sheet = { part = "I2C"; document = "NXP UM10204 Rev. 7.0"; page = "Table 11, p.44" }
   ; margin = Cycle
   ; bound = Datasheet.level ~pin:Datasheet.set_pin ~high:false ()
   } *)
let limits : Datasheet.t list = []

(* TODO what sigrok's dmx512 decoder reads. demo/decode.py --show test/traces/dmx512.trace
   prints every line it reads, by class, to fill [expect] with. Its channels: dmx;
   optional: none; options: none; classes: bit, break, mab, startbit, stopbits, startcode,
   channel, interframe, interpacket, data, error. Each of [teeth] changes the waveform so
   the decoders have to misread it. *)
let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "dmx512" ~pins:[ "dmx", pin ] ]
  ; expect = []
  ; joins_after = None
  ; rejected = None
  ; teeth = []
  }
;;

(* TODO a run at the pins: the host's words, and in [peer] a model of the far end if it
   answers *)
let scenario =
  { Scenario.name = "dmx512"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Write (Reg.tx, [ 0x55; 0xa3 ]); Scenario.start; Run 600 ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "dmx512"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = [ "dmx512", "TODO the rows of the spec's timing table" ]
  ; swept = []
  ; not_swept = [ "dmx512", "TODO why the sweep does not stamp it, or a Swept.t" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
