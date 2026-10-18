open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* SNB-1 Snorble Sensor Beacon, Rev. C preliminary: section 4's timing (p.1) and notes 1-3
   (p.2). At 48 MHz: sync 384 cycles (8.0 us), a zero's low 58 (1.208 us), a one's 144
   (3.0 us), every high gap 96 (2.0 us), and 8448 idle after the parity's rise, which
   keeps frames 214 us apart at least, under section 1's 5 kframes/s. *)

let pin = 5

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  ; in_shift = Left
  ; out_shift = Left
  ; crc_width = 1
  ; crc_poly = 1
  ; crc_init = 1
  ; crc_reflect = false
  }
;;

(* The low byte of each host word, MSB first, then odd parity from the CRC, built in isr
   MSB-aligned for osr. p is 24 cycles, half a microsecond: the analyser knows only
   constants [set] makes, so every width is adds of p and of immediates. [t] is the next
   fall on entry to [bit]. *)
let firmware =
  [%firmware
    {|
    set pins, 1              ; idle high
    set p, 24
    mov t, now
    add t, 2                 ; a row only reset reaches, which the teeth can move
idle:
    set x, 31
gap:
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    wait t                   ; 32 waits of 264: idle 8448 since the parity's rise
    jmp x--, gap
    wait tx
    pull
    crc_init
    mov isr, null
    in osr, 8
    out null, 8
    out null, 1              ; through the CRC, unrolled: the certificate's induction
    out null, 1              ; cannot see a counted loop's bound across its passes
    out null, 1
    out null, 1
    out null, 1
    out null, 1
    out null, 1
    out null, 1
    in crc, 1
    in null, 7
    mov osr, isr
    mov t, now
    add t, 2
    wait t
    set pins, 0              ; sync
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p                 ; 384
    wait t
    set pins, 1
    add t, p
    add t, p
    add t, p
    add t, p                 ; 96: the gap
    set x, 8                 ; eight data bits and parity
bit:
    wait t
    set pins, 0
    add t, p
    add t, p
    add t, 7
    add t, 3                 ; 58: a zero
    out y, 1
    jmp y--, one
    jmp low
one:
    add t, p
    add t, p
    add t, p
    add t, 7
    add t, 7                 ; 144: a one
low:
    wait t
    set pins, 1
    add t, p
    add t, p
    add t, p
    add t, p                 ; 96: the gap
    jmp x--, bit
    jmp idle
|}
      ~config]
;;

let certified = [ Certified.of_firmware ~no_wrap:true "snorble" firmware ]
let bytes = [ 0xa5; 0x00; 0xff; 0x3c ]
let cycles_a_frame = 11_000

let bench =
  { Bench.name = "snorble"
  ; what =
      "Snorble.firmware: SIG on OUT0, sync 8.0 us, lows 1.208 and 3.0 us, gaps 2.0 us, \
       frames 214 us apart at least"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus =
      Some
        { bursts = [ bytes ]
        ; quiet = 0
        ; cycles = (List.length bytes + 1) * cycles_a_frame
        }
  }
;;

(* Each low in a run is a sync past 5 us, between tL1's max and tSYN's min, else a bit, a
   one past 2.1 us, between tL0's max and tL1's min, as a receiver tells them. The highs
   inside a frame are those between two bits, which note 1 bounds above. *)
let limits =
  let sheet page =
    { Datasheet.Sheet.part = "Snorble"
    ; document = "SNB-1 Snorble Sensor Beacon Rev. C"
    ; page
    }
  in
  let table = "section 4, p.1" in
  let sync ~clock_hz l = l >= Datasheet.cycles ~clock_hz 5_000. in
  let one ~clock_hz l = l >= Datasheet.cycles ~clock_hz 2_100. in
  let lows f =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter (Datasheet.lows levels) ~f:(f ~clock_hz))
  in
  let in_frame =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter_map
        (List.zip_exn
           (List.drop_last_exn (Datasheet.pairs levels))
           (List.drop (Datasheet.pairs levels) 1))
        ~f:(fun (((before, b), (high, h)), (_, (after, a))) ->
          Option.some_if
            ((not before)
             && high
             && (not after)
             && (not (sync ~clock_hz b))
             && not (sync ~clock_hz a))
            h))
  in
  let idle =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, h), (_, l)) ->
        Option.some_if (high && sync ~clock_hz l) h)
      |> Fn.flip List.drop 1)
  in
  (* sync fall to sync fall *)
  let frames =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      let _, starts =
        List.fold levels ~init:(0, []) ~f:(fun (at, starts) (high, n) ->
          at + n, if (not high) && sync ~clock_hz n then at :: starts else starts)
      in
      let starts = List.rev starts in
      List.map2_exn (List.drop_last_exn starts) (List.tl_exn starts) ~f:(fun a b -> b - a))
  in
  let limit parameter limit page bound =
    { Datasheet.firmware = "snorble"
    ; parameter
    ; limit
    ; sheet = sheet page
    ; margin = Cycle
    ; bound
    }
  in
  [ limit "tSYN" (At_least 7_500.) table (lows (fun ~clock_hz l -> sync ~clock_hz l))
  ; limit "tSYN" (At_most 8_500.) table (lows (fun ~clock_hz l -> sync ~clock_hz l))
  ; limit
      "tL0"
      (At_least 1_100.)
      table
      (Datasheet.level ~pin:Datasheet.set_pin ~high:false ())
  ; limit "tL0" (At_most 1_300.) table (lows (fun ~clock_hz l -> not (one ~clock_hz l)))
  ; limit
      "tL1"
      (At_least 2_900.)
      table
      (lows (fun ~clock_hz l -> one ~clock_hz l && not (sync ~clock_hz l)))
  ; limit
      "tL1"
      (At_most 3_100.)
      table
      (lows (fun ~clock_hz l -> one ~clock_hz l && not (sync ~clock_hz l)))
  ; limit
      "tH"
      (At_least 1_800.)
      table
      (Datasheet.level ~pin:Datasheet.set_pin ~high:true ())
  ; limit "tH" (At_most 4_000.) "section 4, p.1, and note 1, p.2: inside a frame" in_frame
  ; limit "tIFG" (At_least 20_000.) "section 4, p.1, and note 3, p.2" idle
  ; limit
      "frame rate"
      (At_least 200_000.)
      "section 1, p.1: about 5 kframes/s at most"
      frames
  ]
;;

(* Snorble frames back from the pin's levels: a sync, then nine lows, each a one past 2.1
   us, then a high of 20 us at least. The byte, and whether its parity is odd. *)
let decode ~clock_hz (levels : (bool * int) list) =
  let sync n = n >= Datasheet.cycles ~clock_hz 5_000. in
  let rec frames acc = function
    | [] -> List.rev acc
    | (false, n) :: rest when sync n ->
      let lows =
        List.filter_map (List.take rest 18) ~f:(fun (high, n) ->
          Option.some_if (not high) n)
      in
      if List.length lows < 9
      then List.rev acc
      else (
        let bits =
          List.map lows ~f:(fun n -> Bool.to_int (n >= Datasheet.cycles ~clock_hz 2_100.))
        in
        let byte = List.fold (List.take bits 8) ~init:0 ~f:(fun b x -> (b lsl 1) lor x) in
        let odd = List.sum (module Int) bits ~f:Fn.id % 2 = 1 in
        frames ((byte, odd) :: acc) (List.drop rest 18))
    | _ :: rest -> frames acc rest
  in
  frames [] levels
;;

let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "snorble" ~pins:[ "sig", pin ] ]
  ; expect =
      [ ( "snorble=byte:parity-ok"
        , List.concat_map bytes ~f:(fun b -> [ sprintf "%02X" b; "Parity OK" ])
          |> Sigrok.lines "snorble" )
      ]
  ; joins_after = None
  ; rejected = None
  ; (* edges from 0, the rise out of reset: edge 4 ends the first bit's low, a one's 144
       cycles cut to a zero's 58 *)
    teeth = [ [ Shift { pin; edge = 4; cycles = -86 } ] ]
  }
;;

let scenario =
  { Scenario.name = "snorble"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Write (Reg.tx, bytes)
        ; Scenario.start
        ; Run ((List.length bytes + 1) * cycles_a_frame)
        ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "snorble"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept = [ "snorble", "idles 8448 cycles a frame, past the sweep's window" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
