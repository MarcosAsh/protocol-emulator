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
    set y, 4                 ; signal free time, five bit periods
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
        checked
          t
          ~name:"free"
          ~ns:(ns (t.now - fall) - (24 * ms / 10))
          ~lo:(12 * ms)
          ~hi:Int.max_value
      | Some (_, Start) | None -> t
    in
    let ack_slot = t.in_frame && List.length t.bits = 9 in
    let driving_until =
      if ack_slot && addressed t then Some (t.now + (15 * ms / 10 / t.cycle_ns)) else None
    in
    { t with fall = Some (t.now, if t.in_frame then Data else Start); driving_until }
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
        if Option.is_some t.driving_until
        then t
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
          { t with
            in_frame = false
          ; frames =
              ( { Frame.initiator = header lsr 4; destination = header land 0xf; data }
              , List.rev t.acks )
              :: t.frames
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

  let step t ~low =
    let t =
      match t.low, low, t.fall with
      | false, true, _ -> fell t
      | true, false, Some (fall, _) -> rose t ~fall
      | _ -> t
    in
    { t with low; now = t.now + 1 }
  ;;

  let frames t = List.rev t.frames
  let measured t = t.measured
  let violations t = List.rev t.violations
end
