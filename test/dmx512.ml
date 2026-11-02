open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* DMX512, Wikipedia oldid 1380777110, one page; numbers are its line numbers. 250 kbit/s,
   a slot is a start bit, 8 bits LSB first and two stop bits (line 291). A packet is a
   break, a mark after break, the start code and 512 channels (lines 292-297), the timing
   table at lines 303-310. Bits of 192 cycles at 48 MHz. *)
let pin = 5

(* [set] reaches 31, so the firmware builds the bit in x and writes p once. The analyser
   and the certificate take any write to p for a load, assumed to be this, which here it
   is. *)
let period = 24 * 8

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  }
;;

(* A packet a host word with the start code in its low byte, then 256 words of two
   channels, low byte first. Break 25 bits (100 us), mark after break 4 (16 us). A late
   word stretches the mark before a channel's start bit, which the spec leaves free (line
   311). *)
let firmware =
  [%firmware
    {|
    set x, 24
    add x, x
    add x, x
    add x, x
    mov p, x                 ; a bit, 192 cycles
    set pins, 1              ; mark while idle
packet:
    wait tx                  ; the start code's word
    pull
    mov t, now
    set pins, 0              ; break
    add t, p
    set x, 23
break:
    wait t+
    jmp x--, break
    wait t+
    set pins, 1              ; mark after break
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 0              ; the start code's start bit
    set x, 7
code:
    wait t+
    out pins, 1
    jmp x--, code
    wait t+
    set pins, 1              ; two stop bits
    out null, 8              ; the word's high byte is not sent
    set y, 16
    add y, y
    add y, y
    add y, y
    add y, y
    add y, y
    sub y, 1                 ; 512 channels
    wait t+
    wait t
channel:
    jmp !osre, slot          ; the word's second channel
    wait tx
    pull
slot:
    mov t, now
    set pins, 0              ; start bit
    add t, p
    set x, 7
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1              ; two stop bits
    wait t+
    wait t
    jmp y--, channel
    jmp packet
|}
      ~config
      ~period]
;;

let certified = [ Certified.of_firmware "dmx512" firmware ]

(* the start code, then the 512 channels two a word, low byte first *)
let packet ~start_code channels =
  let rec pairs = function
    | lo :: hi :: rest -> (lo lor (hi lsl 8)) :: pairs rest
    | _ -> []
  in
  if List.length channels <> 512
  then raise_s [%message "BUG: a packet has 512 channels" (List.length channels : int)];
  start_code :: pairs channels
;;

let channels = List.init 512 ~f:(fun n -> ((n * 37) + 11) land 0xff)

(* The copy python/bench_firmware.py holds: a packet of channels 0x55, every low a bit,
   and the next packet's break. *)
let bench =
  { Bench.name = "dmx512"
  ; what =
      "Dmx512.firmware: a packet of 512 channels at 250 kbit/s on OUT0, then the next \
       packet's break"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Period period
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus =
      Some
        { bursts =
            [ packet ~start_code:0x00 (List.init 512 ~f:(Fn.const 0x55)) @ [ 0x00 ] ]
        ; quiet = 0
        ; cycles = 1_110_000
        }
  }
;;

(* Bits of the line in the run. No slot is low longer than a start bit and eight zeros, so
   a longer low is a break; one that is short enough to pass for a slot leaves no break,
   and the row no bound. Packet time, about 23 ms (line 312), is typical and no row. *)
let limits =
  let sheet line =
    { Datasheet.Sheet.part = "DMX512"
    ; document = "Wikipedia, DMX512, oldid 1380777110"
    ; page = [%string "page 1, %{line}"]
    }
  in
  let is_break ~clock_hz n = n * 250_000 > 10 * clock_hz in
  let breaks ~clock_hz levels =
    List.filter (Datasheet.lows levels) ~f:(is_break ~clock_hz)
  in
  let marks_after_break ~clock_hz levels =
    List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, n), (_, mark)) ->
      Option.some_if ((not high) && is_break ~clock_hz n) mark)
  in
  let break_to_break ~clock_hz levels =
    let starts =
      List.folding_map levels ~init:0 ~f:(fun at (high, n) ->
        at + n, Option.some_if ((not high) && is_break ~clock_hz n) at)
      |> List.filter_opt
    in
    List.map2_exn (List.drop_last_exn starts) (List.tl_exn starts) ~f:(fun a b -> b - a)
  in
  (* the lows of the channels, each one bit of 0x55; a start code is not one *)
  let channel_lows ~clock_hz levels =
    List.folding_map levels ~init:false ~f:(fun after_code (high, n) ->
      match high with
      | true -> after_code, None
      | false when is_break ~clock_hz n -> false, None
      | false -> true, Option.some_if after_code n)
    |> List.filter_opt
  in
  let row ?(margin = Datasheet.Margin.Cycle) parameter ~line limit bound =
    { Datasheet.firmware = bench.name
    ; parameter
    ; limit
    ; sheet = sheet line
    ; margin
    ; bound
    }
  in
  let run widths = Datasheet.run ~pin:Datasheet.set_pin widths in
  let exact =
    Datasheet.Margin.Ns
      { ns = 0.; why = "the rate has no tolerance: a bit is 192 cycles at 48 MHz" }
  in
  [ row
      "bit at 250 kbit/s, shortest low"
      ~line:"line 291"
      ~margin:exact
      (At_least 4_000.)
      (Datasheet.level ~pin:Datasheet.set_pin ~high:false ())
  ; row
      "bit at 250 kbit/s, shortest high"
      ~line:"line 291"
      ~margin:exact
      (At_least 4_000.)
      (Datasheet.level ~pin:Datasheet.set_pin ~high:true ())
  ; row
      "bit at 250 kbit/s, longest channel low"
      ~line:"line 291"
      ~margin:exact
      (At_most 4_000.)
      (run channel_lows)
  ; row "BREAK transmitted" ~line:"table, lines 303-306" (At_least 92_000.) (run breaks)
  ; row
      "BREAK receiver recognized"
      ~line:"table, lines 303, 308-309"
      (At_least 88_000.)
      (run breaks)
  ; row
      "MAB transmitted"
      ~line:"table, lines 304-305, 307"
      (At_least 12_000.)
      (run marks_after_break)
  ; row
      "MAB receiver recognized"
      ~line:"table, lines 304, 308, 310"
      (At_least 8_000.)
      (run marks_after_break)
  ; row "MAB since 1990" ~line:"line 301" (At_least 8_000.) (run marks_after_break)
  ; row
      "break to break transmitted"
      ~line:"line 313"
      (At_least 1_204_000.)
      (run break_to_break)
  ; row
      "break to break receivers handle"
      ~line:"line 313"
      (At_least 1_196_000.)
      (run break_to_break)
  ; row
      "refresh rate of 512 channels, at most 44 Hz"
      ~line:"line 312"
      (At_least (1e9 /. 44.))
      (run break_to_break)
  ]
;;

(* What sigrok's dmx512 decoder reads of the packet. The line is low from reset until the
   firmware starts, longer than a break, so the decoder joins once the line has idled
   high; from reset it reads that low as a break. The teeth cut the break to 83 us, under
   the 88 a receiver recognises, and flip channel 1's first bit. *)
let sigrok =
  let line = sprintf "dmx512-1: %s" in
  let byte b = line (sprintf "%d / 0x%x" b b) in
  let opening = [ line "Break"; line "MAB"; line "Start code"; byte 0x00 ] in
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "dmx512" ~pins:[ "dmx", pin ] ]
  ; expect =
      [ ( "dmx512=break:mab:startcode:channel:interpacket:data"
        , opening
          @ List.concat_mapi channels ~f:(fun n b ->
            [ line (sprintf "Channel %d" (n + 1)); byte b ])
          @ (line "Interpacket" :: opening) )
      ]
  ; joins_after =
      Some
        ( 1_000
        , { why =
              "the line is low from reset until the firmware starts, which sigrok takes \
               for a break and reads the real one as the start code, framing the \
               channels on the wrong edges"
          ; first_difference = 5
          ; reads = "dmx512-1: 7 / 0x7"
          } )
  ; rejected = None
  ; teeth =
      [ [ Shift { pin; edge = 2; cycles = -(4 * period) } ]
      ; [ Flip { pin; edge = 5; after = period; cycles = period } ]
      ]
  }
;;

(* The host writes eight words, then waits out the bits they take, 194 for the first with
   the break, 176 for the rest, and a few more: the mark stretches before every eighth
   word. Then the next packet's start code. *)
let scenario =
  let words = packet ~start_code:0x00 channels @ [ 0x00 ] in
  let writes =
    List.chunks_of words ~length:Machine.fifo_depth
    |> List.concat_mapi ~f:(fun n chunk ->
      [ Step.Write (Reg.tx, chunk); Run ((if n = 0 then 200 else 180) * period) ])
  in
  { Scenario.name = "dmx512"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Scenario.start; Run 2_000 ]
      @ writes
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "dmx512"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ "dmx512", "a packet is 1092101 cycles, past the 65536 a stamp tells apart" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
