open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* SB-Projects, "NEC Protocol", last updated 17 July 2025, one page; numbers by line of
   the limit table's text (spec.txt):
   {v
   carrier       38 kHz, duty 1/4 or 1/3                     lines 17, 21, 23
   burst         560 us of carrier                           line 21
   bit           1.125 ms a zero, 2.25 ms a one, LSB first   lines 18, 22, 26
   frame         9 ms AGC burst, 4.5 ms space, address, its
                 inverse, command, its inverse, a burst      lines 28-31, 34
   repeat code   9 ms AGC, 2.25 ms space, a burst, every
                 110 ms while the key is down                lines 36-37
   v}
   The spec gives nominal times only; each is taken as the least the line may give. The
   line is the LED's drive: high for the carrier's on third, low otherwise. *)

let pin = 5

(* A third of a 38 kHz period. 422 cycles at 48 MHz is 8.79 us (a 37.9 kHz carrier), so
   every count of thirds below, worked out for exactly 38 kHz, comes out at or over its
   time. *)
let standard_third = 422
let shortest_third = 16
let config = { Program_config.default with set_base = pin; set_count = 1 }

(* The host loads the third once, then per message a word: 0 for a frame, anything else for
   a repeat code. A frame also gets the address and command as one word. The firmware
   sends each byte then its inverse, so a frame is always 7780 thirds, and each message
   starts at least 12540 thirds (110 ms) after the one before. [t] is the next third
   throughout; a pulse is high a third and low two. The osr holds the address and its
   inverse, then [isr]'s command and its inverse; a repeat code leaves it empty and [isr]
   zero. *)
let firmware =
  [%firmware
    {|
    wait tx
    pull
    mov p, osr               ; a third of the carrier period
    set pins, 0
message:
    wait tx
    pull
    out x, 16                ; the kind, leaving the osr empty
    mov isr, null
    jmp x--, start           ; a repeat code
    wait tx
    pull                     ; command in the high byte, address in the low
    mov y, osr
    out null, 8
    in osr, 8
    mov osr, !osr
    in osr, 8                ; command, then its inverse
    mov x, isr
    mov osr, y
    in osr, 8
    mov osr, !osr
    in osr, 8                ; address, then its inverse
    mov osr, isr
    mov isr, x
start:
    mov t, now
    add t, p
    set y, 17
agc_row:
    set x, 18
agc:
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    jmp x--, agc
    jmp y--, agc_row         ; 342 periods
    wait t+
    set pins, 1
    wait t+
    set pins, 0              ; and a pulse: 1027 thirds, 9 ms
    set y, 7
space_row:
    set x, 31
space:
    wait t+
    jmp x--, space
    jmp y--, space_row       ; 257 thirds to the rise, 2.25 ms
    jmp !osre, frame_space
    set y, 0                 ; a repeat code's one burst
    jmp burst
frame_space:
    set y, 7
frame_row:
    set x, 31
frame:
    wait t+
    jmp x--, frame
    jmp y--, frame_row       ; 513 thirds, 4.5 ms
    set y, 1                 ; two halves of 16 bits
burst:
    set x, 20
pulse:
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    jmp x--, pulse           ; 21 periods
    wait t+
    set pins, 1
    wait t+
    set pins, 0              ; and a pulse: 64 thirds, 560 us
    jmp !osre, bit
    mov osr, isr
    jmp y--, bit             ; the command's half
    mov x, isr
    jmp x--, frame_pad
    set y, 30
repeat_row:
    set x, 25
repeat_pad:
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    jmp x--, repeat_pad
    jmp y--, repeat_row      ; 6448 thirds
frame_pad:
    set y, 22
pad_row:
    set x, 25
pad:
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    wait t+
    jmp x--, pad
    jmp y--, pad_row         ; 4784 thirds
    jmp message
bit:
    out x, 1
    jmp x--, one
    jmp zero
one:
    set x, 31
one_space:
    wait t+
    wait t+
    wait t+
    wait t+
    jmp x--, one_space       ; 128 thirds more for a one
zero:
    set x, 31
zero_space:
    wait t+
    wait t+
    jmp x--, zero_space      ; 64 thirds, 129 from the rise for a zero
    jmp burst
|}
      ~config
      ~period_floor:shortest_third]
;;

let certified = [ Certified.of_firmware ~period:standard_third "ir_nec" firmware ]

module Message = struct
  type t =
    | Frame of
        { address : int
        ; command : int
        }
    | Repeat_code
  [@@deriving sexp_of, equal]
end

let words : Message.t -> int list = function
  | Frame { address; command } -> [ 0; address lor (command lsl 8) ]
  | Repeat_code -> [ 1 ]
;;

module Burst = struct
  type t =
    { rise : int
    ; fall : int
    ; periods : int list
    ; highs : int list
    }
end

(* Demodulated: a low of two carrier periods or more ends a burst. *)
let bursts ~clock_hz (levels : Datasheet.Levels.t) =
  let _, runs =
    List.fold_map levels ~init:0 ~f:(fun at (high, n) -> at + n, (high, at, n))
  in
  let pulses =
    List.filter_map runs ~f:(fun (high, at, n) -> Option.some_if high (at, n))
  in
  List.group pulses ~break:(fun (rise, high) (next, _) ->
    (next - rise - high) * 19_000 >= clock_hz)
  |> List.map ~f:(fun pulses ->
    let rise, _ = List.hd_exn pulses
    and last, high = List.last_exn pulses in
    let rises = List.map pulses ~f:fst in
    { Burst.rise
    ; fall = last + high
    ; periods =
        List.map2_exn (List.drop_last_exn rises) (List.tl_exn rises) ~f:(fun a b -> b - a)
    ; highs = List.map pulses ~f:snd
    })
;;

(* Each AGC burst, 4 ms or more, with the bursts after it up to the next. *)
let messages ~clock_hz levels =
  let agc (b : Burst.t) = (b.fall - b.rise) * 250 >= clock_hz in
  List.group (bursts ~clock_hz levels) ~break:(fun _ b -> agc b)
  |> List.map ~f:(function
    | first :: rest when agc first -> Ok (first, rest)
    | _ -> Or_error.error_s [%message "a burst before any AGC burst"])
;;

let runs levels =
  List.group levels ~break:Bool.( <> )
  |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
;;

let pairs xs = List.zip_exn (List.drop_last_exn xs) (List.tl_exn xs)

let decode ~clock_hz levels =
  let open Or_error.Let_syntax in
  (* within 5%, sigrok's tolerance, exactly *)
  let near cycles ~ns =
    abs ((cycles * 1_000_000_000) - (ns * clock_hz)) * 20 <= ns * clock_hz
  in
  (* a one's bit and a frame's space from the midpoint *)
  let over cycles ~ns = cycles * 1_000_000_000 >= ns * clock_hz in
  let timed measured cycles ~ns ~name =
    let got = Measured.ns ~clock_hz cycles in
    if near cycles ~ns
    then return (Measured.add measured ~name ~ns:got)
    else Or_error.error_s [%message "out of spec" name ~ns:(got : int)]
  in
  let burst ~ns ~name measured (b : Burst.t) =
    let%bind measured =
      List.fold_result b.periods ~init:measured ~f:(fun measured period ->
        let ns = Measured.ns ~clock_hz period in
        if abs ((period * 38_000) - clock_hz) * 20 <= clock_hz
        then return (Measured.add measured ~name:"carrier period" ~ns)
        else Or_error.error_s [%message "not a 38 kHz carrier" (ns : int)])
    in
    let measured =
      List.fold b.highs ~init:measured ~f:(fun measured high ->
        Measured.add measured ~name:"carrier high" ~ns:(Measured.ns ~clock_hz high))
    in
    timed measured (b.fall - b.rise) ~ns ~name
  in
  let frame measured bursts =
    let%bind () =
      if List.length bursts = 33
      then return ()
      else Or_error.error_s [%message "not 33 bursts" ~bursts:(List.length bursts : int)]
    in
    let%bind measured =
      List.fold_result bursts ~init:measured ~f:(burst ~ns:560_000 ~name:"burst")
    in
    let%bind measured, bits =
      List.fold_result
        (pairs (List.map bursts ~f:(fun (b : Burst.t) -> b.rise)))
        ~init:(measured, [])
        ~f:(fun (measured, bits) (a, b) ->
          let one = over (b - a) ~ns:1_687_500 in
          let%map measured =
            if one
            then timed measured (b - a) ~ns:2_250_000 ~name:"one"
            else timed measured (b - a) ~ns:1_125_000 ~name:"zero"
          in
          measured, one :: bits)
    in
    let value =
      List.foldi (List.rev bits) ~init:0 ~f:(fun i acc one ->
        if one then acc lor (1 lsl i) else acc)
    in
    let byte i = (value lsr (8 * i)) land 0xff in
    if byte 0 lxor byte 1 = 0xff && byte 2 lxor byte 3 = 0xff
    then return (measured, Message.Frame { address = byte 0; command = byte 2 })
    else Or_error.error_s [%message "a byte not followed by its inverse" (value : int)]
  in
  let message measured ((agc : Burst.t), rest) =
    let%bind measured = burst measured agc ~ns:9_000_000 ~name:"AGC burst" in
    match rest with
    | [] -> Or_error.error_s [%message "an AGC burst alone"]
    | (first : Burst.t) :: _ ->
      let space = first.rise - agc.fall in
      if over space ~ns:3_375_000
      then (
        let%bind measured = timed measured space ~ns:4_500_000 ~name:"frame space" in
        frame measured rest)
      else (
        let%bind measured = timed measured space ~ns:2_250_000 ~name:"repeat space" in
        match rest with
        | [ b ] ->
          let%map measured = burst measured b ~ns:560_000 ~name:"repeat burst" in
          measured, Message.Repeat_code
        | _ -> Or_error.error_s [%message "a repeat code of more than one burst"])
  in
  let%bind messages = messages ~clock_hz (runs levels) |> Or_error.all in
  let%bind measured =
    match List.map messages ~f:(fun ((agc : Burst.t), _) -> agc.rise) with
    | [] -> return Measured.empty
    | starts ->
      List.fold_result (pairs starts) ~init:Measured.empty ~f:(fun measured (a, b) ->
        timed measured (b - a) ~ns:110_000_000 ~name:"message period")
  in
  let%map measured, sent =
    List.fold_result messages ~init:(measured, []) ~f:(fun (measured, sent) m ->
      let%map measured, m = message measured m in
      measured, m :: sent)
  in
  List.rev sent, measured
;;

(* The spec's example frame, line 27, then two repeat codes. *)
let sent = [ Message.Frame { address = 0x59; command = 0x16 }; Repeat_code; Repeat_code ]

(* thirds from a message's start to the next, with what the host costs, and some over *)
let message_thirds = 12_600

let bench =
  { Bench.name = "ir_nec"
  ; what =
      [%string
        "Ir_nec.firmware: an NEC frame then repeat codes, %{standard_third#Int} cycles a \
         third of the 38 kHz carrier, the line high for the carrier's on third, on OUT0"]
  ; source = Timed_program.source firmware
  ; config = Timed_program.config firmware
  ; assumption = Floor shortest_third
  ; clock_hz = Bench.clock_hz
  ; load = Some standard_third
  ; stimulus =
      Some
        { bursts = List.map (List.take sent 2) ~f:words
        ; quiet = 0
        ; cycles = (message_thirds + 1_500) * standard_third
        }
  }
;;

(* A row for each of limits.tsv's, by its line of spec.txt, each nominal taken as the
   least. All are the run's, since the bursts and spaces are loops of waits. Not the 110 ms
   repeat code interval (line 36): 5.3 million cycles at 48 MHz is past what [Datasheet]
   solves a clock for, and [decode] holds it to 5%. *)
let limits =
  let sheet lines =
    { Datasheet.Sheet.part = "NEC infrared remote"
    ; document = "SB-Projects, NEC Protocol, updated 17 July 2025"
    ; page = [%string "page 1, %{lines}"]
    }
  in
  let row parameter ~ns ~lines widths =
    { Datasheet.firmware = bench.name
    ; parameter
    ; limit = At_least ns
    ; sheet = sheet lines
    ; margin = Cycle
    ; bound =
        Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
          widths ~clock_hz (messages ~clock_hz levels |> List.filter_map ~f:Result.ok))
    }
  in
  let frames ms = List.filter ms ~f:(fun (_, rest) -> List.length rest > 1) in
  let repeats ms = List.filter ms ~f:(fun (_, rest) -> List.length rest = 1) in
  let length (b : Burst.t) = b.fall - b.rise in
  let agc ms = List.map ms ~f:(fun ((agc : Burst.t), _) -> length agc) in
  let space ms =
    List.filter_map ms ~f:(fun ((agc : Burst.t), rest) ->
      List.hd rest |> Option.map ~f:(fun (b : Burst.t) -> b.rise - agc.fall))
  in
  let bits ~one ~clock_hz ms =
    List.concat_map (frames ms) ~f:(fun (_, rest) ->
      pairs (List.map rest ~f:(fun (b : Burst.t) -> b.rise))
      |> List.map ~f:(fun (a, b) -> b - a)
      |> List.filter ~f:(fun bit ->
        Bool.equal one (bit >= Datasheet.cycles ~clock_hz 1_687_500.)))
  in
  let repeat_bursts ~clock_hz:_ ms =
    List.concat_map (repeats ms) ~f:(fun (_, rest) -> List.map rest ~f:length)
  in
  let repeat_space ~clock_hz:_ ms = space (repeats ms) in
  [ row
      "Carrier frequency, as its period"
      ~ns:(1e9 /. 38_000.)
      ~lines:"line 17"
      (fun ~clock_hz:_ ms ->
         List.concat_map ms ~f:(fun (agc, rest) ->
           List.concat_map (agc :: rest) ~f:(fun (b : Burst.t) -> b.periods)))
  ; row "Bit time, logical 0" ~ns:1.125e6 ~lines:"line 18" (bits ~one:false)
  ; row "Bit time, logical 1" ~ns:2.25e6 ~lines:"line 18" (bits ~one:true)
  ; row "Carrier burst length" ~ns:560e3 ~lines:"line 21" (fun ~clock_hz:_ ms ->
      List.concat_map ms ~f:(fun (_, rest) -> List.map rest ~f:length))
  ; row "AGC burst, message start" ~ns:9e6 ~lines:"line 28" (fun ~clock_hz:_ ms ->
      agc (frames ms))
  ; row
      "Space after AGC burst, message start"
      ~ns:4.5e6
      ~lines:"line 29"
      (fun ~clock_hz:_ ms -> space (frames ms))
  ; row "Extra burst at end of message" ~ns:560e3 ~lines:"line 34" (fun ~clock_hz:_ ms ->
      List.filter_map (frames ms) ~f:(fun (_, rest) ->
        List.last rest |> Option.map ~f:length))
  ; row "AGC pulse, repeat code" ~ns:9e6 ~lines:"line 37" (fun ~clock_hz:_ ms ->
      agc (repeats ms))
  ; row "Space after AGC pulse, repeat code" ~ns:2.25e6 ~lines:"line 37" repeat_space
  ; row "Burst, repeat code" ~ns:560e3 ~lines:"line 37" repeat_bursts
  ; row "Repeat code space" ~ns:2.25e6 ~lines:"line 37" repeat_space
  ; row "Repeat code burst" ~ns:560e3 ~lines:"line 37" repeat_bursts
  ]
;;

(* The trace's clock: [shortest_third] cycles a third of 38 kHz exactly. *)
let trace_clock_hz = 114_000 * shortest_third

let sigrok =
  { Sigrok.clock_hz = trace_clock_hz
  ; decoders =
      [ Sigrok.decoder
          "ir_nec"
          ~pins:[ "ir", pin ]
          ~options:[ "polarity", "active-high"; "cd_freq", "38000" ]
      ]
  ; expect =
      (let bits byte = List.init 8 ~f:(fun i -> Int.to_string ((byte lsr i) land 1)) in
       let field name byte = bits byte @ [ sprintf "%s: 0x%02X" name byte ] in
       [ ( "ir_nec=bit:agc-pulse:longpause:shortpause:stop-bit:leader-code:addr:addr-inv:cmd:cmd-inv:repeat-code:remote"
         , [ "AGC pulse"; "Long pause"; "Leader code" ]
           @ field "Address" 0x59
           @ field "Address#" 0xa6
           @ field "Command" 0x16
           @ field "Command#" 0xe9
           @ [ "Stop bit"
             ; "Unknown device: Unknown"
             ; "AGC pulse"
             ; "Short pause"
             ; "Stop bit"
             ; "Repeat code"
             ]
           |> Sigrok.lines "ir_nec" )
       ])
  ; joins_after = None
  ; rejected = None
  ; (* a pulse 100 thirds into the 4.5 ms space, after the AGC burst's last fall (edge 685);
       and the second data burst's first rise (edge 730) 128 thirds early, so the address's
       first bit, a one, reads as a zero *)
    teeth =
      [ [ Flip { pin; edge = 685; after = 100 * shortest_third; cycles = shortest_third }
        ]
      ; [ Shift { pin; edge = 730; cycles = -128 * shortest_third } ]
      ]
  }
;;

(* The frame and a repeat code, the frame 10 ms after the load: sigrok's ir_nec times its
   first edge from the capture's start and reads a repeat code there if that is 11.25 ms.
   It ends a frame only at the next AGC burst's rise, and reads a repeat code at its
   burst's. *)
let scenario =
  { Scenario.name = "ir_nec"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ [ Scenario.start
        ; Write (Reg.tx, [ shortest_third ])
        ; Run (1_140 * shortest_third)
        ; Write (Reg.tx, List.concat_map (List.take sent 2) ~f:words)
        ; Run ((message_thirds + 1_500) * shortest_third)
        ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "ir_nec"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "ir_nec"
        , "the 4.5 ms space after the AGC burst is 216000 cycles, past the 65536 a stamp \
           tells apart" )
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
