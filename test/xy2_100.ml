open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* Newson rhothor X7 I/O configuration: XY2-100, datasheet revision 0703, p.1-2. A 20-bit
   word, C2-C0 then D15-D0 then even parity, at SENDCK 2 MHz (24 cycles of the 48 MHz
   clock, 12 a half). The host's word is the 16 data bits: the core sends control 001, the
   motor setpoint, and the parity, which the CRC unit counts as a 1-bit CRC started at 1
   for the control's one. SENDCK runs on, SYNC low and DATA unchanged, while the fifo is
   empty. *)
let clk_pin = 5
let sync_pin = clk_pin + 1
let data_pin = clk_pin + 2
let pin = clk_pin

(* the 20 bits on the wire for a setpoint, first bit highest *)
let on_wire ~data =
  if data < 0 || data >= 1 lsl 16
  then raise_s [%message "BUG: data is 16 bits" (data : int)];
  let body = (1 lsl 16) lor data in
  (body lsl 1) lor (Int.popcount body land 1)
;;

let config =
  { Program_config.default with
    side_set_count = 2
  ; side_set_base = clk_pin
  ; out_base = data_pin
  ; out_count = 1
  ; set_base = data_pin
  ; set_count = 1
  ; out_shift = Left
  ; crc_width = 1
  ; crc_poly = 1
  ; crc_init = 1
  ; crc_reflect = false
  }
;;

(* Side-set is SENDCK in bit 0 and SYNC in bit 1. Data changes with each rise, which SYNC
   joins on the first bit and leaves on the last. *)
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
    crc_init side 0
    set x, 15 side 0
    wait t+ side 0
    set pins, 0 side 3       ; C2, SYNC rises
    wait t+ side 3
    nop side 2
    wait t+ side 2
    set pins, 0 side 3       ; C1
    wait t+ side 3
    nop side 2
    wait t+ side 2
    set pins, 1 side 3       ; C0
    wait t+ side 3
    nop side 2
bit:
    wait t+ side 2
    out pins, 1 side 3       ; D15 first
    wait t+ side 3
    nop side 2
    jmp x--, bit
    in crc, 16 side 2        ; the parity so far
    wait t+ side 2
    mov pins, isr side 1     ; parity, SYNC falls
    wait t+ side 1
    nop side 0
    jmp clock
|}
      ~config]
;;

let certified = [ Certified.of_firmware "xy2_100" firmware ]

(* the copy python/bench_firmware.py holds for the bench: two setpoints in a run of two
   frames' time *)
let bench =
  { Bench.name = "xy2_100"
  ; what =
      "Xy2_100.firmware: SENDCK at 2 MHz on OUT0, SYNC on OUT1 and DATA on OUT2, a \
       20-bit word every 10 us"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus = Some { bursts = [ [ 0x8000; 0x1234 ] ]; quiet = 0; cycles = 1_200 }
  }
;;

(* DATA changes only in the instruction that raises SENDCK, and is read at its fall. The
   setup is the kernel's spacing from DATA's last change to the fall. The hold runs from
   the fall to the next change, no sooner than the next rise: SENDCK's low time. *)
let limits =
  let sheet =
    { Datasheet.Sheet.part = "rhothor X7"
    ; document = "Newson XY2-100 I/O configuration, Rev. 0703"
    ; page = "Timing specifications table, p.2"
    }
  in
  let limit parameter ns bound =
    { Datasheet.firmware = bench.name
    ; parameter
    ; limit = At_least ns
    ; sheet
    ; margin = Cycle
    ; bound
    }
  in
  [ limit
      "tDS"
      50.
      (Datasheet.Bound.Kernel
         (fun config ->
           Datasheet.spacing
             ~apart:(fun ~own ~other:_ -> own)
             ~a:(Datasheet.side_pin config)
             ~b:config.out_base
             ()))
  ; limit "tDH" 100. (Datasheet.level ~pin:Datasheet.side_pin ~high:false ())
  ]
;;

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
      @ [ Write (Reg.tx, [ 0x8000; 0x0000; 0xffff; 0x1234 ]); Scenario.start; Run 2_800 ]
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
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ "xy2_100", "SENDCK edges 12 cycles apart without a break: the fifo holds 8" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
