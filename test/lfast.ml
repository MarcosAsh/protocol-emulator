open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* NXP AN5134 Rev. 0, "Introduction to the Zipwire Interface": LFAST frames, p.3 and
   Figure 2 on p.4, the timing in Table 8 on p.12. *)
let pin = 5

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  ; out_shift = Left
  }
;;

(* LFAST frame, MSB first, as the spec's Figure 2 gives it: sync 0xA84B, an 8-bit header,
   the payload, a single 1 stop bit. The note leaves the header's fields to the reference
   manual, so they are sigrok's: 0b000_0100_1 is an 8-bit payload on data channel A with
   CTS set. The host's word is the payload byte, not 0x00, whose eight low bits would
   outrun the decoder's timeout. The line idles low, five megabaud at 48 MHz is 9.6 cycles
   a bit and the firmware takes 10. *)
let firmware =
  [%firmware
    {|
    set p, 10
    set pins, 0              ; idle low
idle:
    wait tx
    pull
    out null, 8              ; the payload byte, MSB first
    mov t, now               ; anchor: the first bit a period from here
    add t, p
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    set pins, 0
    wait t+
    set pins, 0
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    set pins, 0
    wait t+
    set pins, 0
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    set x, 7
payload:
    wait t+
    out pins, 1
    jmp x--, payload
    wait t+
    set pins, 1              ; stop bit
    wait t+
    set pins, 0              ; idle again a period after it
    jmp idle
|}
      ~config]
;;

(* TODO the certificates, under the assumptions [%firmware] checked: give ~period, the
   period the host loads, to firmware checked at a ~period_floor, and ~no_wrap:true where
   a wait can fall far behind, as a receiver's can *)
let certified = [ Certified.of_firmware "lfast" firmware ]

(* TODO the copy python/bench_firmware.py holds for the bench, at its clock, with a run
   long enough to bound [limits]; for a period the host loads, [Floor] the least and
   [load] the one the bench loads *)
let bench =
  { Bench.name = "lfast"
  ; what = "Lfast.firmware: TODO what the bench sees, on OUT0"
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

(* TODO what sigrok's lfast decoder reads. demo/decode.py --show test/traces/lfast.trace
   prints every line it reads, by class, to fill [expect] with. Its channels: data;
   optional: none; options: none; classes: bit, sync, header_pl_size, header_ch_type,
   header_cts, payload, ctrl_data, sleep, warning. Each of [teeth] changes the waveform so
   the decoders have to misread it. *)
let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "lfast" ~pins:[ "data", pin ] ]
  ; expect = []
  ; joins_after = None
  ; rejected = None
  ; teeth = []
  }
;;

(* TODO a run at the pins: the host's words, and in [peer] a model of the far end if it
   answers *)
let scenario =
  { Scenario.name = "lfast"
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
  { Protocol.name = "lfast"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = [ "lfast", "TODO the rows of the spec's timing table" ]
  ; swept = []
  ; not_swept = [ "lfast", "TODO why the sweep does not stamp it, or a Swept.t" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
