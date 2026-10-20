open! Core
open Protocol_emulator

let pin = 12
let standard_unit = 2_500
let shortest_unit = 7

(* [t] is the next unit on the line throughout; each loop waits it out a unit a pass, [x]
   counting all but the last. The bit loop ends when the nine bits of a block are out. *)
let firmware =
  {|
    wait tx
    pull
    mov p, osr               ; 50 us
    mov t, now
    set pins, 0              ; the line is only ever pulled low
    set pindirs, 0
frame:
    wait tx
    pull
    mov y, osr               ; blocks less one
    mov t, now
    add t, p
    wait t+
    set pindirs, 1           ; start bit, 3.7 ms low
    set x, 31
s0:
    wait t+
    jmp x--, s0
    set x, 31
s1:
    wait t+
    jmp x--, s1
    set x, 8
s2:
    wait t+
    jmp x--, s2
    wait t+
    set pindirs, 0           ; 4.5 ms in all
    set x, 14
s3:
    wait t+
    jmp x--, s3
block:
    pull
    mov osr, !osr            ; a released line is a one
bit:
    wait t+
    set pindirs, 1
    set x, 10
b0:
    wait t+
    jmp x--, b0
    wait t+
    out pindirs, 1           ; a one rises at 0.6 ms
    set x, 16
b1:
    wait t+
    jmp x--, b1
    wait t+
    set pindirs, 0           ; a zero at 1.5 ms
    set x, 16
b2:
    wait t+
    jmp x--, b2              ; 2.4 ms a bit
    jmp !osre, bit
    wait t+                  ; ACK: the initiator sends a one
    set pindirs, 1
    set x, 10
a0:
    wait t+
    jmp x--, a0
    wait t+
    set pindirs, 0
    set x, 7
a1:
    wait t+
    jmp x--, a1
    wait t+
    in pins, 1               ; at 1.05 ms: low is an ACK
    push
    set x, 25
a2:
    wait t+
    jmp x--, a2
    jmp y--, block
    set y, 6                 ; signal free time, seven bit periods
free:
    set x, 31
f0:
    wait t+
    jmp x--, f0
    set x, 15
f1:
    wait t+
    jmp x--, f1
    jmp y--, free
    jmp frame
|}
;;

let config =
  { Program_config.default with
    in_base = pin
  ; in_count = 1
  ; out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  ; out_shift = Left
  ; in_shift = Left
  ; pull_threshold = 9
  }
;;

module Frame = struct
  type t =
    { initiator : int
    ; destination : int
    ; data : int list
    }
  [@@deriving sexp_of, compare, equal]
end

let words ({ initiator; destination; data } : Frame.t) =
  let bytes = ((initiator lsl 4) lor destination) :: data in
  let last = List.length bytes - 1 in
  last
  :: List.mapi bytes ~f:(fun i byte -> (byte lsl 8) lor (Bool.to_int (i = last) lsl 7))
;;

module Follower = struct
  module Bit = struct
    type t =
      | Start
      | Data
    [@@deriving sexp_of]
  end

  (* the last frame, to its EOM or as far as it came before its initiator gave it up *)
  module Previous = struct
    type t =
      { initiator : int option
      ; blocks : int list
      ; whole : bool
      ; went_through : bool
      }
  end

  type t =
    { clock_hz : int
    ; address : int
    ; now : int
    ; low : bool
    ; fall : (int * Bit.t) option (* the last fall, and what it began *)
    ; bits : bool list (* this block's, last first *)
    ; bytes : int list
    ; acks : bool list
    ; in_frame : bool
    ; free : (int * int) option
        (* before this frame, checked at its EOM: cycles from the last fall, and the ns of
           its nominal period in them *)
    ; previous : Previous.t option
    ; driving_until : int option
    ; frames : (Frame.t * bool list) list
    ; measured : Measured.t
    ; violations : string list
    }

  let create ~clock_hz ~address =
    { clock_hz
    ; address
    ; now = 0
    ; low = false
    ; fall = None
    ; bits = []
    ; bytes = []
    ; acks = []
    ; in_frame = false
    ; free = None
    ; previous = None
    ; driving_until = None
    ; frames = []
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let drive_low t = Option.exists t.driving_until ~f:(fun until -> t.now < until)
  let ms = 1_000_000

  let checked ?hi t ~name ~cycles ~lo =
    let { clock_hz; _ } = t in
    let ns = Measured.ns ~clock_hz cycles in
    let t = { t with measured = Measured.add t.measured ~name ~ns } in
    if Measured.at_least ~clock_hz cycles ~ns:lo
       && Option.for_all hi ~f:(fun ns -> Measured.at_most ~clock_hz cycles ~ns)
    then t
    else { t with violations = [%string "%{name} of %{ns#Int} ns"] :: t.violations }
  ;;

  (* the line free for at least [least] ns past [period], the nominal end of a bit *)
  let checked_free t ~cycles ~period ~least =
    let { clock_hz; _ } = t in
    let ns = Measured.ns ~clock_hz cycles - period in
    let t = { t with measured = Measured.add t.measured ~name:"free" ~ns } in
    if Measured.at_least ~clock_hz cycles ~ns:(period + least)
    then t
    else { t with violations = [%string "free of %{ns#Int} ns"] :: t.violations }
  ;;

  let byte bits = List.fold bits ~init:0 ~f:(fun b bit -> (b lsl 1) lor Bool.to_int bit)

  (* the destination, once the header's eight bits are in *)
  let addressed t =
    let header =
      match List.last t.bytes with
      | Some header -> Some header
      | None when List.length t.bits >= 8 -> Some (byte (List.take (List.rev t.bits) 8))
      | None -> None
    in
    Option.exists header ~f:(fun header -> header land 0xf = t.address)
  ;;

  let fell t =
    let t =
      match t.fall with
      | Some (fall, Start) when t.in_frame ->
        checked
          t
          ~name:"start"
          ~cycles:(t.now - fall)
          ~lo:(43 * ms / 10)
          ~hi:(47 * ms / 10)
      | Some (fall, Data) when t.in_frame ->
        checked
          t
          ~name:"bit"
          ~cycles:(t.now - fall)
          ~lo:(205 * ms / 100)
          ~hi:(275 * ms / 100)
      | Some (fall, bit) ->
        (* free from the end of the last bit's nominal period, or a start bit's given up;
           3 bit periods at least, whatever the frame; which of 3, 5 or 7 at its EOM *)
        let period =
          match bit with
          | Data -> 24 * ms / 10
          | Start -> 45 * ms / 10
        in
        let cycles = t.now - fall in
        let least = 3 * 24 * ms / 10 in
        if Option.is_some t.previous
           && not (Measured.at_least ~clock_hz:t.clock_hz cycles ~ns:(period + least))
        then { (checked_free t ~cycles ~period ~least) with free = None }
        else { t with free = Some (cycles, period) }
      | None -> t
    in
    let ack_slot = t.in_frame && List.length t.bits = 9 in
    let driving_until =
      if ack_slot && addressed t
      then Some (t.now + Measured.cycles ~clock_hz:t.clock_hz ~ns:(15 * ms / 10))
      else None
    in
    { t with fall = Some (t.now, if t.in_frame then Data else Start); driving_until }
  ;;

  (* CEC 9.1's signal free time, in nominal bit periods of 2.4 ms; a retry is the same
     frame again, as Linux's cec-adap.c takes it *)
  let check_free t (frame : Frame.t) =
    match t.free, t.previous with
    | Some (cycles, period), Some previous ->
      let blocks = ((frame.initiator lsl 4) lor frame.destination) :: frame.data in
      let retry =
        (not previous.went_through)
        &&
        if previous.whole
        then [%equal: int list] previous.blocks blocks
        else List.is_prefix blocks ~prefix:previous.blocks ~equal:Int.equal
      in
      let periods =
        match previous.initiator with
        | Some initiator when initiator = frame.initiator -> if retry then 3 else 7
        | Some _ | None -> 5
      in
      checked_free t ~cycles ~period ~least:(periods * 24 * ms / 10)
    | _ -> t
  ;;

  (* a directed block goes through when acknowledged, a broadcast one unless refused *)
  let went_through ~destination acks =
    if destination = 0xf
    then not (List.exists acks ~f:Fn.id)
    else List.for_all acks ~f:Fn.id
  ;;

  let rose t ~fall =
    let cycles = t.now - fall in
    (* what a sample at 1.05 ms sees *)
    let one = Measured.at_most ~clock_hz:t.clock_hz cycles ~ns:(105 * ms / 100) in
    if not t.in_frame
    then (
      let t = checked t ~name:"start low" ~cycles ~lo:(35 * ms / 10) ~hi:(39 * ms / 10) in
      { t with in_frame = true; bits = []; bytes = []; acks = [] })
    else if List.length t.bits = 9
    then (
      (* the ACK slot *)
      let acked = not one in
      let t =
        if acked
        then checked t ~name:"zero low" ~cycles ~lo:(13 * ms / 10) ~hi:(17 * ms / 10)
        else checked t ~name:"one low" ~cycles ~lo:(4 * ms / 10) ~hi:(8 * ms / 10)
      in
      let block = List.rev t.bits in
      let t =
        { t with
          bits = []
        ; bytes = byte (List.take block 8) :: t.bytes
        ; acks = acked :: t.acks
        }
      in
      if List.nth_exn block 8
      then (
        match List.rev t.bytes with
        | header :: data ->
          let frame =
            { Frame.initiator = header lsr 4; destination = header land 0xf; data }
          in
          let acks = List.rev t.acks in
          let t = check_free t frame in
          { t with
            in_frame = false
          ; previous =
              Some
                { initiator = Some frame.initiator
                ; blocks = header :: data
                ; whole = true
                ; went_through = went_through ~destination:frame.destination acks
                }
          ; frames = (frame, acks) :: t.frames
          }
        | [] -> raise_s [%message "BUG: a block is in"])
      else t)
    else (
      let t =
        if one
        then checked t ~name:"one low" ~cycles ~lo:(4 * ms / 10) ~hi:(8 * ms / 10)
        else checked t ~name:"zero low" ~cycles ~lo:(13 * ms / 10) ~hi:(17 * ms / 10)
      in
      { t with bits = one :: t.bits })
  ;;

  (* a start bit's period is at most 4.7 ms and a bit's 2.75; the line high past that
     inside a frame is the initiator giving it up *)
  let aborted t ~low =
    match t.fall with
    | Some (fall, bit) when t.in_frame && not low ->
      let limit =
        match bit with
        | Start -> 47 * ms / 10
        | Data -> 275 * ms / 100
      in
      not (Measured.at_most ~clock_hz:t.clock_hz (t.now - fall) ~ns:limit)
    | _ -> false
  ;;

  let step t ~low =
    let t =
      match t.low, low, t.fall with
      | false, true, _ -> fell t
      | true, false, Some (fall, _) -> rose t ~fall
      | _ -> t
    in
    let t =
      if aborted t ~low
      then (
        let initiator =
          match List.last t.bytes, List.rev t.bits with
          | Some header, _ -> Some (header lsr 4)
          | None, bits when List.length bits >= 4 -> Some (byte (List.take bits 4))
          | None, _ -> None
        in
        let previous =
          { Previous.initiator
          ; blocks = List.rev t.bytes
          ; whole = false
          ; went_through = false
          }
        in
        { t with
          in_frame = false
        ; bits = []
        ; bytes = []
        ; acks = []
        ; previous = Some previous
        })
      else t
    in
    { t with low; now = t.now + 1 }
  ;;

  let frames t = List.rev t.frames
  let measured t = t.measured
  let violations t = List.rev t.violations
end

open Pin_trace
module Reg = Host_port.Reg

let certified =
  Certified.plain
    ~period:standard_unit
    ~period_floor:shortest_unit
    ~no_wrap:true
    "cec"
    firmware
    config
;;

(* A unit of 25 cycles, as a 500 kHz clock gives, keeps the simulation short. *)
let scenario =
  let clock_hz = 500_000 in
  let unit = clock_hz / 20_000 in
  let frame ~to_ data = { Frame.initiator = 4; destination = to_; data } in
  let frames =
    [ frame ~to_:0 []
    ; frame ~to_:0 [ 0x04 ]
    ; frame ~to_:0 [ 0x47; Char.to_int 'C'; Char.to_int 'E'; Char.to_int 'C' ]
    ; frame ~to_:15 [ 0x36 ]
    ]
  in
  let peer () =
    let follower = ref (Follower.create ~clock_hz ~address:0) in
    let low = ref false in
    { Peer.inputs = (fun () -> if !low then 0 else 1 lsl pin)
    ; step =
        (fun ~pin_out:_ ~pin_dir ->
          low := Peer.bit pin_dir pin = 1 || Follower.drive_low !follower;
          follower := Follower.step !follower ~low:!low)
    }
  in
  (* the start bit is 90 units, a block 480, and the line is left free for 336 *)
  let send (frame : Frame.t) =
    let blocks = 1 + List.length frame.data in
    [ Step.Write (Reg.tx, words frame)
    ; Run ((90 + (480 * blocks) + 336 + 10) * unit)
    ; Read (Reg.rx, blocks)
    ]
  in
  { Scenario.name = "cec"
  ; peer
  ; script =
      Scenario.load ~assumptions:(Certified.assumptions certified) ~config ~program:(Firmware.assemble firmware) ()
      @ [ Scenario.start; Write (Reg.tx, [ unit ]) ]
      @ List.concat_map frames ~f:send
  ; sigrok =
      Some
        { clock_hz
        ; decoders = [ Sigrok.decoder "cec" ~pins:[ "cec", pin ] ]
        ; expect =
            [ ( "cec=frames"
              , List.map frames ~f:(fun frame ->
                  ((frame.initiator lsl 4) lor frame.destination) :: frame.data
                  |> List.map ~f:(sprintf "%02x")
                  |> String.concat ~sep:":")
                |> Sigrok.lines "cec" )
            ; (* the follower at 0 pulls each ACK slot low; nobody refuses a broadcast *)
              ( "cec=ack:nack"
              , List.concat_map frames ~f:(fun frame ->
                  List.init (1 + List.length frame.data) ~f:(fun _ -> "ACK"))
                |> Sigrok.lines "cec" )
            ]
        ; joins_after = None
        ; rejected = None
        ; (* edge 5 ends the low of the header's first one: 0.9 ms, past a one's 0.8 *)
          teeth = [ [ Shift { pin; edge = 5; cycles = 6 * unit } ] ]
        }
  }
;;

(* the firmware on the bench's clock, sending a polling message, a header and no data, to
   the TV at 0 *)
let bench =
  let unit = Bench.cycles_in ~us:50 in
  { Bench.name = "cec"
  ; what =
      [%string
        "Cec.firmware: an initiator's frames, %{unit#Int} cycles a 50 us unit, on IO0, \
         which no demo has wired yet"]
  ; source = firmware
  ; config
  ; assumption = Floor shortest_unit
  ; clock_hz = Bench.clock_hz
  ; load = Some unit
  ; stimulus =
      Some
        { bursts = [ words { initiator = 4; destination = 0; data = [] } ]
        ; quiet = 0
        ; cycles = 600 * unit
        }
  }
;;

(* HDMI 1.3a's bit timings, the line low where anyone pulls it. A low under 1 ms is a
   one's, to 2.5 ms a zero's and past it a start bit's; a bit runs from its fall to the
   next, and the last of a frame, whose high runs on past 2.75 ms, has none. All are the
   run's: the kernel's least low counts one pass of each loop of waits, two units. *)
let limits =
  let sheet figure page =
    { Datasheet.Sheet.part = "HDMI-CEC"
    ; document = "HDMI Specification 1.3a, Supplement 1 CEC"
    ; page = [%string "%{figure}, p. %{page}"]
    }
  in
  let start = sheet "CEC 5.2.1, CEC Figure 3" "CEC-8"
  and bit = sheet "CEC 5.2.2, CEC Figure 4" "CEC-9" in
  let ms ~clock_hz ms = Datasheet.cycles ~clock_hz (ms *. 1e6) in
  let bits ~clock_hz levels =
    List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, low), (_, after)) ->
      Option.some_if ((not high) && after < ms ~clock_hz 2.75) (low, low + after))
  in
  let lows ~from ~until f =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter_map (bits ~clock_hz levels) ~f:(fun ((low, _) as bit) ->
        Option.some_if (low >= ms ~clock_hz from && low < ms ~clock_hz until) (f bit)))
  in
  let limit parameter limit sheet bound =
    { Datasheet.firmware = "cec"; parameter; limit; sheet; margin = Cycle; bound }
  in
  [ limit "start low" (At_least 3.5e6) start (lows ~from:2.5 ~until:10. fst)
  ; limit "start low" (At_most 3.9e6) start (lows ~from:2.5 ~until:10. fst)
  ; limit "start bit" (At_least 4.3e6) start (lows ~from:2.5 ~until:10. snd)
  ; limit "start bit" (At_most 4.7e6) start (lows ~from:2.5 ~until:10. snd)
  ; limit "one low, T1" (At_least 0.4e6) bit (lows ~from:0. ~until:1. fst)
  ; limit "one low, T2" (At_most 0.8e6) bit (lows ~from:0. ~until:1. fst)
  ; limit "zero low, T5" (At_least 1.3e6) bit (lows ~from:1. ~until:2.5 fst)
  ; limit "zero low, T6" (At_most 1.7e6) bit (lows ~from:1. ~until:2.5 fst)
  ; limit "bit, T7" (At_least 2.05e6) bit (lows ~from:0. ~until:2.5 snd)
  ; limit "bit, T8" (At_most 2.75e6) bit (lows ~from:0. ~until:2.5 snd)
  ]
;;

let protocol =
  { Protocol.name = "cec"
  ; certified = [ certified ]
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept = [ "cec", "open drain, which a wire does not show" ]
  ; scenarios = []
  ; decoded = [ scenario ]
  }
;;
