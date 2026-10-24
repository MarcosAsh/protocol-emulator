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

(* The period is a constant in the firmware, so the certificate assumes nothing. *)
let certified = [ Certified.of_firmware "lfast" firmware ]

(* One 33-bit frame is 330 cycles, inside the stimulus' 400. *)
let bench =
  { Bench.name = "lfast"
  ; what = "Lfast.firmware: LFAST frames at 4.8 Mb/s, a payload byte each, on OUT0"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus = Some { bursts = [ [ 0x55 ] ]; quiet = 0; cycles = 400 }
  }
;;

(* The one limit on the line the note gives as a maximum: the data rate, up to 320 Mb/s
   (p.3), so no level of the line lasts under 1 / 320 MHz = 3.125 ns. Table 8 on p.12 and
   the text on p.1, p.2 and p.25 repeat the 320 and give 5 MHz at low speed only as
   typical, and the 10 to 264 MHz reference clock on p.25 is an input of the other chip,
   so none of them bounds this pin. *)
let limits : Datasheet.t list =
  let sheet =
    { Datasheet.Sheet.part = "LFAST"
    ; document = "NXP AN5134 Rev. 0"
    ; page = "p.3, text: rates up to 320 Mb/s"
    }
  in
  List.map
    [ "high", true; "low", false ]
    ~f:(fun (name, high) ->
      { Datasheet.firmware = bench.name
      ; parameter = [%string "data rate, shortest %{name} bit (3.125 ns)"]
      ; limit = At_least 3.125
      ; sheet
      ; margin = Cycle
      ; bound = Datasheet.level ~pin:Datasheet.set_pin ~high ()
      })
;;

(* What sigrok's lfast decoder reads. It labels the 1 stop bit a sleep request, and it
   needs the frame's last payload bit to end a run, so a payload ends in a 1. The teeth
   flip a sync bit, a header bit and a payload bit. *)
let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "lfast" ~pins:[ "data", pin ] ]
  ; expect =
      [ ( "lfast=sync:header_pl_size:header_ch_type:header_cts:payload:sleep"
        , List.concat_map [ 0x55; 0xa3 ] ~f:(fun byte ->
            [ "Sync OK"
            ; "8 bit"
            ; "Data Channel A"
            ; "1"
            ; sprintf "%02X" byte
            ; "LVDS sleep mode request"
            ])
          |> Sigrok.lines "lfast" )
      ]
  ; joins_after = None
  ; rejected = None
  ; teeth =
      [ [ Flip { pin; edge = 2; after = 0; cycles = 10 } ]
      ; [ Flip { pin; edge = 12; after = 0; cycles = 10 } ]
      ; [ Flip { pin; edge = 16; after = 0; cycles = 10 } ]
      ]
  }
;;

(* Two frames at the pins. The far end only listens, so [peer] is idle. *)
let scenario =
  { Scenario.name = "lfast"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Write (Reg.tx, [ 0x55; 0xa3 ]); Scenario.start; Run 760 ]
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
  ; unlimited = []
  ; swept = []
  ; not_swept = [ "lfast", "a fixed-length frame with no field to carry a cycle stamp" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
