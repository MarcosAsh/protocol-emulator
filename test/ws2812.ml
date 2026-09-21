open! Core
open Protocol_emulator

let pin = 5
let cycle_ns = 20

(* y is the number of bits in the word less one: 15 for the first word of a pixel, 7 for
   the second. Both ways round the end of a word take the same thirteen cycles. *)
let firmware ~third ~tail =
  [%string
    {|
    mov t, now
    set pins, 0
    set p, %{third#Int}
latch:
    mov t, now
    set x, 31
gap:
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    jmp x--, gap
    wait t                   ; the line has been low for 160 thirds
    wait tx
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
    add t, %{tail#Int}
    jmp x--, bit
    set x, 15
    jmp x!=y, last
    set y, 7
    jmp word
last:
    jmp tx, pixel
    jmp latch
|}]
;;

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
