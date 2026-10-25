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
      Some
        { bursts = [ [ 0x1234; 0x56; 0x9abc; 0xde ]; [ 0x1235; 0x56; 0x9abd; 0xde ] ]
        ; quiet = 0
        ; cycles = 90_000
        }
  }
;;

(* The spec's timing is all nominal ("about", "~"), taken here as the least the scale
   waits: a clock no faster than 90 kHz, so a half period of 5555.5 ns, and pauses no
   shorter than 55, 110 and 55 us. The 300 ms and 20 ms update periods, and their 3 and 50
   Hz, are the host's to pace, so no row bounds them. The last pause is not a high of its
   own on the line: it runs into the next frame's first, so that row reads the two
   together. Highs of the run: 0 is the first pause, 24 the one between the words, 48 the
   last. *)
let limits =
  let sheet lines =
    { Datasheet.Sheet.part = "Chinese digital scale"
    ; document = "Chinese Scales web page, no revision"
    ; page = [%string "Chinese Scale Protocol, page 1, %{lines}"]
    }
  in
  let clock (config : Program_config.t) = config.set_base in
  let pause ~parameter ~lines ~ns ~index =
    { Datasheet.firmware = bench.name
    ; parameter
    ; limit = At_least ns
    ; sheet = sheet lines
    ; margin = Cycle
    ; bound =
        Datasheet.run ~pin:clock (fun ~clock_hz:_ levels ->
          List.filter_map levels ~f:(fun (high, n) -> Option.some_if high n)
          |> Fn.flip List.nth index
          |> Option.to_list)
    }
  in
  let half ~high =
    { Datasheet.firmware = bench.name
    ; parameter = (if high then "clock high at 90 kHz" else "clock low at 90 kHz")
    ; limit = At_least 5_555.5
    ; sheet = sheet "lines 52-54"
    ; margin = Cycle
    ; bound = Datasheet.level ~pin:clock ~high ()
    }
  in
  [ half ~high:true
  ; half ~high:false
  ; pause
      ~parameter:"pause before the first word"
      ~lines:"lines 82-84"
      ~ns:55_000.
      ~index:0
  ; pause ~parameter:"pause between the words" ~lines:"lines 82-84" ~ns:110_000. ~index:24
  ; pause
      ~parameter:"pause after the last word"
      ~lines:"lines 82-84"
      ~ns:55_000.
      ~index:48
  ]
;;

(* sigrok's caliper decoder reads 24 bits at the rises of the clock, 16 of number and 8 of
   flags, and so each word of the frame on its own: a number in 1/2000 inch if the last
   flag is set, with the sign in the fifth. It does not take the spec's 1/20480 inch two's
   complement. The clock rises once when the firmware starts, which it takes for a bit, so
   it joins once the clock idles. *)
let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "caliper" ~pins:[ "clk", pin; "data", pin + 1 ] ]
  ; expect = [ "caliper=measurement", Sigrok.lines "caliper" [ "46.6mm"; "-16.384in" ] ]
  ; joins_after =
      Some
        ( 100
        , { why =
              "the clock is low from reset until the firmware starts, and the rise then \
               is a bit of the first number"
          ; first_difference = 0
          ; reads = "caliper-1: 93.2mm"
          } )
  ; rejected = None
  ; (* the first rise of the data held low for a bit, and a clock edge of the first word
       moved a bit late *)
    teeth =
      [ [ Flip { pin = pin + 1; edge = 0; after = 0; cycles = 2 * half_period } ]
      ; [ Shift { pin; edge = 6; cycles = 2 * half_period } ]
      ]
  }
;;

(* a frame of two positions, the clock's half period first; the receiver only listens *)
let scenario =
  { Scenario.name = "caliper"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ [ Scenario.start
        ; Write (Reg.tx, [ half_period; 0x1234; 0x00; 0x8000; 0xff ])
        ; Run 45_000
        ]
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
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "caliper"
        , "the data moves 3 cycles after each clock rise: the sweep's edge logger cannot \
           follow edges so close" )
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
