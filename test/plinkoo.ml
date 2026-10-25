open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* PLK-2 Plinkoo Two-Wire Packet Bus, revision 1.3: section 4's timing (pp.1-2), section
   5's framing and notes 1-5 (p.2). At 48 MHz: sync 248 cycles (5.167 us), so tB is 15.5
   cycles and note 1 allows 14.57 to 16.43; each bit is 16 (333 ns, 3 MHz), STB high 8
   then low 8. DAT moves 1 after the fall (tDS 146 ns, tDH 187 ns) and is let go 4 after
   the checksum's last rise (83 ns, between tDH's 80 and tREL's 100). *)

let stb = 10
let dat = 15
let sync = 248

let config =
  { Program_config.default with
    in_base = dat
  ; in_count = 1
  ; out_base = dat
  ; out_count = 1
  ; set_base = stb
  ; set_count = 1
  ; in_shift = Left
  ; out_shift = Left
  ; pull_threshold = 8
  }
;;

(* The host writes L then L bytes, each in a word's high byte; the firmware takes L, waits
   160 us for the rest to land in the fifo, sends sync, L, the bytes and the checksum,
   then the ack bit, and pushes DAT as it sampled it: 0 acknowledged, 1 not. osr holds
   each byte inverted, as a direction bit of 1 pulls DAT low; y the negated sum, x the
   payload bytes still to load after the next. Each byte's loop loads the next byte while
   STB is low after its last bit. [t] is the next fall on entry to a loop, and each
   [wait t+] moves it 8 on. *)
let firmware =
  [%firmware
    {|
    set pins, 1              ; STB idles high, DAT let go
frame:
    set p, 30
    wait tx
    pull                     ; L
    mov isr, osr
    mov t, now
    set x, 31
pause:
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    wait t                   ; 32 waits of 240: 160 us for the host's bytes
    jmp x--, pause
    mov osr, isr
    out x, 8
    sub x, 1
    mov osr, !isr
    set y, 0
    sub y, isr
    set p, 31
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
    add t, p                 ; 248
    wait t
    set pins, 1
    set p, 8
    add t, p
    add t, p
    add t, p                 ; tSYH 24, to the first fall
more:
    wait t+
    set pins, 0
    out pindirs, 1           ; DAT 1 after the fall
    jmp !osre, more_rise
    pull                     ; a payload byte
    sub y, osr
    mov osr, !osr
    wait t+
    set pins, 1
    jmp x--, more
    jmp last
more_rise:
    wait t+
    set pins, 1
    jmp more
last:
    wait t+
    set pins, 0
    out pindirs, 1
    jmp !osre, last_rise
    mov osr, !y              ; the checksum
    wait t+
    set pins, 1
    jmp check
last_rise:
    wait t+
    set pins, 1
    jmp last
check:
    wait t+
    set pins, 0
    out pindirs, 1
    jmp !osre, check_rise
    wait t
    set pins, 1              ; the checksum's last rise
    mov isr, null
    add t, 4
    wait t
    mov pindirs, null        ; DAT let go 4 after it
    add t, 3
    wait t
    in pins, 1               ; the ack, 9 before its rise
    set pins, 0
    add t, 7
    add t, 2
    wait t
    set pins, 1              ; the ack bit's rise
    push
    jmp frame
check_rise:
    wait t+
    set pins, 1
    jmp check
|}
      ~config]
;;

let certified = [ Certified.of_firmware ~no_wrap:true "plinkoo" firmware ]
let checksum bytes = (256 - (List.sum (module Int) bytes ~f:Fn.id % 256)) % 256
let words payload = List.map (List.length payload :: payload) ~f:(fun b -> b lsl 8)

(* section 6's frame, then one of eight bytes *)
let frames = [ [ 0x12; 0x34; 0x56 ]; [ 0x00; 0xff; 0x80; 0x01; 0xa5; 0x5a; 0x7e; 0xc3 ] ]
let cycles_a_frame = 9_600

(* A peripheral that takes DAT at each rise of STB after a sync, a low past 1 us, and once
   the checksum is in and right, with L from 1 to 8, pulls DAT low 5 cycles after that
   rise, past tREL, until 5 after the ack bit's rise. *)
module Peripheral = struct
  type t =
    { stb : bool
    ; low : int
    ; bits : int list (* newest first *)
    ; in_frame : bool
    ; pull_in : int option
    ; holding : bool
    ; release_in : int option
    ; frames : (int list * bool) list (* newest first: the bytes and the ack *)
    }

  let create () =
    { stb = true
    ; low = 0
    ; bits = []
    ; in_frame = false
    ; pull_in = None
    ; holding = false
    ; release_in = None
    ; frames = []
    }
  ;;

  let pulls_low t = t.holding

  let bytes bits =
    List.rev bits
    |> List.chunks_of ~length:8
    |> List.map ~f:(List.fold ~init:0 ~f:(fun b x -> (b lsl 1) lor x))
  ;;

  let take t ~dat =
    let bits = Bool.to_int dat :: t.bits in
    let length = if List.length bits >= 8 then List.hd_exn (bytes bits) else 0 in
    let got = List.length bits in
    if got = 8 && (length < 1 || length > 8)
    then { t with bits = []; in_frame = false; frames = ([ length ], false) :: t.frames }
    else if got >= 8 && got = 8 * (length + 2)
    then (
      let bytes = bytes bits in
      let ok = List.sum (module Int) bytes ~f:Fn.id % 256 = 0 in
      { t with
        bits = []
      ; in_frame = false
      ; pull_in = Option.some_if ok 5
      ; frames = (bytes, ok) :: t.frames
      })
    else { t with bits }
  ;;

  let rose t ~dat =
    if t.holding
    then { t with release_in = Some 5 }
    else if t.low >= Bench.cycles_in ~us:1
    then { t with bits = []; in_frame = true }
    else if t.in_frame
    then take t ~dat
    else t
  ;;

  let count = function
    | Some 1 -> None, true
    | Some n -> Some (n - 1), false
    | None -> None, false
  ;;

  (* STB and DAT as the line shows them, after a cycle *)
  let step t ~stb ~dat =
    let t = if stb && not t.stb then rose t ~dat else t in
    let pull_in, pull = count t.pull_in in
    let release_in, release = count t.release_in in
    { t with
      stb
    ; low = (if stb then 0 else t.low + 1)
    ; pull_in
    ; release_in
    ; holding = (t.holding || pull) && not release
    }
  ;;

  let frames t = List.rev t.frames
end

let peer () =
  let p = ref (Peripheral.create ())
  and line = ref true in
  { Peer.inputs = (fun () -> Bool.to_int !line lsl dat)
  ; step =
      (fun ~pin_out ~pin_dir ->
        let stb = Peer.bit pin_out stb = 1 in
        let dat = Peer.bit pin_dir dat = 0 && not (Peripheral.pulls_low !p) in
        p := Peripheral.step !p ~stb ~dat;
        line := dat && not (Peripheral.pulls_low !p))
  }
;;

let bench =
  { Bench.name = "plinkoo"
  ; what =
      "Plinkoo.firmware: STB on OUT5, DAT on IO3, sync 5.167 us, 16 cycles a bit (3 \
       MHz), a frame of three bytes then one of eight, each with its checksum and ack \
       bit"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus =
      Some
        { bursts = List.map frames ~f:words
        ; quiet = 0
        ; cycles = (List.length frames + 1) * cycles_a_frame
        }
  }
;;

(* STB's lows past 1 us are syncs. A bit period runs rise to rise inside a frame, from the
   first bit's rise to the ack bit's: the sync's rise starts tSYH, not a bit. *)
let limits =
  let sheet page =
    { Datasheet.Sheet.part = "Plinkoo"
    ; document = "PLK-2 data sheet, revision 1.3"
    ; page
    }
  in
  let is_sync ~clock_hz n = n >= Datasheet.cycles ~clock_hz 1_000. in
  let syncs =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter (Datasheet.lows levels) ~f:(is_sync ~clock_hz))
  in
  let after_sync =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, l), (_, h)) ->
        Option.some_if ((not high) && is_sync ~clock_hz l) h))
  in
  let before_sync =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, h), (_, l)) ->
        Option.some_if (high && is_sync ~clock_hz l) h)
      |> Fn.flip List.drop 1)
  in
  (* a high and the low after it, inside a frame, past the high after the sync *)
  let periods =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter_map
        (List.zip_exn
           (List.drop_last_exn (Datasheet.pairs levels))
           (List.drop (Datasheet.pairs levels) 1))
        ~f:(fun (((before, b), (high, h)), (_, (_, l))) ->
          Option.some_if
            ((not before)
             && high
             && (not (is_sync ~clock_hz b))
             && not (is_sync ~clock_hz l))
            (h + l)))
  in
  let bit_ns = Float.of_int sync *. 1e9 /. Float.of_int Bench.clock_hz /. 16. in
  let limit parameter limit page bound =
    { Datasheet.firmware = "plinkoo"
    ; parameter
    ; limit
    ; sheet = sheet page
    ; margin = Cycle
    ; bound
    }
  in
  let table = "section 4, pp.1-2" in
  [ limit "tSYN" (At_least 4_800.) table syncs
  ; limit "tSYN" (At_most 5_200.) table syncs
  ; limit "tSYH" (At_least 325.) "section 4, p.1: a tB at tSYN's 5.2 us max" after_sync
  ; limit
      "tB"
      (At_least (0.94 *. bit_ns))
      "note 1, p.2: tSYN/16 less 6 %, at this firmware's 248-cycle sync"
      periods
  ; limit
      "tB"
      (At_most (1.06 *. bit_ns))
      "note 1, p.2: tSYN/16 and 6 %, at this firmware's 248-cycle sync"
      periods
  ; limit "fSTB" (At_least (1e9 /. 3.5e6)) "section 4, p.2: 3.5 MHz max" periods
  ; limit
      "tSL"
      (At_least 140.)
      table
      (Datasheet.level ~pin:Datasheet.set_pin ~high:false ())
  ; limit
      "tSH"
      (At_least 140.)
      table
      (Datasheet.level ~pin:Datasheet.set_pin ~high:true ())
  ; limit "tFRM" (At_least 1_500.) "section 4, p.2, and note 4" before_sync
  ]
;;

(* DAT's limits against STB, which no bound above sees, as two pins: of each rise of STB
   in a run of every pin by cycle, the cycles since DAT last moved and until it next does. *)
let around_rises (pins : int array) =
  let bit p i = (pins.(i) lsr p) land 1 in
  let cycles = List.range 1 (Array.length pins) in
  let moves = List.filter cycles ~f:(fun i -> bit dat i <> bit dat (i - 1)) in
  List.filter cycles ~f:(fun i -> bit stb i = 1 && bit stb (i - 1) = 0)
  |> List.filter_map ~f:(fun r ->
    let%map.Option before = List.filter moves ~f:(fun m -> m <= r) |> List.last in
    r, r - before, List.find moves ~f:(fun m -> m > r) |> Option.map ~f:(fun a -> a - r))
;;

let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "plinkoo" ~pins:[ "stb", stb; "dat", dat ] ]
  ; expect =
      [ ( "plinkoo=length:byte:checksum-ok:ack"
        , List.concat_map frames ~f:(fun payload ->
            [ sprintf "Length %d" (List.length payload) ]
            @ List.map payload ~f:(sprintf "%02X")
            @ [ "Checksum OK"; "ACK" ])
          |> Sigrok.lines "plinkoo" )
      ]
  ; joins_after = None
  ; rejected = None
  ; (* DAT's edge 0 is L's first 0, in the first frame; held high over that rise *)
    teeth = [ [ Flip { pin = dat; edge = 0; after = 0; cycles = 10 } ] ]
  }
;;

let scenario =
  { Scenario.name = "plinkoo"
  ; peer
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ [ Write (Reg.tx, words (List.hd_exn frames))
        ; Scenario.start
        ; Run cycles_a_frame
        ; Write (Reg.tx, words (List.last_exn frames))
        ; Run (2 * cycles_a_frame)
        ; Read (Reg.rx, 2)
        ]
  ; sigrok = Some sigrok
  }
;;

(* refused, so neither on the bench nor among the library's limits: [bench] and [limits]
   stay for the refusal its tests name *)
let protocol =
  { Protocol.name = "plinkoo"
  ; certified
  ; time_triggered = []
  ; bench = []
  ; loaded_from_hex = []
  ; limits = []
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "plinkoo"
        , "refused at the margin: note 1's tB and the turnaround's tDH and tREL, see \
           test_plinkoo" )
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
