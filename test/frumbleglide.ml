open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* FGL-0 Frumbleglide Clockless Telemetry Link, revision 0.9: section 4's timing (p.1) and
   notes 1-4 (p.2). tCELL's 2.005 to 2.015 us is 96.24 to 96.72 cycles at 48 MHz, and no
   whole number lies between: a cell is 96 (2.000 us) or 97 (2.021 us), and note 1 holds
   each cell to the limits, not their average. This firmware is the nearest: two waits of
   24 and 7864/65536 a half cell, so cells of 96 and 97 averaging 2.010 us, which the
   limits refuse. *)

let pin = 5

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  ; out_shift = Left
  ; period_fraction = 7864
  }
;;

(* Each host word MSB first after six cells of 1, a 1 high then low, a 0 low then high;
   two [wait t+] step half a cell, as the analyser bounds only a [p] that [set] makes, and
   [y] holds the bit. *)
let firmware =
  [%firmware
    {|
    set pins, 0              ; idle low
    set p, 24
frame:
    wait tx
    pull
    mov t, now
    set x, 20
gap:
    add t, p
    add t, p
    add t, p
    add t, p
    wait t                   ; 21 waits of 96: 42 us idle first
    jmp x--, gap
    add t, p
    set x, 5                 ; six cells of preamble
pre:
    wait t+
    wait t+
    set pins, 1
    wait t+
    wait t+
    set pins, 0
    jmp x--, pre
    set x, 15
data:
    out y, 1
    wait t+
    wait t+
    mov pins, y
    wait t+
    wait t+
    mov pins, !y
    jmp x--, data
    wait t+
    wait t+
    set pins, 0              ; idle, after a 0's high half
    jmp frame
|}
      ~config]
;;

let words = [ 0x8001; 0x5a3c ]
let cycles_a_frame = (2 * 22 * 49) + 2_100

let bench =
  { Bench.name = "frumbleglide"
  ; what =
      "Frumbleglide.firmware: LNK on OUT0, cells of 96 and 97 cycles averaging 2.010 us, \
       six of preamble and sixteen of data"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus =
      Some
        { bursts = List.map words ~f:List.return
        ; quiet = 0
        ; cycles = (List.length words + 1) * cycles_a_frame
        }
  }
;;

(* Transitions in a frame, from its first rise: after a mid-cell one the next is a cell's
   boundary within 1.5 us, half a cell, else the next cell's middle. A low past 3 us is
   idle. *)
let mids ~clock_hz (levels : (bool * int) list) =
  let idle n = n >= Datasheet.cycles ~clock_hz 3_000. in
  let boundary n = n < Datasheet.cycles ~clock_hz 1_500. in
  let _, frames =
    List.fold levels ~init:(0, []) ~f:(fun (at, frames) (high, n) ->
      let frames =
        match frames with
        | _ when (not high) && idle n -> [ at + n ] :: frames
        | frame :: rest -> ((at + n) :: frame) :: rest
        | [] -> []
      in
      at + n, frames)
  in
  List.rev_map frames ~f:(fun frame ->
    match List.rev frame with
    | [] -> []
    | start :: edges ->
      let _, _, mids =
        List.fold edges ~init:(start, true, []) ~f:(fun (last, after_boundary, mids) at ->
          if after_boundary || not (boundary (at - last))
          then at, false, at :: mids
          else at, true, mids)
      in
      List.rev mids)
;;

let limits =
  let sheet page =
    { Datasheet.Sheet.part = "Frumbleglide"
    ; document = "FGL-0 data sheet, revision 0.9"
    ; page
    }
  in
  let cells =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.concat_map (mids ~clock_hz levels) ~f:(fun mids ->
        List.zip_exn (List.drop_last mids |> Option.value ~default:[]) (List.drop mids 1)
        |> List.map ~f:(fun (a, b) -> b - a)))
  in
  let halves =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter_map levels ~f:(fun (_, n) ->
        Option.some_if (n < Datasheet.cycles ~clock_hz 1_500.) n))
  in
  let gaps =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter (Datasheet.lows levels) ~f:(fun n ->
        n >= Datasheet.cycles ~clock_hz 3_000.))
  in
  let limit parameter limit page bound =
    { Datasheet.firmware = "frumbleglide"
    ; parameter
    ; limit
    ; sheet = sheet page
    ; margin = Cycle
    ; bound
    }
  in
  let table = "section 4, p.1" in
  [ limit "tCELL" (At_least 2_005.) "section 4, p.1, and note 1, p.2: each cell" cells
  ; limit "tCELL" (At_most 2_015.) "section 4, p.1, and note 1, p.2: each cell" cells
  ; limit "tMID" (At_least (0.45 *. 2_005.)) (table ^ ": 45 % of tCELL's min") halves
  ; limit "tMID" (At_most (0.55 *. 2_015.)) (table ^ ": 55 % of tCELL's max") halves
  ; limit "tGAP" (At_least 40_000.) (table ^ ", and note 3, p.2") gaps
  ]
;;

let scenario =
  { Scenario.name = "frumbleglide"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Write (Reg.tx, words)
        ; Scenario.start
        ; Run ((List.length words + 1) * cycles_a_frame)
        ]
  ; sigrok = None
  }
;;

(* refused, so neither on the bench nor among the library's limits: [bench] and [limits]
   stay for the refusal its tests name *)
let protocol =
  { Protocol.name = "frumbleglide"
  ; certified = []
  ; time_triggered = []
  ; bench = []
  ; loaded_from_hex = []
  ; limits = []
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "frumbleglide"
        , "refused: no whole number of cycles is a tCELL at 48 MHz, see test_frumbleglide"
        )
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
