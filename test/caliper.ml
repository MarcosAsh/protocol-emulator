open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* Chinese Scales (no revision), page 1, "Chinese Scale Protocol", lines 51-84 of the
   spec: a 48-bit frame of two 24-bit position words, LSB first, clocked at about 90 kHz
   with the clock idling high and pausing before, between and after the words. This is the
   scale's end: data moves just after each rise, so it holds through the fall the receiver
   samples at. The host feeds the frames and so paces the 300 ms and 20 ms update periods. *)

(* the clock is OUT0 and the data OUT1 *)
let pin = 5

(* 270 cycles is 5.625 us, a clock of 88.9 kHz: under the spec's 90 kHz, and ten of them
   are 56 us and twenty 113 us, over the 55 and 110 us pauses *)
let half_period = 270

let config =
  { Program_config.default with
    out_base = pin + 1
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  }
;;

(* The host's first word is the half period of the clock in cycles, and each frame is four
   words: the 24 bits of a position as 16 and 8. Every [wait t+] is a half period on, so
   the pauses are counts of them: ten high before the first fall, twenty between the words
   and ten after the last rise. *)
let firmware =
  [%firmware
    {|
    wait tx
    pull
    mov p, osr               ; half a clock period
    set pins, 1              ; the clock idles high
frame:
    wait tx
    pull                     ; absolute position, bits 0 to 15
    out pins, 1
    mov t, now
    add t, p
    set y, 8
before:
    wait t+
    jmp y--, before          ; ten half periods high before the first fall
    set x, 15
abs_lo:
    wait t+
    set pins, 0              ; falls: the receiver samples here
    wait t+
    set pins, 1
    jmp x--, abs_lo_next
    pull                     ; bits 16 to 23
    out pins, 1
    set x, 7
abs_hi:
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    jmp x--, abs_hi_next
    pull                     ; relative position, bits 0 to 15
    out pins, 1
    set y, 18
between:
    wait t+
    jmp y--, between         ; twenty half periods high between the words
    set x, 15
rel_lo:
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    jmp x--, rel_lo_next
    pull                     ; bits 16 to 23
    out pins, 1
    set x, 7
rel_hi:
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    jmp x--, rel_hi_next
    set y, 9
after:
    wait t+
    jmp y--, after           ; ten half periods high after the last rise
    jmp frame
abs_lo_next:
    out pins, 1
    jmp abs_lo
abs_hi_next:
    out pins, 1
    jmp abs_hi
rel_lo_next:
    out pins, 1
    jmp rel_lo
rel_hi_next:
    out pins, 1
    jmp rel_hi
|}
      ~config
      ~period_floor:16]
;;

let certified = [ Certified.of_firmware ~period:half_period "caliper" firmware ]

let bench =
  { Bench.name = "caliper"
  ; what =
      [%string
        "Caliper.firmware: a scale's two 24-bit position words, clock on OUT0 and data \
         on OUT1, %{half_period#Int} cycles a half period, %{Bench.rate ~unit:\"Hz\" (2 \
         * half_period)}"]
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Floor 16
  ; clock_hz = Bench.clock_hz
  ; load = Some half_period
  ; stimulus =
      Some { bursts = [ [ 0x1234; 0x56; 0x9abc; 0xde ] ]; quiet = 0; cycles = 45_000 }
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

(* TODO what sigrok's caliper decoder reads. demo/decode.py --show
   test/traces/caliper.trace prints every line it reads, by class, to fill [expect] with.
   Its channels: clk, data; optional: none; options: timeout_ms, unit, changes; classes:
   measurement, warning. Each of [teeth] changes the waveform so the decoders have to
   misread it. *)
let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders =
      [ Sigrok.decoder "caliper" ~pins:[ "clk", pin; "data", pin + 1 (* TODO *) ] ]
  ; expect = []
  ; joins_after = None
  ; rejected = None
  ; teeth = []
  }
;;

(* TODO a run at the pins: the host's words, and in [peer] a model of the far end if it
   answers *)
let scenario =
  { Scenario.name = "caliper"
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
  { Protocol.name = "caliper"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = [ "caliper", "TODO the rows of the spec's timing table" ]
  ; swept = []
  ; not_swept = [ "caliper", "TODO why the sweep does not stamp it, or a Swept.t" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
