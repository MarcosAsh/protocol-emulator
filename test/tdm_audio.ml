open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* Cirrus Logic AN301 REV1 (Sep 2006), the TDM tutorial: no timing table, the format is
   pp.2-3 and Figures 2-6. Eight 32-bit channel blocks a frame, the 24-bit audio word MSB
   first then an 8-bit zero pad (Figure 3). FSYNC rises one SCLK before channel 1, so the
   last bit of channel 8 is within it (p.3, Figure 4), and is high for one SCLK, the least
   p.3 allows. SCLK is 8 MHz (6 cycles of the 48 MHz clock, 3 a half), a 31.25 kHz frame:
   p.2 gives 12.288 MHz only as the example for 48 kHz, and 4 cycles a bit leaves no room
   for a jmp. *)
let clk_pin = 5
let sync_pin = clk_pin + 1
let data_pin = clk_pin + 2
let pin = clk_pin
let channels = 8
let block_bits = 32

(* The host's 16-bit sample is the top of the 24-bit audio word, the low 8 bits 0. *)
let audio_word ~sample =
  if sample < 0 || sample >= 1 lsl 16
  then raise_s [%message "BUG: a sample is 16 bits" (sample : int)];
  sample lsl 8
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
  }
;;

(* Side-set is SCLK in bit 0 and FSYNC in bit 1. Every half bit is 3 cycles of
   instructions, no waits: data and FSYNC change as SCLK falls, the far end reads them as
   it rises. A block's last bit asks for the next sample; with none the block is silence. *)
let firmware =
  [%firmware
    {|
    .side_set 2
    set pins, 0 side 0
    wait tx side 0           ; the first sample starts SCLK
    set x, 15 side 2 [2]     ; FSYNC before the first frame
    pull side 3 [2]
ch1:
    out pins, 1 side 0 [2]   ; a sample bit, MSB first, as SCLK falls
    nop side 1               ; SCLK rises: the far end reads it
    jmp x--, ch1
    set pins, 0 side 0       ; the audio word's low 8 bits and the pad are 0
    set x, 13 side 0 [1]
    nop side 1 [2]
pad1:
    nop side 0 [2]
    nop side 1
    jmp x--, pad1
    set x, 15 side 0         ; the block's last bit
    jmp tx, word1
    mov osr, null side 1     ; no sample: silence
    jmp ch2
word1:
    pull side 1 [2]
ch2:
    out pins, 1 side 0 [2]
    nop side 1
    jmp x--, ch2
    set pins, 0 side 0
    set x, 13 side 0 [1]
    nop side 1 [2]
pad2:
    nop side 0 [2]
    nop side 1
    jmp x--, pad2
    set x, 15 side 0
    jmp tx, word2
    mov osr, null side 1
    jmp ch3
word2:
    pull side 1 [2]
ch3:
    out pins, 1 side 0 [2]
    nop side 1
    jmp x--, ch3
    set pins, 0 side 0
    set x, 13 side 0 [1]
    nop side 1 [2]
pad3:
    nop side 0 [2]
    nop side 1
    jmp x--, pad3
    set x, 15 side 0
    jmp tx, word3
    mov osr, null side 1
    jmp ch4
word3:
    pull side 1 [2]
ch4:
    out pins, 1 side 0 [2]
    nop side 1
    jmp x--, ch4
    set pins, 0 side 0
    set x, 13 side 0 [1]
    nop side 1 [2]
pad4:
    nop side 0 [2]
    nop side 1
    jmp x--, pad4
    set x, 15 side 0
    jmp tx, word4
    mov osr, null side 1
    jmp ch5
word4:
    pull side 1 [2]
ch5:
    out pins, 1 side 0 [2]
    nop side 1
    jmp x--, ch5
    set pins, 0 side 0
    set x, 13 side 0 [1]
    nop side 1 [2]
pad5:
    nop side 0 [2]
    nop side 1
    jmp x--, pad5
    set x, 15 side 0
    jmp tx, word5
    mov osr, null side 1
    jmp ch6
word5:
    pull side 1 [2]
ch6:
    out pins, 1 side 0 [2]
    nop side 1
    jmp x--, ch6
    set pins, 0 side 0
    set x, 13 side 0 [1]
    nop side 1 [2]
pad6:
    nop side 0 [2]
    nop side 1
    jmp x--, pad6
    set x, 15 side 0
    jmp tx, word6
    mov osr, null side 1
    jmp ch7
word6:
    pull side 1 [2]
ch7:
    out pins, 1 side 0 [2]
    nop side 1
    jmp x--, ch7
    set pins, 0 side 0
    set x, 13 side 0 [1]
    nop side 1 [2]
pad7:
    nop side 0 [2]
    nop side 1
    jmp x--, pad7
    set x, 15 side 0
    jmp tx, word7
    mov osr, null side 1
    jmp ch8
word7:
    pull side 1 [2]
ch8:
    out pins, 1 side 0 [2]
    nop side 1
    jmp x--, ch8
    set pins, 0 side 0
    set x, 13 side 0 [1]
    nop side 1 [2]
pad8:
    nop side 0 [2]
    nop side 1
    jmp x--, pad8
    set x, 15 side 2         ; FSYNC rises: the next frame
    jmp tx, word8
    mov osr, null side 3
    jmp ch1
word8:
    pull side 3
    jmp ch1
|}
      ~config]
;;

let certified = [ Certified.of_firmware "tdm_audio" firmware ]

(* a frame of samples, channel 1 first; the bench copy has no run as there is no limit for
   one to bound *)
let samples = [ 0x8000; 0x7fff; 0x1234; 0xa5a5; 0x0001; 0xffff; 0x5555; 0xc3c3 ]

(* The bench's OUT1 reaches no analyser channel, so all three go to analyser B: SCLK and
   FSYNC on OUT3 and OUT4, SDATA on OUT6. OUT5, the flash's clock, stays still, so the
   flash takes none of it for a command. *)
let bench =
  { Bench.name = "tdm_audio"
  ; what =
      "Tdm_audio.firmware: SCLK at 8 MHz on OUT3, FSYNC on OUT4 and SDATA on OUT6, eight \
       32-bit channel blocks every 32 us"
  ; source = Timed_program.source firmware
  ; config = { config with side_set_base = Bench.neopixel; out_base = 11; set_base = 11 }
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus = None
  }
;;

let limits : Datasheet.t list = []

(* sigrok's tdm_audio reads a whole block a channel, pad and all, at the rise of its last
   bit, and starts a frame at the bit after FSYNC is seen high: the frame of samples, then
   the frame of silence. The teeth flip channel 1's MSB, and bring the second FSYNC a bit
   early so channel 8 is cut short and never read. *)
let sigrok =
  let frame samples =
    List.mapi samples ~f:(fun i sample ->
      sprintf "tdm_audio-1: Channel %d: %08x" (i + 1) (audio_word ~sample lsl 8))
  in
  { Sigrok.clock_hz = 48_000_000
  ; decoders =
      [ Sigrok.decoder
          "tdm_audio"
          ~pins:[ "clock", clk_pin; "frame", sync_pin; "data", data_pin ]
          ~options:[ "bps", Int.to_string block_bits; "channels", Int.to_string channels ]
      ]
  ; expect =
      [ ( "tdm_audio=ch0:ch1:ch2:ch3:ch4:ch5:ch6:ch7"
        , frame samples @ frame (List.map samples ~f:(Fn.const 0)) )
      ]
  ; joins_after = None
  ; rejected = None
  ; teeth =
      [ [ Flip { pin = data_pin; edge = 0; after = 0; cycles = 6 } ]
      ; [ Shift { pin = sync_pin; edge = 2; cycles = -6 } ]
      ]
  }
;;

(* a frame of the eight samples, then one of silence as the host has no more *)
let scenario =
  { Scenario.name = "tdm_audio"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Write (Reg.tx, samples); Scenario.start; Run 3_200 ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "tdm_audio"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited =
      [ ( "tdm_audio"
        , "AN301 has no timing table: SCLK 12.288 MHz (p.2) is typical only, the example \
           for 8 x 32-bit blocks at 48 kHz, with no minimum or maximum" )
      ]
  ; swept = []
  ; not_swept =
      [ "tdm_audio", "a fixed 256-bit frame with no field to carry a cycle stamp" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
