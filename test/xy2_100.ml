open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* Newson rhothor X7 I/O configuration: XY2-100, datasheet revision 0703, p.1-2. A 20-bit
   word, C2-C0 then D15-D0 then even parity, at SENDCK 2 MHz (24 cycles of the 48 MHz
   clock, 12 a half). The host's word is the 20 bits, parity included. SENDCK runs on,
   SYNC low and DATA unchanged, while the fifo is empty. *)
let clk_pin = 5
let sync_pin = clk_pin + 1
let data_pin = clk_pin + 2
let pin = clk_pin

let config =
  { Program_config.default with
    side_set_count = 2
  ; side_set_base = clk_pin
  ; out_base = data_pin
  ; out_count = 1
  ; out_shift = Left
  }
;;

(* Side-set is SENDCK in bit 0 and SYNC in bit 1. Data changes with each rise, which
   SYNC joins on the first bit and leaves on the last. *)
let firmware =
  [%firmware
    {|
    .side_set 2
    set p, 12 side 0
    mov t, now side 0        ; the only anchor
    add t, p side 0
clock:
    jmp tx, send
    wait t+ side 0
    nop side 1               ; idle rise
    wait t+ side 1
    nop side 0
    jmp clock
send:
    pull side 0
    out null, 12 side 0      ; the word is the low 20 bits
    set x, 17 side 0
    wait t+ side 0
    out pins, 1 side 3       ; first bit, SYNC rises
    wait t+ side 3
    nop side 2
bit:
    wait t+ side 2
    out pins, 1 side 3
    wait t+ side 3
    nop side 2
    jmp x--, bit
    wait t+ side 2
    out pins, 1 side 1       ; parity, SYNC falls
    wait t+ side 1
    nop side 0
    jmp clock
|}
      ~config]
;;

let certified = [ Certified.of_firmware "xy2_100" firmware ]

(* TODO the copy python/bench_firmware.py holds for the bench, at its clock, with a run
   long enough to bound [limits]; for a period the host loads, [Floor] the least and
   [load] the one the bench loads *)
let bench =
  { Bench.name = "xy2_100"
  ; what = "Xy2_100.firmware: TODO what the bench sees, on OUT0"
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

(* TODO what sigrok's xy2-100 decoder reads. demo/decode.py --show
   test/traces/xy2_100.trace prints every line it reads, by class, to fill [expect] with.
   Its channels: clk, sync, data; optional: status; options: none; classes: bit, stat_bit,
   type, command, parameter, parity, position, status, warning. Each of [teeth] changes
   the waveform so the decoders have to misread it. *)
let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders =
      [ Sigrok.decoder
          "xy2-100"
          ~pins:[ "clk", clk_pin; "sync", sync_pin; "data", data_pin ]
      ]
  ; expect = []
  ; joins_after = None
  ; rejected = None
  ; teeth = []
  }
;;

(* TODO a run at the pins: the host's words, and in [peer] a model of the far end if it
   answers *)
let scenario =
  { Scenario.name = "xy2_100"
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
  { Protocol.name = "xy2_100"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = [ "xy2_100", "TODO the rows of the spec's timing table" ]
  ; swept = []
  ; not_swept = [ "xy2_100", "TODO why the sweep does not stamp it, or a Swept.t" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
