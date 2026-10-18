open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* TODO the spec: the document with its revision, and the table the timing comes from *)

(* TODO the pins: OUT0 is 5, IO0 is 12 (Isa.first_bidir_pin), Bench names the bench's *)
let pin = 5

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  }
;;

(* TODO the firmware. This placeholder idles the line high and sends the low byte of each
   host word LSB first, 16 cycles a bit. [%firmware] runs the analyser and the kernel when
   this file compiles, so a deadline it can miss fails the build at its line. *)
let firmware =
  [%firmware
    {|
    set p, 16
    set pins, 1              ; idle high
idle:
    wait tx
    pull
    set x, 7
    mov t, now               ; anchor: the first bit a period from here
    add t, p
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1              ; idle again a period after the last bit
    jmp idle
|}
      ~config]
;;

(* TODO the certificates, under the assumptions [%firmware] checked: give ~period, the
   period the host loads, to firmware checked at a ~period_floor, and ~no_wrap:true where
   a wait can fall far behind, as a receiver's can *)
let certified = [ Certified.of_firmware "frumbleglide" firmware ]

(* TODO the copy python/bench_firmware.py holds for the bench, at its clock, with a run
   long enough to bound [limits]; for a period the host loads, [Floor] the least and
   [load] the one the bench loads *)
let bench =
  { Bench.name = "frumbleglide"
  ; what = "Frumbleglide.firmware: TODO what the bench sees, on OUT0"
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

(* TODO what sigrok's TODO decoder reads. demo/decode.py --show
   test/traces/frumbleglide.trace prints every line it reads, by class, to fill [expect]
   with. Its channels: TODO; optional: none; options: none; classes: none. Each of [teeth]
   changes the waveform so the decoders have to misread it. *)
let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "TODO" ~pins:[ "TODO", pin ] ]
  ; expect = []
  ; joins_after = None
  ; rejected = None
  ; teeth = []
  }
;;

(* TODO a run at the pins: the host's words, and in [peer] a model of the far end if it
   answers *)
let scenario =
  { Scenario.name = "frumbleglide"
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
  { Protocol.name = "frumbleglide"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = [ "frumbleglide", "TODO the rows of the spec's timing table" ]
  ; swept = []
  ; not_swept = [ "frumbleglide", "TODO why the sweep does not stamp it, or a Swept.t" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
