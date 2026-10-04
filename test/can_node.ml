open! Core
open Protocol_emulator

let rx_pin = 1

(* Can.tx_pin, written out for [%firmware] to read *)
let tx_pin = 6

let () =
  if tx_pin <> Can.tx_pin
  then raise_s [%message "BUG: CTX is not Can.tx_pin" (tx_pin : int)]
;;

module Receiver = struct
  let period = 96
  let sample = 72
  let shortest_period = 63

  let config =
    { Program_config.default with
      in_base = rx_pin
    ; in_count = 1
    ; out_base = tx_pin
    ; set_base = tx_pin
    ; jmp_pin = rx_pin
    ; capture_pin = rx_pin
    ; capture_rising = false
    ; in_shift = Left
    ; out_shift = Right
    ; autopush = true
    ; push_threshold = 16
    ; crc_width = 15
    ; crc_poly = 0x4599
    ; crc_init = 0
    ; crc_reflect = false
    }
  ;;

  let lines = String.concat ~sep:"\n"

  (* the top five bits by [set], then a doubling per bit left *)
  let load_period period =
    let width = Int.ceil_log2 (period + 1) in
    let top = period lsr Int.max 0 (width - 5) in
    [%string "    set p, %{top#Int}"]
    :: List.concat_map
         (List.range ~stride:(-1) (width - 6) (-1))
         ~f:(fun bit ->
           "    add p, p"
           :: (if (period lsr bit) land 1 = 1 then [ "    add p, 1" ] else []))
  ;;

  (* n added to t through y, which the caller sets again after: k equal parts of at most
     31, the rest in immediates of at most 7 *)
  let add_to_t n =
    let parts = (n + 30) / 31 in
    let part = n / Int.max parts 1 in
    let rec rest n = if n = 0 then [] else Int.min n 7 :: rest (n - Int.min n 7) in
    (if parts = 0 then [] else [ [%string "    set y, %{part#Int}"] ])
    @ List.init parts ~f:(fun _ -> "    add t, y")
    @ List.map (rest (n - (parts * part))) ~f:(fun r -> [%string "    add t, %{r#Int}"])
  ;;

  (* exactly n cycles of nops *)
  let delay n =
    List.init (n / 32) ~f:(fun _ -> "    nop [31]")
    @ if n % 32 = 0 then [] else [ [%string "    nop [%{n % 32 - 1#Int}]"] ]
  ;;

  (* One field's bits: x is the number left less one, y counts a run down from 3 and is
     spent at five equal bits, and the last bit's level is the half of the loop the core
     is in. [in pins] samples a bit [sample] cycles in, and [jmp pin] reads it again a
     cycle later to pick the half. A recessive bit arms the capture, so a fall before the
     next sample is caught and the bits are timed from it, as can2040 does. Stuff bits are
     checked and kept out of isr and the CRC. The loop leaves at [high_end] or [low_end]
     by the last level. *)
  let field name ~sample ~high_end ~low_end =
    lines
      ([ [%string "%{name}_high:"]
       ; "    wait t+"
       ; "    in pins, 1"
       ; [%string "    jmp pin, %{name}_held_high"]
       ; [%string "%{name}_fell:"]
       ; [%string "    wait 0 pin %{rx_pin#Int}"]
       ; "    mov t, capture"
       ; "    add t, p"
       ]
       @ add_to_t (sample - 1)
       @ [ "    set y, 3"
         ; [%string "    jmp x--, %{name}_low"]
         ; [%string "    jmp %{low_end}"]
         ; [%string "%{name}_held_high:"]
         ; "    capture_arm"
         ; [%string "    jmp y--, %{name}_next_high"]
         ; "    wait t+                  ; a stuff bit, dominant"
         ; "    jmp pin, stuffing"
         ; [%string "    jmp %{name}_fell"]
         ; [%string "%{name}_next_high:"]
         ; [%string "    jmp x--, %{name}_high"]
         ; [%string "    jmp %{high_end}"]
         ; [%string "%{name}_low:"]
         ; "    wait t+"
         ; "    in pins, 1"
         ; [%string "    jmp pin, %{name}_rose"]
         ; [%string "    jmp y--, %{name}_next_low"]
         ; "    wait t+                  ; a stuff bit, recessive"
         ; [%string "    jmp pin, %{name}_rose"]
         ; "    jmp stuffing"
         ; [%string "%{name}_rose:"]
         ; "    capture_arm"
         ; "    set y, 3"
         ; [%string "    jmp x--, %{name}_high"]
         ; [%string "    jmp %{high_end}"]
         ; [%string "%{name}_next_low:"]
         ; [%string "    jmp x--, %{name}_low"]
         ; [%string "    jmp %{low_end}"]
         ])
  ;;

  (* isr holds RTR, IDE, r0 and the DLC, the ID gone in the first word. A frame with IDE
     or r0 recessive is refused; otherwise they go to the host and x is the data bits less
     one. An odd number of bytes starts with a zero byte, so they fill whole words. *)
  let header_end level =
    lines
      [ [%string "header_%{level}_end:"]
      ; "    mov osr, isr"
      ; "    out null, 4"
      ; "    out x, 2                 ; r0 and IDE"
      ; "    jmp x--, refused"
      ; "    mov x, osr               ; RTR"
      ; [%string "    jmp x--, remote_%{level}"]
      ; "    mov osr, isr"
      ; "    out null, 3"
      ; "    mov x, osr               ; the DLC's top bit"
      ; [%string "    jmp x--, eight_%{level}"]
      ; "    mov osr, ::isr"
      ; "    out null, 15"
      ; "    mov x, osr               ; the DLC's low bit"
      ; [%string "    jmp x--, odd_%{level}"]
      ; "    mov x, isr"
      ; "    push"
      ; "    add x, x"
      ; "    add x, x"
      ; "    add x, x"
      ; [%string "    jmp x--, data_%{level}"]
      ; "    set x, 14                ; no data: the CRC"
      ; [%string "    jmp crc_%{level}"]
      ; [%string "odd_%{level}:"]
      ; "    mov x, isr"
      ; "    push"
      ; "    in null, 8"
      ; "    add x, x"
      ; "    add x, x"
      ; "    add x, x"
      ; "    sub x, 1"
      ; [%string "    jmp data_%{level}"]
      ; [%string "eight_%{level}:"]
      ; "    push"
      ; "    set x, 31"
      ; "    add x, x"
      ; "    add x, 1                 ; eight bytes"
      ; [%string "    jmp data_%{level}"]
      ; [%string "remote_%{level}:"]
      ; "    push"
      ; "    set x, 14"
      ; [%string "    jmp crc_%{level}"]
      ]
  ;;

  let data_end level =
    lines
      [ [%string "data_%{level}_end:"]
      ; "    set x, 14"
      ; [%string "    jmp crc_%{level}"]
      ]
  ;;

  let source ~period ~sample =
    if sample < 1 || sample > period - 5
    then raise_s [%message "BUG: no room for the ACK" (period : int) (sample : int)];
    lines
      (load_period period
       @ [ "    set pins, 1              ; recessive"
         ; "    mov t, now"
         ; "    add t, p"
         ; "idle:"
         ; "    set x, 10"
         ; "quiet:"
         ; "    wait t+"
         ; "    jmp pin, recessive"
         ; "    jmp idle"
         ; "recessive:"
         ; "    jmp x--, quiet           ; eleven recessive bits: the bus is idle"
         ; "sof:"
         ; "    capture_arm"
         ; "    jmp pin, armed"
         ; "    mov t, now               ; a SOF edge came a few cycles before the arm"
         ; "    jmp sofed"
         ; "armed:"
         ; [%string "    wait 0 pin %{rx_pin#Int}             ; SOF, its edge in capture"]
         ; "    mov t, capture"
         ; "sofed:"
         ]
       @ add_to_t (sample - 1)
       @ [ "    wait t+"
         ; "    jmp pin, sof             ; recessive again: no SOF"
         ; "    crc_init"
         ; "    in null, 5               ; so the ID fills the first word"
         ; "    set y, 3"
         ; "    set x, 17                ; ID, RTR, IDE, r0 and the DLC"
         ; "    jmp header_low"
         ; field "header" ~sample ~high_end:"header_high_end" ~low_end:"header_low_end"
         ; header_end "high"
         ; header_end "low"
         ; field "data" ~sample ~high_end:"data_high_end" ~low_end:"data_low_end"
         ; data_end "high"
         ; data_end "low"
         ; field "crc" ~sample ~high_end:"crc_end" ~low_end:"crc_end"
         ; "crc_end:"
         ; "    mov isr, null"
         ; "    in crc, 15"
         ; "    mov x, isr               ; zero when the CRC holds"
         ; "    wait t+                  ; the CRC delimiter"
         ; "    jmp pin, delimited"
         ; "    jmp form"
         ; "delimited:"
         ; "    jmp x--, crc_error"
         ]
       @ delay (period - sample - 5)
       @ [ "    set pins, 0              ; ACK, from the slot's start"; "    wait t+" ]
       @ delay (period - sample - 1)
       @ [ "    set pins, 1              ; to its end"
         ; "    mov isr, null"
         ; "    push"
         ; "    set x, 9                 ; ACK delimiter, EOF, two of the intermission"
         ; "    jmp quiet"
         ; "stuffing:"
         ; "    set x, 1"
         ; "    jmp error"
         ; "refused:"
         ; "    set x, 2"
         ; "    jmp error"
         ; "form:"
         ; "    set x, 3"
         ; "    jmp error"
         ; "crc_error:"
         ; "    set x, 4"
         ; "error:"
         ; "    mov isr, x"
         ; "    push"
         ; "    irq"
         ; "    wait tx                  ; the host has read the words and cleared irq"
         ; "    pull"
         ; "    mov t, now"
         ; "    add t, p"
         ; "    jmp idle"
         ])
  ;;

  let check ~period ~sample =
    Timed_program.check ~period ~single_capture_edge:true ~config (source ~period ~sample)
  ;;

  let firmware =
    Timed_program.of_source_exn
      ~period
      ~single_capture_edge:true
      ~config
      (source ~period ~sample)
  ;;

  module Error_code = struct
    type t =
      | Stuffing
      | Refused
      | Form
      | Crc
    [@@deriving sexp_of, compare, equal, enumerate]

    let to_word t =
      1 + List.find_mapi_exn all ~f:(fun i c -> Option.some_if (equal t c) i)
    ;;

    let of_word word = List.nth all (word - 1)
  end

  let words (frame : Can.Frame.t) =
    let bytes = if frame.rtr then [] else List.take frame.data (Int.min frame.dlc 8) in
    let bytes = if List.length bytes % 2 = 1 then 0 :: bytes else bytes in
    (frame.id
     :: ((Bool.to_int frame.rtr lsl 6) lor frame.dlc)
     :: List.map (List.chunks_of bytes ~length:2) ~f:(function
       | [ high; low ] -> (high lsl 8) lor low
       | _ -> raise_s [%message "BUG: bytes in pairs"]))
    @ [ 0 ]
  ;;

  module Event = struct
    type t =
      | Frame of Can.Frame.t
      | Error of Error_code.t
    [@@deriving sexp_of, compare, equal]
  end

  let frame words =
    match words with
    | id :: control :: rest when control < 0x80 ->
      let rtr = control land 0x40 <> 0
      and dlc = control land 0xf in
      let bytes = if rtr then 0 else Int.min dlc 8 in
      let #(data, rest) = List.split_n rest ((bytes + 1) / 2) in
      let data =
        List.concat_map data ~f:(fun word -> [ word lsr 8; word land 0xff ])
        |> fun all -> List.drop all (List.length all - bytes)
      in
      (match rest with
       | 0 :: rest when List.length data = bytes ->
         Some ({ Can.Frame.id; rtr; dlc; data }, rest)
       | _ -> None)
    | _ -> None
  ;;

  (* Whole frames, then what an error left: the words of the frame it ended and its code,
     the last word the core pushed before it raised [irq]. *)
  let rec read words =
    match frame words with
    | Some (frame, rest) ->
      Or_error.map (read rest) ~f:(fun events -> Event.Frame frame :: events)
    | None ->
      (match List.last words with
       | None -> Ok []
       | Some code ->
         (match Error_code.of_word code with
          | Some code -> Ok [ Event.Error code ]
          | None ->
            Or_error.error_s [%message "neither a frame nor an error" (words : int list)]))
  ;;
end

let sender_shortest_period = 15

let sender_config =
  { Program_config.default with
    in_base = rx_pin
  ; in_count = 1
  ; out_base = tx_pin
  ; set_base = tx_pin
  ; jmp_pin = tx_pin
  ; out_shift = Left
  ; autopull = true
  ; crc_width = 15
  ; crc_poly = 0x4599
  ; crc_init = 0
  ; crc_reflect = false
  }
;;

(* [Can.firmware] to the CRC delimiter, then the bus 11 cycles before the ACK slot ends,
   after which the deadlines go back to the bit's edges. *)
let sender =
  [%firmware
    {|
    wait tx
    pull
    mov p, osr               ; the bit period
    mov t, now
    add t, p
    wait t+
    set pins, 1              ; recessive
frame:
    wait tx
    pull
    mov x, osr               ; bits after SOF, less one
    out null, 16             ; the next out autopulls the first word of them
    crc_init
    mov t, now
    add t, p
    wait t+
    set pins, 0              ; SOF
    set y, 3
dbit:
    jmp pin, dhigh
    wait t+
    out pins, 1
    jmp pin, dchanged
    jmp dsame
dhigh:
    wait t+
    out pins, 1
    jmp pin, dsame
dchanged:
    set y, 3
    jmp dnext
dsame:
    jmp y--, dnext
    wait t+
    mov pins, !pins          ; stuff
    set y, 3
dnext:
    jmp x--, dbit
    in crc, 15
    mov osr, isr
    set x, 14
cbit:
    jmp pin, chigh
    wait t+
    out pins, 1
    jmp pin, cchanged
    jmp csame
chigh:
    wait t+
    out pins, 1
    jmp pin, csame
cchanged:
    set y, 3
    jmp cnext
csame:
    jmp y--, cnext
    wait t+
    mov pins, !pins          ; stuff
    set y, 3
cnext:
    jmp x--, cbit
    wait t+
    set pins, 1              ; CRC delimiter
    wait t+                  ; the ACK slot
    sub t, 7
    sub t, 5
    wait t
    mov isr, pins            ; the bus: 0 is an ACK
    push
    add t, 7
    add t, 5
    set x, 10                ; ACK delimiter, EOF, intermission
tail:
    wait t+
    jmp x--, tail
    jmp frame
|}
      ~config:sender_config
      ~period_floor:sender_shortest_period]
;;

module Sender = struct
  let config = sender_config
  let firmware = sender
  let shortest_period = sender_shortest_period
end
