open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

let sheet =
  { Datasheet.Sheet.part = "PS/2 auxiliary device"
  ; document =
      "IBM PS/2 Hardware Interface Technical Reference, May 1988, Keyboard and Auxiliary \
       Device Controller (Type 1)"
  ; page = "Figure 8, Receiving Data Timings, p.13 (PDF p.346)"
  }
;;

let data = Isa.first_bidir_pin
let clock = data + 1

(* a quarter of the clock period, 20 us at the bench's 48 MHz *)
let standard_unit = Bench.cycles_in ~us:20
let shortest_unit = 8

let config =
  { Program_config.default with
    in_base = data
  ; out_base = data
  ; out_count = 1
  ; set_base = clock
  ; set_count = 1
  ; jmp_pin = clock
  ; in_shift = Left
  }
;;

(* A frame is eleven bits of four units each: the data changes mid clock high, the clock
   falls a unit later and rises two after that. Both lines are only ever pulled low; a
   clock the host holds low before the 11th clock sends the frame again once it lets go.
   The first host word is the unit, then each is a byte with its odd parity in bit 8. *)
let firmware =
  [%firmware
    {|
    wait tx
    pull
    mov p, osr               ; a unit, 20 us
    set pins, 0
    mov pins, null
idle:
    wait tx
    pull
    mov y, osr
retry:
    mov pindirs, null        ; data released
    mov isr, null
    set x, 1
    in x, 1                  ; stop
    in y, 9                  ; parity and the byte
    in null, 1               ; start
    mov osr, !isr            ; a released line is a one
    wait 1 pin 13            ; the host lets the clock go
    mov t, now
    add t, p
    set x, 2
high:
    wait t+
    jmp !pin, retry          ; held low again: inhibited
    jmp x--, high            ; 60 us high before the start bit
    set x, 10
bit:
    out pindirs, 1
    wait t+
    set pindirs, 1           ; the clock falls a unit after the data
    wait t+
    wait t+
    set pindirs, 0           ; and rises two units later
    wait t+
    jmp !pin, inhibited      ; the clock checked a unit after each rise
    jmp x--, bit
    jmp idle
inhibited:
    jmp x--, retry           ; before the 11th clock: the whole frame again
    jmp idle
|}
      ~config
      ~period_floor:shortest_unit]
;;

(* the byte with its odd parity in bit 8 *)
let word byte =
  let byte = byte land 0xff in
  byte lor (Bool.to_int (Int.popcount byte % 2 = 0) lsl 8)
;;

(* A PC's controller holds the clock low a while after each frame's 11th clock to take the
   byte, inside T5's 50 us, so the device sends nothing more until it lets go. *)
let host ~after ~hold () =
  let dirs = ref 0 in
  let rises = ref 0 in
  let cycle = ref 0 in
  let held = ref (0, 0) in
  let released pin = Peer.bit !dirs pin = 0 in
  { Peer.inputs =
      (fun () ->
        let from, until = !held in
        let inhibit = from <= !cycle && !cycle < until in
        (Bool.to_int (released data) lsl data)
        lor (Bool.to_int (released clock && not inhibit) lsl clock))
  ; step =
      (fun ~pin_out:_ ~pin_dir ->
        if Peer.bit !dirs clock = 1 && Peer.bit pin_dir clock = 0
        then (
          incr rises;
          if !rises = 11
          then (
            rises := 0;
            held := !cycle + after, !cycle + after + hold));
        dirs := pin_dir;
        incr cycle)
  }
;;

let certified =
  [ Certified.plain
      ~period:standard_unit
      ~period_floor:shortest_unit
      "ps2_blind"
      (Timed_program.source firmware)
      config
  ]
;;

(* two frames back to back, with nothing holding the clock *)
let bench =
  { Bench.name = "ps2_blind"
  ; what =
      [%string
        "Ps2_blind.firmware: the host sends the unit, %{standard_unit#Int} cycles for a \
         clock of %{Bench.rate (4 * standard_unit)}, then a byte a word; data on IO0, \
         clock on IO1"]
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Floor shortest_unit
  ; clock_hz = Bench.clock_hz
  ; load = Some standard_unit
  ; stimulus = Some { bursts = [ [ word 0x15; word 0xf0 ] ]; quiet = 0; cycles = 120_000 }
  }
;;

(* The kernel bounds the device's own edges, the bits before an edge true while it holds
   the line low. A run bounds the widths from above: each of a frame's first ten lows of
   the clock is followed by a high inside the frame, and its 11th by the gap to the next,
   whose start bit comes a unit before its first clock. T1 and T2 from above are spaced
   across both lines, which a run of one pin does not show. *)
let limits =
  let clock = Datasheet.set_pin
  and data (config : Program_config.t) = config.out_base in
  let limit parameter limit bound =
    { Datasheet.firmware = bench.name; parameter; limit; sheet; margin = Cycle; bound }
  in
  let highs f =
    Datasheet.run ~pin:clock (fun ~clock_hz:_ levels ->
      List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, _), (_, width)) ->
        Option.some_if (not high) width)
      |> List.filter_mapi ~f:(fun i width -> f ~eleventh:(i % 11 = 10) width))
  in
  [ limit
      "T1"
      (At_least 5_000.)
      (Kernel
         (fun config ->
           Datasheet.spacing
             ~dirs:true
             ~apart:(fun ~own ~other:_ -> not own)
             ~a:(clock config)
             ~b:(data config)
             ()))
  ; limit
      "T2"
      (At_least 5_000.)
      (Kernel
         (fun config n ->
           Datasheet.swap
             (Datasheet.spacing
                ~dirs:true
                ~apart:(fun ~own:_ ~other -> not other)
                ~a:(data config)
                ~b:(clock config)
                ()
                n)))
  ; limit "T3" (At_least 30_000.) (Datasheet.level ~dirs:true ~pin:clock ~high:true ())
  ; limit
      "T3"
      (At_most 50_000.)
      (Datasheet.run ~pin:clock (fun ~clock_hz:_ levels -> Datasheet.lows levels))
  ; limit "T4" (At_least 30_000.) (Datasheet.level ~dirs:true ~pin:clock ~high:false ())
  ; limit
      "T4"
      (At_most 50_000.)
      (highs (fun ~eleventh width -> Option.some_if (not eleventh) width))
  ; limit
      "T5"
      (At_least 50_000.)
      (highs (fun ~eleventh width -> Option.some_if eleventh (width - standard_unit)))
  ]
;;

(* What sigrok's ps2 decoder reads of the Q key's make and break codes. It ends a frame on
   the 12th fall of the clock, which is the host taking the byte. Data edge 1 is bit 0's
   rise; 30 us late it comes after the clock falls, and the host reads 0x14. *)
let sigrok =
  { Sigrok.clock_hz = 2_000_000
  ; decoders = [ Sigrok.decoder "ps2" ~pins:[ "clk", clock; "data", data ] ]
  ; expect =
      [ ( "ps2=start-bit:word:parity-ok:parity-err:stop-bit"
        , List.concat_map [ 0x15; 0xf0; 0x15 ] ~f:(fun byte ->
            [ "Start bit"; sprintf "Data: %02x" byte; "Parity OK"; "Stop bit" ])
          |> Sigrok.lines "ps2" )
      ]
  ; joins_after = None
  ; rejected = None
  ; teeth = [ [ Shift { pin = data; edge = 1; cycles = 60 } ] ]
  }
;;

(* The Q key's make and break codes at a 2 MHz clock, which keeps the simulation short: a
   unit of 40 cycles, and a host that takes each byte as a PC does, the clock held low 150
   us from 10 us past its 11th clock. A frame is 44 units and the hold 8 more. *)
let scenario =
  let unit = 40 in
  { Scenario.name = "ps2_blind"
  ; peer = host ~after:20 ~hold:300
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Scenario.start
        ; Write (Reg.tx, [ unit; word 0x15; word 0xf0; word 0x15 ])
        ; Run (3 * 60 * unit)
        ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "ps2_blind"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept = [ "ps2_blind", "open drain, which a wire does not show" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
