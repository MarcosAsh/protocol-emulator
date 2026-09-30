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
    { cycle_ns : int
    ; address : int
    ; now : int
    ; low : bool
    ; fall : (int * Bit.t) option (* the last fall, and what it began *)
    ; bits : bool list (* this block's, last first *)
    ; bytes : int list
    ; acks : bool list
    ; in_frame : bool
    ; free_ns : int option (* before this frame, checked at its EOM *)
    ; previous : Previous.t option
    ; driving_until : int option
    ; frames : (Frame.t * bool list) list
    ; measured : Measured.t
    ; violations : string list
    }

  let create ~cycle_ns ~address =
    { cycle_ns
    ; address
    ; now = 0
    ; low = false
    ; fall = None
    ; bits = []
    ; bytes = []
    ; acks = []
    ; in_frame = false
    ; free_ns = None
    ; previous = None
    ; driving_until = None
    ; frames = []
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let drive_low t = Option.exists t.driving_until ~f:(fun until -> t.now < until)
  let ms = 1_000_000

  let checked t ~name ~ns ~lo ~hi =
    let t = { t with measured = Measured.add t.measured ~name ~ns } in
    if ns >= lo && ns <= hi
    then t
    else { t with violations = [%string "%{name} of %{ns#Int} ns"] :: t.violations }
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
    let ns cycles = cycles * t.cycle_ns in
    let t =
      match t.fall with
      | Some (fall, Start) when t.in_frame ->
        checked
          t
          ~name:"start"
          ~ns:(ns (t.now - fall))
          ~lo:(43 * ms / 10)
          ~hi:(47 * ms / 10)
      | Some (fall, Data) when t.in_frame ->
        checked
          t
          ~name:"bit"
          ~ns:(ns (t.now - fall))
          ~lo:(205 * ms / 100)
          ~hi:(275 * ms / 100)
      | Some (fall, Data) ->
        (* 3 bit periods at least, whatever the frame; which of 3, 5 or 7 at its EOM *)
        let free = ns (t.now - fall) - (24 * ms / 10) in
        if Option.is_some t.previous && free < 3 * 24 * ms / 10
        then (
          let t =
            checked t ~name:"free" ~ns:free ~lo:(3 * 24 * ms / 10) ~hi:Int.max_value
          in
          { t with free_ns = None })
        else { t with free_ns = Some free }
      | Some (_, Start) | None -> t
    in
    let ack_slot = t.in_frame && List.length t.bits = 9 in
    let driving_until =
      if ack_slot && addressed t then Some (t.now + (15 * ms / 10 / t.cycle_ns)) else None
    in
    { t with fall = Some (t.now, if t.in_frame then Data else Start); driving_until }
  ;;

  (* CEC 9.1's signal free time, in nominal bit periods of 2.4 ms; a retry is the same
     frame again, as Linux's cec-adap.c takes it *)
  let check_free t (frame : Frame.t) =
    match t.free_ns, t.previous with
    | Some ns, Some previous ->
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
      checked t ~name:"free" ~ns ~lo:(periods * 24 * ms / 10) ~hi:Int.max_value
    | _ -> t
  ;;

  (* a directed block goes through when acknowledged, a broadcast one unless refused *)
  let went_through ~destination acks =
    if destination = 0xf
    then not (List.exists acks ~f:Fn.id)
    else List.for_all acks ~f:Fn.id
  ;;

  let rose t ~fall =
    let low_ns = (t.now - fall) * t.cycle_ns in
    if not t.in_frame
    then (
      let t =
        checked t ~name:"start low" ~ns:low_ns ~lo:(35 * ms / 10) ~hi:(39 * ms / 10)
      in
      { t with in_frame = true; bits = []; bytes = []; acks = [] })
    else if List.length t.bits = 9
    then (
      (* the ACK slot: what a sample at 1.05 ms sees *)
      let acked = low_ns > 105 * ms / 100 in
      let t =
        if acked
        then checked t ~name:"zero low" ~ns:low_ns ~lo:(13 * ms / 10) ~hi:(17 * ms / 10)
        else checked t ~name:"one low" ~ns:low_ns ~lo:(4 * ms / 10) ~hi:(8 * ms / 10)
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
      let one = low_ns <= 105 * ms / 100 in
      let t =
        if one
        then checked t ~name:"one low" ~ns:low_ns ~lo:(4 * ms / 10) ~hi:(8 * ms / 10)
        else checked t ~name:"zero low" ~ns:low_ns ~lo:(13 * ms / 10) ~hi:(17 * ms / 10)
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
      (t.now - fall) * t.cycle_ns > limit
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
