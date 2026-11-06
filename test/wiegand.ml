open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* Wikipedia, "Wiegand interface", oldid 1374164469, page 1, lines 91 and 94 of the spec.
   DATA0 and DATA1 idle high, a 0 pulls DATA0 low and a 1 pulls DATA1 low. The 26-bit
   format is a parity bit, 8 bits of facility, 16 of ID and a parity bit. The page gives
   no timing, so the host loads the pulse width and the interval between pulses. *)

(* DATA0 is OUT0, DATA1 is OUT1. *)
let pin = 5

(* 50 us pulses 500 us apart: the page has no figure, so these are the scenario's own. *)
let pulse = 2_400
let interval = 10

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 2
  ; set_base = pin
  ; set_count = 2
  ; out_shift = Left
  }
;;

(* The host's first words are the pulse width in cycles and the interval in pulse widths
   (at least 3). Then comes a read: its length in bits less one, and the bits MSB first,
   16 per word, with the last word left-aligned. The host paces the reads. *)
let firmware =
  [%firmware
    {|
    set pins, 3              ; both lines idle high
    wait tx
    pull
    mov p, osr               ; the pulse width
    wait tx
    pull
    mov x, osr
    sub x, 3
    mov isr, x               ; the gap's waits, less one
read:
    wait tx
    pull
    mov y, osr               ; bits in the read, less one
    wait tx
    pull
    mov t, now
    add t, p
next:
    jmp !osre, have
    pull                     ; the next 16 bits
have:
    out x, 1
    jmp x--, one
    wait t+
    set pins, 2              ; a 0 pulls DATA0 low
    jmp held
one:
    wait t+
    set pins, 1              ; a 1 pulls DATA1 low
held:
    wait t+
    set pins, 3              ; both high again a pulse width later
    mov x, isr
gap:
    wait t+
    jmp x--, gap
    jmp y--, next
    jmp read
|}
      ~config
      ~period_floor:16]
;;

let certified = [ Certified.of_firmware ~period:pulse "wiegand" firmware ]

(* A 26-bit card read: the words of [card]. *)
let card ~facility ~id =
  let data = (facility lsl 16) lor id in
  let parity bits = Int.popcount bits land 1 in
  let even = parity (data lsr 12) in
  let odd = 1 lxor parity (data land 0xfff) in
  let bits = (even lsl 25) lor (data lsl 1) lor odd in
  [ 25; bits lsr 10; (bits land 0x3ff) lsl 6 ]
;;

let bench =
  { Bench.name = "wiegand"
  ; what =
      [%string
        "Wiegand.firmware: a 26-bit card read, DATA0 on OUT0 and DATA1 on OUT1, pulses \
         of %{Bench.time pulse} every %{Bench.time (interval * pulse)}"]
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Floor 16
  ; clock_hz = Bench.clock_hz
  ; load = Some pulse
  ; stimulus = None
  }
;;

(* The page gives no timing. *)
let limits : Datasheet.t list = []

(* sigrok's decoder ends a bit at the next pulse or [bitwidth_ms] after its start, so the
   interval is under 1 ms and the run idles 1 ms after the last pulse. Its state class
   prints the whole read. *)
let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders =
      [ Sigrok.decoder
          "wiegand"
          ~pins:[ "d0", pin; "d1", pin + 1 ]
          ~options:[ "bitwidth_ms", "1" ]
      ]
  ; expect =
      [ "wiegand=state", Sigrok.lines "wiegand" [ "26 bits 00010101000010010001101001" ] ]
  ; joins_after =
      Some
        ( 100
        , { why =
              "both lines are low from reset until the firmware starts, which the \
               decoder reads as invalid"
          ; first_difference = 0
          ; reads = "wiegand-1: invalid"
          } )
  ; rejected = None
  ; (* The first 0's pulse held high, and the first 1's split in two. *)
    teeth =
      [ [ Flip { pin; edge = 1; after = 0; cycles = pulse } ]
      ; [ Flip { pin = pin + 1; edge = 1; after = pulse / 3; cycles = pulse / 3 } ]
      ]
  }
;;

(* The pulse width, the interval, then one card: facility 42, ID 4660. *)
let scenario =
  { Scenario.name = "wiegand"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ [ Scenario.start
        ; Write (Reg.tx, [ pulse; interval ] @ card ~facility:0x2a ~id:0x1234)
        ; Run (28 * interval * pulse)
        ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "wiegand"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited =
      [ ( "wiegand"
        , "the spec, Wikipedia's Wiegand interface page, gives no pulse width, interval \
           or any other timing" )
      ]
  ; swept =
      [ (* 1200-cycle pulses 10 apart, slow enough for the host's polls and inside a
           stamp. DATA0 is on the wire and DATA1 beside it. *)
        { Swept.name = "wiegand"
        ; watch = "DATA0"
        ; on_wire = Swept.line
        ; period = Some 1200
        ; bursts = [ 10 :: card ~facility:0x2a ~id:0x1234 ]
        }
      ]
  ; not_swept = []
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
