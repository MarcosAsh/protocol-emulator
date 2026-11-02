open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* S/PDIF, Wikipedia revision 1378032122 (2 October 2026), one page, read as the limit
   table spec.txt: biphase mark (l.171, l.179), 192 frames a block of two subframes
   (l.256), 44.1 kHz at code 0000 (l.222). The subframe's 32 slots, preambles B M W and V
   U C P are sigrok's spdif decoder's, which the page does not give. *)

let pin = 5

(* Readback of the line makes the transitions, so [in_base] is the line too. Half a slot
   is 8 32991/65536 cycles: 128 a frame at 48 MHz is 44.1 kHz. *)
let config =
  { Program_config.default with
    in_base = pin
  ; out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  ; period_fraction = 32991
  }
;;

(* Two 16-bit samples a frame from the host, left then right, LSB first in slots 12 to 27,
   the rest 0: the channel status says consumer, PCM, 44.1 kHz, accuracy code 00. Every
   subframe starts and ends low, so the preambles are fixed levels and the parity bit is
   the last half slot low. [y] counts the frames to the next B, [isr] says whether left
   had a sample, and right takes one only then: an empty fifo is a silent frame. *)
let firmware =
  [%firmware
    {|
    set pins, 0              ; idle low
    set p, 8
    set y, 0
    wait tx
    mov t, now
    add t, p
frame:
    wait t+
    set pins, 1              ; B or M, 111 first
    jmp !tx, quiet
    pull
    mov isr, !null
    wait t+
    jmp counted
quiet:
    mov osr, null
    mov isr, null
    wait t+
counted:
    wait t+
    wait t+
    set pins, 0
    jmp y--, m
    set y, 23                ; B: 191 more frames in the block
    add y, y
    wait t+
    set pins, 1
    add y, y
    add y, y
    add y, 7
    wait t+
    set pins, 0
    wait t+
    wait t+
    jmp left
m:
    wait t+
    wait t+
    wait t+
    set pins, 1
    wait t+
    set pins, 0
left:
    set x, 7
laux:
    wait t+
    mov pins, !pins          ; slots 4 to 11, 0
    wait t+
    jmp x--, laux
lbit:
    wait t+
    mov pins, !pins          ; slots 12 to 27, the sample
    out x, 1
    jmp x--, lone
    wait t+
    jmp !osre, lbit
    jmp lvuc
lone:
    wait t+
    mov pins, !pins
    jmp !osre, lbit
lvuc:
    set x, 2
lzero:
    wait t+
    mov pins, !pins          ; V, U and C, 0
    wait t+
    jmp x--, lzero
    wait t+
    mov pins, !pins          ; P
    wait t+
    set pins, 0
    wait t+
    set pins, 1              ; W, 11100100
    mov x, isr
    jmp x--, rpull
    mov osr, null
    wait t+
    jmp right
rpull:
    pull
    wait t+
right:
    wait t+
    wait t+
    set pins, 0
    wait t+
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    set x, 7
raux:
    wait t+
    mov pins, !pins
    wait t+
    jmp x--, raux
rbit:
    wait t+
    mov pins, !pins
    out x, 1
    jmp x--, rone
    wait t+
    jmp !osre, rbit
    jmp rvuc
rone:
    wait t+
    mov pins, !pins
    jmp !osre, rbit
rvuc:
    set x, 2
rzero:
    wait t+
    mov pins, !pins
    wait t+
    jmp x--, rzero
    wait t+
    mov pins, !pins
    wait t+
    set pins, 0
    jmp frame
|}
      ~config]
;;

let certified = [ Certified.of_firmware "spdif" firmware ]

(* TODO the copy python/bench_firmware.py holds for the bench, at its clock, with a run
   long enough to bound [limits]; for a period the host loads, [Floor] the least and
   [load] the one the bench loads *)
let bench =
  { Bench.name = "spdif"
  ; what = "Spdif.firmware: TODO what the bench sees, on OUT0"
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

(* TODO what sigrok's spdif decoder reads. demo/decode.py --show test/traces/spdif.trace
   prints every line it reads, by class, to fill [expect] with. Its channels: data;
   optional: none; options: none; classes: bitrate, preamble, bits, aux, samples,
   validity, subcode, chan_stat, parity. Each of [teeth] changes the waveform so the
   decoders have to misread it. *)
let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "spdif" ~pins:[ "data", pin ] ]
  ; expect = []
  ; joins_after = None
  ; rejected = None
  ; teeth = []
  }
;;

(* TODO a run at the pins: the host's words, and in [peer] a model of the far end if it
   answers *)
let scenario =
  { Scenario.name = "spdif"
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
  { Protocol.name = "spdif"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = [ "spdif", "TODO the rows of the spec's timing table" ]
  ; swept = []
  ; not_swept = [ "spdif", "TODO why the sweep does not stamp it, or a Swept.t" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
