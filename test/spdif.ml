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
let words = [ 0x1234; 0xfedc; 0x8001; 0x7ffe; 0x00ff; 0xa5a5 ]

(* 194 frames: two B preambles, a block apart *)
let bench =
  { Bench.name = "spdif"
  ; what =
      "Spdif.firmware: S/PDIF on OUT0, biphase mark, stereo 16-bit samples at 44.1 kHz, \
       halves of 8 32991/65536 cycles, silence once the fifo is empty"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus = Some { bursts = [ words ]; quiet = 0; cycles = 194 * 1089 }
  }
;;

(* Where each B or M preamble starts in a run, the only pulses of three half slots at 128
   a frame of 44.1 kHz, and whether it is a B (3113). *)
let frame_starts ~clock_hz (levels : Datasheet.Levels.t) =
  let half_ns = 1e9 /. (44_100. *. 128.) in
  let halves cycles =
    Float.iround_nearest_exn
      (Float.of_int cycles *. 1e9 /. Float.of_int clock_hz /. half_ns)
  in
  let pulses =
    List.folding_map levels ~init:0 ~f:(fun start (_, n) -> start + n, (start, halves n))
    |> List.tl
    |> Option.value ~default:[]
  in
  let rec scan acc = function
    | (start, 3) :: (_, a) :: (_, b) :: (_, c) :: rest ->
      let acc =
        match a, b, c with
        | 1, 1, 3 -> (start, true) :: acc
        | 3, 1, 1 -> (start, false) :: acc
        | _ -> acc
      in
      scan acc rest
    | _ :: rest -> scan acc rest
    | [] -> List.rev acc
  in
  scan [] pulses
;;

let apart starts =
  match starts with
  | [] -> []
  | _ :: later -> List.map2_exn (List.drop_last_exn starts) later ~f:(fun a b -> b - a)
;;

(* The limit table's byte 3 of the channel status (p.1, "S/PDIF control word components",
   spec.txt l.222-224), which this firmware sends as 0: code 0000, 44.1 kHz, at accuracy
   code 00, 1100 ppm. An accuracy is a mean rate, so it holds over a block of 192 frames
   (l.182, l.256): a frame alone is 1088 or 1089 cycles, inside 1100 ppm but not by a
   cycle. And Mode 0's most, 192 kHz (l.180), a frame at a time. Not rows: 48 and 32 kHz
   and 50 ppm are codes it does not send, and bit 2's 4 to 10 Hz (l.254) is CD-DA copy
   prevention, where it holds bit 2 at 0. *)
let limits =
  let sheet ~where =
    { Datasheet.Sheet.part = "S/PDIF, IEC 60958 type II"
    ; document = "Wikipedia, S/PDIF, revision 1378032122 (2 October 2026)"
    ; page = [%string "p.1, %{where}"]
    }
  in
  let control =
    sheet ~where:"S/PDIF control word components, byte 3, spec.txt l.222-224"
  in
  let block =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      frame_starts ~clock_hz levels
      |> List.filter_map ~f:(fun (start, b) -> Option.some_if b start)
      |> apart)
  in
  let frame =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      frame_starts ~clock_hz levels |> List.map ~f:fst |> apart)
  in
  let row parameter limit sheet bound =
    { Datasheet.firmware = bench.name; parameter; limit; sheet; margin = Cycle; bound }
  in
  let block_ns ~ppm = 192e9 /. (44_100. *. (1. +. (ppm /. 1e6))) in
  [ row
      "a block of 192 frames, 44.1 kHz and 1100 ppm"
      (At_least (block_ns ~ppm:1100.))
      control
      block
  ; row
      "a block of 192 frames, 44.1 kHz less 1100 ppm"
      (At_most (block_ns ~ppm:(-1100.)))
      control
      block
  ; row
      "a frame, Mode 0's 192 kHz at most"
      (At_least (1e9 /. 192_000.))
      (sheet ~where:"text, spec.txt l.180")
      frame
  ]
;;

(* sigrok's spdif decoder spends the first subframe on finding its three pulse widths *)
let sigrok =
  { Sigrok.clock_hz = Bench.clock_hz
  ; decoders = [ Sigrok.decoder "spdif" ~pins:[ "data", pin ] ]
  ; expect = []
  ; joins_after = None
  ; rejected = None
  ; teeth = []
  }
;;

(* three stereo frames, then silent ones as the fifo runs dry *)
let scenario =
  { Scenario.name = "spdif"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Write (Reg.tx, words); Scenario.start; Run (5 * 1089) ]
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
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ "spdif", "a fixed 64-slot subframe with no field to carry a cycle stamp" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
