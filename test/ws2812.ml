open! Core
open Protocol_emulator

let pin = 5
let cycle_ns = 20

(* y is bits in the word less one: 15 then 7 per pixel. Both paths round a word's end take
   thirteen cycles, fourteen with a tail over 7. The reset gap waits on every pass of its
   loop, not once after, so [t] is never more than five thirds ahead of [now] and the
   kernel accepts the loop; y counts its turns before a frame takes it. *)
let latching ~gaps ~third ~tail =
  if gaps < 1 || gaps > 32 || tail < 0 || tail > 14
  then raise_s [%message "BUG: gaps or tail out of range" (gaps : int) (tail : int)];
  let gap_turns, gap_again =
    if gaps = 1
    then "", ""
    else [%string "    set y, %{gaps - 1#Int}\ngaps:\n"], "    jmp y--, gaps\n"
  in
  let add_tail =
    if tail <= 7
    then [%string "    add t, %{tail#Int}\n"]
    else [%string "    add t, 7\n    add t, %{tail - 7#Int}\n"]
  in
  [%string
    {|
    mov t, now
    set pins, 0
    set p, %{third#Int}
latch:
    mov t, now
%{gap_turns}    set x, 31
gap:
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    wait t
    jmp x--, gap
%{gap_again}    wait tx                  ; the line has been low for 160 thirds
    mov t, now
    add t, p
pixel:
    set y, 15
word:
    pull
    mov x, y
bit:
    wait t+
    set pins, 1              ; rise
    wait t+
    out pins, 1              ; a zero falls here
    wait t+
    set pins, 0              ; a one falls here
%{add_tail}    jmp x--, bit
    set x, 15
    jmp x!=y, last
    set y, 7
    jmp word
last:
    jmp tx, pixel
    jmp latch
|}]
;;

let firmware = latching ~gaps:1
let standard = firmware ~third:20 ~tail:2

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  ; out_shift = Left
  }
;;

module Pixel = struct
  type t =
    { red : int
    ; green : int
    ; blue : int
    }
  [@@deriving sexp_of, compare, equal]

  let words t = [ (t.green lsl 8) lor t.red; t.blue lsl 8 ]

  let of_bits bits =
    let byte bits = List.fold bits ~init:0 ~f:(fun acc b -> (acc lsl 1) lor b) in
    match List.chunks_of bits ~length:8 with
    | [ green; red; blue ] -> { red = byte red; green = byte green; blue = byte blue }
    | _ -> raise_s [%message "BUG: a pixel is 24 bits" (List.length bits : int)]
  ;;
end

module Strip = struct
  type t =
    { cycle_ns : int
    ; level : int
    ; run : int
    ; pending : int option (* the bit whose low time is running *)
    ; bits : int list
    ; frames : Pixel.t list list
    ; measured : Measured.t
    ; violations : string list
    }

  let tolerance_ns = 150
  let reset_ns = 50_000
  let zero_high_ns = 400
  let zero_low_ns = 850
  let one_high_ns = 800
  let one_low_ns = 450

  let create ~cycle_ns =
    { cycle_ns
    ; level = 0
    ; run = 0
    ; pending = None
    ; bits = []
    ; frames = []
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let within ns ~nominal = abs (ns - nominal) <= tolerance_ns

  let checked t ~name ~ns ~nominal =
    let t = { t with measured = Measured.add t.measured ~name ~ns } in
    if within ns ~nominal
    then t
    else { t with violations = [%string "%{name} of %{ns#Int} ns"] :: t.violations }
  ;;

  let fell t ~ns =
    let bit = if ns > (zero_high_ns + one_high_ns) / 2 then 1 else 0 in
    let t =
      if bit = 1
      then checked t ~name:"T1H" ~ns ~nominal:one_high_ns
      else checked t ~name:"T0H" ~ns ~nominal:zero_high_ns
    in
    { t with bits = bit :: t.bits; pending = Some bit }
  ;;

  let rose t ~ns =
    match t.pending with
    | None -> t
    | Some 1 -> checked t ~name:"T1L" ~ns ~nominal:one_low_ns
    | Some _ -> checked t ~name:"T0L" ~ns ~nominal:zero_low_ns
  ;;

  let latch t =
    let bits = List.rev t.bits in
    let pixels, rest =
      List.chunks_of bits ~length:24 |> List.partition_tf ~f:(fun p -> List.length p = 24)
    in
    let violations =
      match rest with
      | [] -> t.violations
      | _ -> [%string "frame of %{List.length bits#Int} bits"] :: t.violations
    in
    { t with
      pending = None
    ; bits = []
    ; frames = List.map pixels ~f:Pixel.of_bits :: t.frames
    ; violations
    }
  ;;

  let step t ~level =
    if level <> t.level
    then (
      let ns = t.run * t.cycle_ns in
      let t = if level = 0 then fell t ~ns else rose t ~ns in
      { t with level; run = 1 })
    else (
      let t = { t with run = t.run + 1 } in
      if level = 0 && Option.is_some t.pending && t.run * t.cycle_ns >= reset_ns
      then latch t
      else t)
  ;;

  let frames t = List.rev t.frames
  let measured t = t.measured
  let violations t = List.rev t.violations
end

(* SK6812, 012 B/0: a bit of 1.2 us at least and a reset of 200 us *)
let bench_third = 17
let bench_tail = 8
let bench_gaps = (Bench.cycles_in ~us:200 / (160 * bench_third)) + 1

let bench =
  { Bench.name = "sk6812"
  ; what =
      (let third = bench_third
       and tail = bench_tail
       and time = Bench.time in
       [%string
         "Ws2812.latching ~gaps:%{bench_gaps#Int} ~third:%{third#Int} ~tail:%{tail#Int}: \
          T0H %{time third}, T1H %{time (2 * third)}, T0L %{time ((2 * third) + tail)}, \
          T1L %{time (third + tail)}, a bit of %{time ((3 * third) + tail)}, %{time \
          (bench_gaps * 160 * third)} low before a frame, on OUT3"])
  ; source = latching ~gaps:bench_gaps ~third:bench_third ~tail:bench_tail
  ; config = { config with out_base = Bench.neopixel; set_base = Bench.neopixel }
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus =
      (let pixels =
         List.concat_map
           [ { Pixel.red = 0x0f; green = 0xf0; blue = 0x55 }
           ; { red = 0xaa; green = 0x33; blue = 0xcc }
           ]
           ~f:Pixel.words
       in
       Some { bursts = [ pixels; pixels; pixels ]; quiet = 200; cycles = 60_000 })
  }
;;

(* SK6812: the low of a bit is under 20 us (012 B/0, note 3), so a longer one latches, and
   a high under 500 ns is a zero, between the B/0 sheet's T0H and T1H. A cycle of margin
   covers the 74AHCT125's skew between rise and fall, 5.5 ns at most. *)
let limits =
  let rev01 =
    { Datasheet.Sheet.part = "SK6812"
    ; document = "SPC/SK6812 Rev. 01"
    ; page = "p.5, 0.3/0.6/0.9/0.6 us +-0.15"
    }
  and b0 =
    { Datasheet.Sheet.part = "SK6812"
    ; document = "OSK-SPC-SK6812-012 Rev. B/0"
    ; page = "p.7"
    }
  in
  let bits ~clock_hz levels =
    List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, h), (_, l)) ->
      Option.some_if (high && l < Datasheet.cycles ~clock_hz 20_000.) (h, l))
  in
  let zero ~clock_hz (h, _) = h < Datasheet.cycles ~clock_hz 500. in
  let code ~one f =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter_map (bits ~clock_hz levels) ~f:(fun bit ->
        Option.some_if (Bool.equal one (not (zero ~clock_hz bit))) (f bit)))
  in
  let limit parameter limit sheet bound =
    { Datasheet.firmware = "sk6812"; parameter; limit; sheet; margin = Cycle; bound }
  in
  [ limit "T0H" (At_least 200.) b0 (Datasheet.level ~pin:Datasheet.set_pin ~high:true ())
  ; limit "T0H" (At_most 400.) b0 (code ~one:false fst)
  ; limit "T1H" (At_least 600.) b0 (code ~one:true fst)
  ; limit "T1H" (At_most 750.) rev01 (code ~one:true fst)
  ; limit "T0L" (At_least 800.) b0 (code ~one:false snd)
  ; limit "T0L" (At_most 1050.) rev01 (code ~one:false snd)
  ; limit
      "T1L"
      (At_least 450.)
      rev01
      (Datasheet.level ~pin:Datasheet.set_pin ~high:false ())
  ; limit "T1L" (At_most 750.) rev01 (code ~one:true snd)
  ; limit
      "T"
      (At_least 1200.)
      { b0 with page = "p.7, note 2" }
      (Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
         List.map (bits ~clock_hz levels) ~f:(fun (h, l) -> h + l)))
  ; limit
      "reset"
      (At_least 200_000.)
      b0
      (Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
         List.filter (Datasheet.lows levels) ~f:(fun l ->
           l >= Datasheet.cycles ~clock_hz 20_000.)))
  ]
;;

open Pin_trace
module Reg = Host_port.Reg

let scenario =
  let pixel red green blue = { Pixel.red; green; blue } in
  let frames =
    [ [ pixel 0xff 0 0; pixel 0 0xff 0; pixel 0 0 0xff ]
    ; [ pixel 0x12 0x34 0x56; pixel 0xab 0xcd 0xef ]
    ]
  in
  (* a bit is 62 cycles, and 3200 low latch the string *)
  let send pixels =
    [ Step.Write (Reg.tx, List.concat_map pixels ~f:Pixel.words)
    ; Run ((List.length pixels * 24 * 62) + 3200 + 2000)
    ]
  in
  { Scenario.name = "ws2812"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load ~config ~program:(Firmware.assemble standard)
      @ [ Scenario.start ]
      @ List.concat_map frames ~f:send
  ; sigrok =
      Some
        { clock_hz = 48_000_000
        ; decoders = [ Sigrok.decoder "rgb_led_ws281x" ~pins:[ "din", pin ] ]
        ; expect =
            [ ( "rgb_led_ws281x=rgb:reset"
              , List.concat_map frames ~f:(fun pixels ->
                  List.map pixels ~f:(fun { red; green; blue } ->
                    sprintf "#%02x%02x%02x" red green blue)
                  @ [ "RESET" ])
                |> Sigrok.lines "rgb_led_ws281x" )
            ]
        ; joins_after = None
        ; rejected = None
        ; (* the first bit's high stretched from T0H to T1H *)
          teeth = [ [ Shift { pin; edge = 1; cycles = 20 } ] ]
        }
  }
;;

let protocol =
  { Protocol.name = "ws2812"
  ; certified =
      [ Certified.plain ~no_wrap:true "ws2812" (firmware ~third:6 ~tail:7) config ]
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept = [ "ws2812", "48 edges a pixel in 600 cycles: the fifo holds 8" ]
  ; scenarios = []
  ; decoded = [ scenario ]
  }
;;
