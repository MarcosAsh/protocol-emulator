open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* ARM Debug Interface Architecture Specification ADIv5.0 to ADIv5.2, ARM IHI 0031C
   (ID080813), chapter 4 (SW-DP) and 5.2-5.3 (select sequences). It gives no times, only
   counts of clock cycles: its figures "are not timing diagrams" (p.4-94). *)

(* SWCLK on OUT2 and SWDIO on IO5, the bench's SWD pins to its RP2040 *)
let swclk_pin = 7
let swdio_pin = 17

(* 1 MHz at 48 MHz *)
let standard_half = 24
let period_floor = 12

let config =
  { Program_config.default with
    side_set_count = 1
  ; side_set_base = swclk_pin
  ; in_base = swdio_pin
  ; out_base = swdio_pin
  ; out_count = 1
  ; set_base = swdio_pin
  ; set_count = 1
  }
;;

(* A word is eight clocks, two bits each from bit 0: the level, then 1 to drive it or 0 to
   let go. The level and direction move after a fall, the target takes the bit on the rise
   and we take the target's on the next fall. A release is at once, a drive two cycles
   later, so the line is let go for a period and two cycles at least. *)
let firmware =
  [%firmware
    {|
    .side_set 1
    wait tx side 0
    pull side 0
    mov p, osr side 0        ; half a SWCLK period
idle:
    wait tx side 0
    pull side 0
    set x, 7 side 0
    mov t, now side 0
    add t, p side 0
bit:
    out pins, 1 side 0
    out y, 1 side 0
    jmp y--, drive
    set pindirs, 0 side 0    ; let go
    jmp rise
drive:
    nop side 0 [1]
    set pindirs, 1 side 0
rise:
    wait t+ side 0
    nop side 1               ; rise: the target takes the bit
    wait t+ side 1
    in pins, 1 side 0        ; fall: the target's bit, moved at the rise
    jmp x--, bit
    push side 0
    jmp idle
|}
      ~config
      ~period_floor:12]
;;

module Clock = struct
  type t =
    | Drive of bool
    | Release
  [@@deriving sexp_of]
end

let drive bits = List.map bits ~f:(fun bit -> Clock.Drive (bit = 1))
let high n = List.init n ~f:(fun _ -> Clock.Drive true)
let idle n = List.init n ~f:(fun _ -> Clock.Drive false)
let lsb_first ~bits value = List.init bits ~f:(fun i -> (value lsr i) land 1)
let msb_first ~bits value = List.rev (lsb_first ~bits value)
let parity bits = List.sum (module Int) bits ~f:Fn.id % 2

(* at least 50 clocks high, p.4-104 *)
let line_reset = high 56

let request ~ap ~read ~addr =
  let fields =
    [ Bool.to_int ap; Bool.to_int read; (addr lsr 2) land 1; (addr lsr 3) land 1 ]
  in
  drive ((1 :: fields) @ [ parity fields; 0; 1 ])
;;

(* Figure 4-2: a turnaround, ACK, RDATA and parity, a turnaround, then ours again *)
let read_clocks = 45
let ack_offset = 8
let data_offset = 11
let parity_offset = 43

let read ~ap ~addr =
  request ~ap ~read:true ~addr @ List.init (read_clocks - 8) ~f:(fun _ -> Clock.Release)
;;

(* Figure 4-9: five cycles not driven, a turnaround, ACK and a turnaround, then WDATA and
   parity; ACK is not read *)
let write ~ap ~addr data =
  let data = lsb_first ~bits:32 data in
  request ~ap ~read:false ~addr
  @ List.init 5 ~f:(fun _ -> Clock.Release)
  @ drive (data @ [ parity data ])
;;

let words clocks =
  let pad = (8 - (List.length clocks % 8)) % 8 in
  clocks @ idle pad
  |> List.chunks_of ~length:8
  |> List.map ~f:(fun clocks ->
    List.foldi clocks ~init:0 ~f:(fun i word (clock : Clock.t) ->
      let level, dir =
        match clock with
        | Drive level -> Bool.to_int level, 1
        | Release -> 1, 0
      in
      word lor (level lsl (2 * i)) lor (dir lsl ((2 * i) + 1))))
;;

let sampled ~pushed =
  let pushed = Array.of_list pushed in
  fun i -> (pushed.(i / 8) lsr (8 + (i % 8))) land 1
;;

module Answer = struct
  type t =
    { ack : int
    ; data : Int.Hex.t
    ; parity_ok : bool
    }
  [@@deriving sexp_of]
end

let answer ~pushed ~first =
  let bit = sampled ~pushed in
  let field ~offset ~bits =
    List.init bits ~f:(fun i -> bit (first + offset + i) lsl i)
    |> List.fold ~init:0 ~f:( lor )
  in
  let data = field ~offset:data_offset ~bits:32 in
  { Answer.ack = field ~offset:ack_offset ~bits:3
  ; data
  ; parity_ok = parity (lsb_first ~bits:32 data) = bit (first + parity_offset)
  }
;;

module Target = struct
  module Phase = struct
    type t =
      | Lost
      | Reset_idle of int
      | Idle
      | Header of int list (* newest first *)
      | Turnaround of
          { bits : int list
          ; write : (bool * int) option
          }
      | Driving of
          { bits : int list
          ; write : (bool * int) option
          }
      | Write_turnaround of bool * int
      | Write_data of
          { ap : bool
          ; addr : int
          ; bits : int list (* newest first *)
          }
      | Error
  end

  let dpidr = 0x0bc12477

  type t =
    { phase : Phase.t
    ; reset_state : bool
    ; high_run : int
    ; swclk : int
    ; drive : int option
    ; host_drive : bool
    ; host_level : int
    ; contending : bool
    ; ap : int array
    ; posted : int
    ; log : string list
    ; violations : string list
    }

  let create () =
    { phase = Lost
    ; reset_state = false
    ; high_run = 0
    ; swclk = 0
    ; drive = None
    ; host_drive = false
    ; host_level = 1
    ; contending = false
    ; ap = Array.create ~len:4 0
    ; posted = 0
    ; log = []
    ; violations = []
    }
  ;;

  let line t =
    match t.drive with
    | Some bit -> bit
    | None -> if t.host_drive then t.host_level else 1
  ;;

  let note t line = { t with log = line :: t.log }
  let violation t line = { t with violations = line :: t.violations }
  let log t = List.rev t.log
  let violations t = List.rev t.violations
  let name ~ap ~addr = sprintf "%s 0x%x" (if ap then "AP" else "DP") addr

  (* Table 4-1: DPIDR, a CTRL/STAT of 0, RESEND and RDBUFF give the last AP read; an AP
     read gives the one before it, 0 the first time *)
  let respond t ~ap ~read ~addr =
    let t =
      if t.reset_state && not ((not ap) && read && addr = 0)
      then
        violation
          { t with phase = Error }
          (sprintf "%s in the reset state" (name ~ap ~addr))
      else { t with reset_state = false }
    in
    match t.phase with
    | Error -> t
    | _ ->
      let ok = [ 1; 0; 0 ] in
      if read
      then (
        let data, posted =
          match ap, addr with
          | false, 0 -> dpidr, t.posted
          | false, 4 -> 0, t.posted
          | false, _ -> t.posted, t.posted
          | true, _ -> t.posted, t.ap.(addr / 4)
        in
        let bits = lsb_first ~bits:32 data in
        note
          { t with
            posted
          ; phase = Turnaround { bits = ok @ bits @ [ parity bits ]; write = None }
          }
          (sprintf "read %s: 0x%08x" (name ~ap ~addr) data))
      else { t with phase = Turnaround { bits = ok; write = Some (ap, addr) } }
  ;;

  let header t bits =
    match bits with
    | [ _start; ap; read; a2; a3; p; stop; park ]
      when p = parity [ ap; read; a2; a3 ] && stop = 0 && park = 1 ->
      respond t ~ap:(ap = 1) ~read:(read = 1) ~addr:((a2 lsl 2) lor (a3 lsl 3))
    | _ -> violation { t with phase = Error } "protocol error"
  ;;

  let wrote t ~ap ~addr bits =
    let data =
      List.take bits 32 |> List.foldi ~init:0 ~f:(fun i acc b -> acc lor (b lsl i))
    in
    if parity (List.take bits 32) <> List.nth_exn bits 32
    then violation t (sprintf "WDATA parity, %s" (name ~ap ~addr))
    else (
      if ap then t.ap.(addr / 4) <- data;
      note t (sprintf "write %s: 0x%08x" (name ~ap ~addr) data))
  ;;

  (* the host's bit, or with no one driving the pull-up's *)
  let sample t bit =
    let reset = bit = 0 && t.high_run >= 50 in
    let t = { t with high_run = (if bit = 1 then t.high_run + 1 else 0) } in
    if reset
    then note { t with phase = Reset_idle 1; reset_state = true } "line reset"
    else (
      match t.phase with
      | Lost | Error | Turnaround _ | Driving _ | Write_turnaround _ -> t
      | Reset_idle n when bit = 0 -> { t with phase = Reset_idle (n + 1) }
      | Reset_idle n when n < 2 ->
        violation
          { t with phase = Header [ 1 ] }
          (sprintf "%d idle cycles after a line reset" n)
      | Reset_idle _ | Idle -> if bit = 1 then { t with phase = Header [ 1 ] } else t
      | Header bits ->
        let bits = bit :: bits in
        if List.length bits = 8
        then header t (List.rev bits)
        else { t with phase = Header bits }
      | Write_data { ap; addr; bits } ->
        let bits = bit :: bits in
        if List.length bits = 33
        then wrote { t with phase = Idle } ~ap ~addr (List.rev bits)
        else { t with phase = Write_data { ap; addr; bits } })
  ;;

  (* the target moves the line just after a rise *)
  let rise t =
    match t.phase with
    | Turnaround { bits = bit :: bits; write } | Driving { bits = bit :: bits; write } ->
      { t with drive = Some bit; phase = Driving { bits; write }; high_run = 0 }
    | Turnaround { bits = []; _ } -> t
    | Driving { bits = []; write = None } -> { t with drive = None; phase = Idle }
    | Driving { bits = []; write = Some (ap, addr) } ->
      { t with drive = None; phase = Write_turnaround (ap, addr) }
    | Write_turnaround (ap, addr) -> { t with phase = Write_data { ap; addr; bits = [] } }
    | Lost | Reset_idle _ | Idle | Header _ | Write_data _ | Error ->
      sample t (if t.host_drive then t.host_level else 1)
  ;;

  let step t ~swclk ~host_drive ~host_level =
    let t = { t with host_drive; host_level } in
    let contending = host_drive && Option.is_some t.drive in
    let t =
      if contending && not t.contending
      then violation t "host and target both drive SWDIO"
      else t
    in
    let t = { t with contending } in
    let t = if swclk = 1 && t.swclk = 0 then rise t else t in
    { t with swclk }
  ;;
end

let peer () =
  let target = ref (Target.create ()) in
  { Peer.inputs = (fun () -> Target.line !target lsl swdio_pin)
  ; step =
      (fun ~pin_out ~pin_dir ->
        target
        := Target.step
             !target
             ~swclk:(Peer.bit pin_out swclk_pin)
             ~host_drive:(Peer.bit pin_dir swdio_pin = 1)
             ~host_level:(Peer.bit pin_out swdio_pin))
  }
;;

(* the line reset and its idle cycles, eight words, then a DPIDR read and an AP read of
   CSW, six words each, the last with eight idle cycles to end on, p.4-89 *)
let dpidr_first = 64
let ap_first = dpidr_first + 48

let clocks =
  line_reset @ idle 8 @ read ~ap:false ~addr:0 @ idle 3 @ read ~ap:true ~addr:0 @ idle 11
;;

let send words =
  [ Step.Write (Reg.tx, words)
  ; Run ((List.length words * 16 * (standard_half + 1)) + 200)
  ; Read (Reg.rx, List.length words)
  ]
;;

(* sigrok's swd takes our bits on rises and the target's on falls, skipping a fall for the
   first turnaround and a rise for the last. SWDIO's edge 8 is ACK's second bit falling, 9
   RDATA's bit 0 rising: the teeth bring ACK half a clock early, so OK reads 000, and
   invert RDATA's bit 0. *)
let sigrok =
  { Sigrok.clock_hz = Bench.clock_hz
  ; decoders = [ Sigrok.decoder "swd" ~pins:[ "swclk", swclk_pin; "swdio", swdio_pin ] ]
  ; expect =
      [ ( "swd=reset:read:ack:data"
        , Sigrok.lines
            "swd"
            [ "LINERESET"
            ; "IDCODE"
            ; "OK"
            ; sprintf "0x%08x" Target.dpidr
            ; "R AP0"
            ; "OK"
            ; "0x00000000"
            ] )
      ]
  ; joins_after = None
  ; rejected = None
  ; teeth =
      [ [ Shift { pin = swdio_pin; edge = 8; cycles = -(standard_half + 6) } ]
      ; [ Flip { pin = swdio_pin; edge = 9; after = 0; cycles = 2 * standard_half } ]
      ]
  }
;;

let scenario =
  { Scenario.name = "swd_blind"
  ; peer
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Scenario.start; Write (Reg.tx, [ standard_half ]) ]
      @ List.concat_map (List.chunks_of (words clocks) ~length:4) ~f:send
  ; sigrok = Some sigrok
  }
;;

(* The bench's run, every select sequence of chapter 5 and the RP2040's connection: from
   JTAG to SWD (p.5-111), a DPIDR read, SWD to dormant (p.5-116), dormant to SWD with the
   SW-DP's activation code (p.5-117, Table 5-1), TARGETSEL for core 0 (Figure 4-9), the
   DPIDR and an AP read, then SWD to JTAG (p.5-111) and JTAG to dormant (p.5-115). The
   rows' highs and lows are labelled. *)
let bench_segments =
  let alert =
    List.concat_map
      [ 0x49CF9046; 0xA9B4A161; 0x97F5BBC7; 0x45703D98 ]
      ~f:(msb_first ~bits:32)
  in
  [ None, idle 8
  ; Some "JTAG-to-SWD", high 56
  ; None, drive (lsb_first ~bits:16 0xe79e)
  ; Some "line reset", line_reset
  ; Some "idle cycles", idle 8
  ; None, read ~ap:false ~addr:0 @ idle 3
  ; Some "SWD-to-DS", high 56
  ; None, drive (lsb_first ~bits:16 0xe3bc)
  ; None, high 8 @ drive alert @ idle 4 @ drive (msb_first ~bits:8 0x58)
  ; Some "DS-to-SWD", line_reset
  ; None, idle 8
  ; None, write ~ap:false ~addr:0xc 0x01002927 @ idle 8
  ; None, read ~ap:false ~addr:0 @ idle 3
  ; None, read ~ap:true ~addr:0 @ idle 3
  ; None, high 56 @ drive (lsb_first ~bits:16 0xe73c)
  ; Some "JTAG-to-DS", high 8
  ; None, drive (msb_first ~bits:31 0x2EEEEEE6) @ idle 8
  ]
;;

let bench_clocks = List.concat_map bench_segments ~f:snd

(* The line's runs as the clocks make them, the pull-up's before the first word and on a
   released clock, and the run each label's last clock is in *)
let bench_runs =
  let level : Clock.t -> bool = function
    | Drive level -> level
    | Release -> true
  in
  let levels = true :: List.map bench_clocks ~f:level in
  let runs = Datasheet.runs (Array.of_list levels) in
  let run_of =
    List.concat_mapi runs ~f:(fun i (_, n) -> List.init n ~f:(fun _ -> i))
    |> Array.of_list
  in
  let labels, _ =
    List.fold bench_segments ~init:([], 1) ~f:(fun (labels, at) (label, clocks) ->
      let at = at + List.length clocks in
      match label with
      | Some label -> (label, run_of.(at - 1)) :: labels, at
      | None -> labels, at)
  in
  List.length runs, labels
;;

let bench =
  { Bench.name = "swd_blind"
  ; what =
      [%string
        "Swd_blind.firmware: SWCLK at 1 MHz on OUT2 and SWDIO on IO5, the RP2040's; the \
         select sequences, TARGETSEL, the DPIDR and an AP read, %{List.length \
         bench_clocks#Int} clocks"]
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Floor period_floor
  ; clock_hz = Bench.clock_hz
  ; load = Some standard_half
  ; stimulus =
      Some
        { bursts = [ words bench_clocks ]
        ; quiet = 0
        ; cycles = List.length bench_clocks * 2 * (standard_half + 6)
        }
  }
;;

(* The spec counts SWCLK cycles; at the bench's 1 MHz a cycle is 1 us. Trn: the host lets
   go for a data period at least, the kernel's bound on SWDIO undriven. The rest are the
   bench run's labelled runs of SWDIO. *)
let limits =
  let us = 1_000. in
  let sheet page =
    { Datasheet.Sheet.part = "SW-DP"
    ; document = "ARM IHI 0031C ADIv5.0 to ADIv5.2, ID080813"
    ; page
    }
  in
  let run label =
    let count, labels = bench_runs in
    let index = List.Assoc.find_exn labels label ~equal:String.equal in
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz:_ levels ->
      (* the run's last level has not ended *)
      if List.length levels <> count - 1
      then
        raise_s
          [%message
            "BUG: the bench's SWDIO runs" (List.length levels : int) (count : int)];
      [ snd (List.nth_exn levels index) ])
  in
  let limit parameter page cycles bound =
    { Datasheet.firmware = "swd_blind"
    ; parameter
    ; limit = At_least (Float.of_int cycles *. us)
    ; sheet = sheet page
    ; margin = Cycle
    ; bound
    }
  in
  [ limit
      "Trn"
      "Table 2-10, p.2-52"
      1
      (Datasheet.level ~dirs:true ~pin:Datasheet.set_pin ~high:false ())
  ; limit "line reset" "4.4.3, p.4-104" 50 (run "line reset")
  ; limit "idle cycles" "4.4.3, p.4-104" 2 (run "idle cycles")
  ; limit "JTAG-to-SWD" "5.2.1, p.5-111" 50 (run "JTAG-to-SWD")
  ; limit "JTAG-to-DS" "5.3.2, p.5-115" 5 (run "JTAG-to-DS")
  ; limit "SWD-to-DS" "5.3.3, p.5-116" 50 (run "SWD-to-DS")
  ; limit "DS-to-SWD" "5.3.4, p.5-117" 50 (run "DS-to-SWD")
  ]
;;

let certified = [ Certified.of_firmware ~period:standard_half "swd_blind" firmware ]

let protocol =
  { Protocol.name = "swd_blind"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "swd_blind"
        , "SWDIO turns around, which a wire does not show, and a target answers" )
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
