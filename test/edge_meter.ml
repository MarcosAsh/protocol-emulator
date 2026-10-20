open! Core
open Protocol_emulator

(* Self-measurement: OUT0 is wired back to IN0 and every rising edge is timestamped, so
   measured intervals can be set against the analyser's prediction. *)
let firmware ~period =
  [%string
    {|
    set p, %{period#Int}
    set pins, 0
    mov t, now
    add t, p
loop:
    capture_arm
    wait t+
    mov pins, !pins
    wait t+
    mov pins, !pins          ; one of the two is the rising edge
    nop [3]                  ; it comes back and is captured
    in capture, 16
    jmp loop
|}]
;;

let config =
  { Program_config.default with
    in_base = 0
  ; out_base = 5
  ; out_count = 1
  ; capture_pin = 0
  ; capture_rising = true
  ; autopush = true
  ; push_threshold = 16
  }
;;

let protocol =
  { Protocol.name = "edge_meter"
  ; certified = [ Certified.plain "edge_meter" (firmware ~period:16) config ]
  ; time_triggered = []
  ; bench = []
  ; loaded_from_hex = []
  ; limits = []
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "edge_meter"
        , "toggles every 16 cycles for ever, so 9 edges come in 128: the fifo holds 8" )
      ]
  ; scenarios = []
  ; decoded = []
  }
;;
