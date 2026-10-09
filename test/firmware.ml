open! Core
open Protocol_emulator

let assemble source = Asm.assemble source |> ok_exn |> Asm.Program.words |> ok_exn
let usb_scratch_pin = 5
let usb_dp_pin = 6
let usb_dm_pin = 7

let usb_config =
  { Program_config.default with
    in_base = usb_scratch_pin
  ; out_base = usb_scratch_pin
  ; out_count = 3
  ; set_base = usb_dp_pin
  ; set_count = 2
  ; jmp_pin = usb_scratch_pin
  ; out_shift = Right
  ; stuff_threshold = 6
  ; stuff_level = true
  }
;;

(* USB low speed transmitter. The host sends the bit period, then per packet SYNC, PID,
   data length less one and the data; the core adds CRC-16, bit stuffing and EOP. Each
   data bit goes out on a scratch pin first so the CRC sees it and [jmp pin] reads it
   back. Every toggle lands four cycles after its deadline on either path. *)
let usb_tx =
  [%firmware
    {|
    pull
    mov p, osr
    set pins, 2              ; idle J
packet:
    wait tx
    mov t, now
    add t, p
    set y, 1                 ; SYNC and PID
hbyte:
    pull
    set x, 7
hbit:
    jmp stuff, hstuff
    wait t+
    out pins, 1
    jmp pin, hkeep
    mov pins, !pins
hkeep:
    jmp x--, hbit
    jmp y--, hbyte
    crc_init
    pull
    mov y, osr               ; data bytes less one
dbyte:
    pull
    set x, 7
dbit:
    jmp stuff, dstuff
    wait t+
    out pins, 1
    jmp pin, dkeep
    mov pins, !pins
dkeep:
    jmp x--, dbit
    jmp y--, dbyte
    in crc, 16
    mov osr, !isr
    set x, 15
cbit:
    jmp stuff, cstuff
    wait t+
    out pins, 1
    jmp pin, ckeep
    mov pins, !pins
ckeep:
    jmp x--, cbit
    jmp stuff, estuff
eop:
    wait t+
    set pins, 0              ; SE0
    wait t+
    wait t+
    set pins, 2              ; J
    wait t+
    jmp packet
hstuff:
    wait t+
    nop [2]
    mov pins, !pins
    stuff_reset
    jmp hbit
dstuff:
    wait t+
    nop [2]
    mov pins, !pins
    stuff_reset
    jmp dbit
cstuff:
    wait t+
    nop [2]
    mov pins, !pins
    stuff_reset
    jmp cbit
estuff:
    wait t+
    nop [2]
    mov pins, !pins
    stuff_reset
    jmp eop
|}
      ~config:usb_config
      ~period:32]
;;

(* USB low speed receiver. The host sends the bit period; the half period is an immediate
   so the analyser can follow it. Sampling starts half a bit after the first K of SYNC.
   Bits go through [in] one at a time so the CRC sees them; after the EOP the CRC register
   follows as one more word for the host to check. Stuffed zeros are dropped. *)
let usb_rx ~half_period =
  let rec adds n = if n <= 7 then [ n ] else 7 :: adds (n - 7) in
  let anchor =
    List.map (adds half_period) ~f:(fun n -> [%string "    add t, %{n#Int}"])
    |> String.concat ~sep:"\n"
  in
  [%string
    {|
    pull
    mov p, osr
idle:
    set y, 1                 ; J
    crc_init
    stuff_reset
    capture_arm
    wait 1 pin 4             ; D+ rises: the first K of SYNC
    mov t, capture
%{anchor}
bit:
    jmp stuff, stuffed
    wait t+
    mov x, pins
    jmp x!=y, changed
    set x, 1
    in x, 1                  ; the line held: a one
    jmp bit
changed:
    mov y, x
    jmp x--, zero
    in crc, 16               ; SE0: the packet is over
    jmp idle
zero:
    in null, 1
    jmp bit
stuffed:
    wait t+
    mov x, pins
    mov y, x
    stuff_reset
    jmp bit
|}]
;;

let usb_rx_dm_pin = 3
let usb_rx_dp_pin = 4

let usb_rx_config =
  { Program_config.default with
    in_base = usb_rx_dm_pin
  ; in_count = 2
  ; capture_pin = usb_rx_dp_pin
  ; capture_rising = true
  ; in_shift = Right
  ; autopush = true
  ; push_threshold = 8
  ; stuff_threshold = 6
  ; stuff_level = true
  }
;;

(* Self-measurement: OUT0 is wired back to IN0 and every rising edge is timestamped, so
   measured intervals can be set against the analyser's prediction. *)
let edge_meter ~period =
  [%string
    {|
    set p, %{period#Int}
    set pins, 0
    mov t, now
    add t, p
loop:
    capture_arm
    wait t+
    mov pins, !pins
    wait t+
    mov pins, !pins          ; one of the two is the rising edge
    nop [3]                  ; it comes back and is captured
    in capture, 16
    jmp loop
|}]
;;

let edge_meter_config =
  { Program_config.default with
    in_base = 0
  ; out_base = 5
  ; out_count = 1
  ; capture_pin = 0
  ; capture_rising = true
  ; autopush = true
  ; push_threshold = 16
  }
;;

(* Every pin wait releases a fixed number of cycles after its edge, so stamp differences
   are edge differences. *)
let edge_logger ~pin =
  [%string
    {|
    jmp pin, high
low:
    wait 1 pin %{pin#Int}
    mov x, now
    in x, 16
high:
    wait 0 pin %{pin#Int}
    mov x, now
    in x, 16
    jmp low
|}]
;;

let edge_logger_config ~pin =
  { Program_config.default with jmp_pin = pin; autopush = true; push_threshold = 16 }
;;

(* Both stamps are the instruction after a pin wait, and both pins pass one synchroniser,
   so their difference is the gap between the edges as sampled: exact to a cycle. *)
let start_hold ~sda ~scl =
  [%string
    {|
start:
    wait fall pin %{sda#Int}
    mov x, now               ; SDA fell
    jmp !pin, start          ; with SCL low: a data bit
    wait 0 pin %{scl#Int}
    mov y, now               ; SCL fell: the START is over
    jmp !rx, start           ; no room, so this one is dropped
    sub y, x
    in y, 16
    jmp start
|}]
;;

let start_hold_config ~scl =
  { Program_config.default with jmp_pin = scl; autopush = true; push_threshold = 16 }
;;

let usb_device_dp_pin = 12
let usb_device_dm_pin = 13
let usb_device_flag_pin = 14

let usb_device_config =
  { Program_config.default with
    in_base = usb_device_dp_pin
  ; in_count = 2
  ; out_base = usb_device_dp_pin
  ; out_count = 2
  ; set_base = usb_device_dp_pin
  ; set_count = 3
  ; jmp_pin = usb_device_flag_pin
  ; capture_pin = usb_device_dp_pin
  ; capture_rising = true
  ; in_shift = Left
  ; out_shift = Right
  ; autopull = true
  ; stuff_threshold = 6
  ; stuff_level = true
  }
;;

module Usb_line = struct
  type t =
    | J
    | K

  let other = function
    | J -> K
    | K -> J
  ;;

  let suffix = function
    | J -> "j"
    | K -> "k"
  ;;

  let both f = List.concat_map [ J; K ] ~f
end

(* USB low speed device. [mov x, pins] reads J as 2, K as 1, SE0 as 0. The previous line
   state lives in the program counter (each sampling piece exists for J and for K),
   leaving y to count bits. Token address and endpoint are compared, CRC5 included,
   against a constant for [address] endpoint 0, so the CRC unit stays on CRC-16; endpoint
   1 is the only other match. The first PID nibble is walked as a tree, so telling packets
   apart costs no cycles. To the host: SETUP/OUT data as tag 1 (DATA0) or 2 (DATA1), then
   16-bit words, first bit on top; ACK if the CRC checks, else the interrupt and silence.
   A host ACK is tag 3; a reply queued for the other endpoint is dropped as tag 4 and
   answered NAK. From the host, per IN reply: endpoint low / PID high, data bits low /
   data words high, then the data. Nothing queued: NAK. *)
let usb_device ~address ~half_period =
  let open Usb_line in
  let label name line = [%string "%{name}_%{suffix line}"] in
  let bits_of value ~count = List.init count ~f:(fun i -> (value lsr i) land 1) in
  let msb_first bits = List.fold bits ~init:0 ~f:(fun acc bit -> (acc lsl 1) lor bit) in
  (* the sixteen bits after a token's PID, for one of our endpoints *)
  let token endpoint =
    let bits = bits_of address ~count:7 @ bits_of endpoint ~count:4 in
    let crc5 =
      List.fold bits ~init:0x1f ~f:(fun crc bit ->
        Crc.step ~width:5 ~poly:0x14 ~reflect:true crc ~bit)
      lxor 0x1f
    in
    msb_first (bits @ bits_of crc5 ~count:5)
  in
  (* a constant in isr, most significant chunk first; more than a bit at a time, so the
     CRC and stuff counter do not see it *)
  let load_isr ?(through = "y") value ~bits =
    let rec chunks left =
      if left = 0
      then []
      else (
        let n =
          if left <= 5
          then left
          else if left % 5 = 1
          then 3
          else if left % 5 = 0
          then 5
          else left % 5
        in
        let chunk = (value lsr (left - n)) land ((1 lsl n) - 1) in
        [%string "    set %{through}, %{chunk#Int}\n    in %{through}, %{n#Int}"]
        :: chunks (left - n))
    in
    "    mov isr, null" :: chunks bits
  in
  let sample ?se0 name line ~one ~zero =
    let same, changed =
      match line with
      | J -> label one J, label zero K
      | K -> label one K, label zero J
    in
    let stays, moves =
      match line with
      | J -> same, changed
      | K -> changed, same
    in
    (* EOP is looked for only where one can be; elsewhere SE0 reads as J and the packet
       fails a later check *)
    let first =
      match se0 with
      | Some se0 ->
        [ [%string "    jmp x--, %{label name line}_nz"]
        ; [%string "    jmp %{se0}"]
        ; [%string "%{label name line}_nz:"]
        ]
      | None -> [ "    sub x, 1" ]
    in
    [ [%string "%{label name line}:"]; "    wait t+"; "    mov x, pins" ]
    @ first
    @ [ [%string "    jmp x--, %{stays}"]; [%string "    jmp %{moves}"] ]
  in
  let node name ~one ~zero = both (fun line -> sample name line ~one ~zero) in
  (* [count] bits that are only counted *)
  let skip name ~count ~next =
    both (fun line ->
      [ [%string "%{label name line}:"]; [%string "    set y, %{count - 1#Int}"] ]
      @ sample (name ^ "_s") line ~one:(name ^ "_n") ~zero:(name ^ "_n")
      @ [ [%string "%{label (name ^ \"_n\") line}:"]
        ; [%string "    jmp y--, %{label (name ^ \"_s\") line}"]
        ; [%string "    jmp %{label next line}"]
        ])
  in
  (* [count] bits shifted into isr, past the CRC and the stuff counter *)
  let field name ~count ~next =
    both (fun line ->
      [ [%string "%{label name line}:"]
      ; [%string "    set y, %{count - 1#Int}"]
      ; [%string "%{label (name ^ \"_b\") line}:"]
      ; [%string "    jmp stuff, %{label (name ^ \"_f\") line}"]
      ]
      @ sample (name ^ "_s") line ~one:(name ^ "_1") ~zero:(name ^ "_0")
      @ [ [%string "%{label (name ^ \"_1\") line}:"]
        ; "    set x, 1"
        ; "    in x, 1"
        ; [%string "    jmp y--, %{label (name ^ \"_b\") line}"]
        ; [%string "    jmp %{label next line}"]
        ; [%string "%{label (name ^ \"_0\") line}:"]
        ; "    in null, 1"
        ; [%string "    jmp y--, %{label (name ^ \"_b\") line}"]
        ; [%string "    jmp %{label next line}"]
        ; [%string "%{label (name ^ \"_f\") line}:"]
        ; "    wait t+"
        ; "    stuff_reset"
        ; [%string "    jmp %{label (name ^ \"_b\") (other line)}"]
        ])
  in
  (* what follows a field does not sample, so one copy serves both line states *)
  let join name = both (fun line -> [ [%string "%{label name line}:"] ]) in
  (* the CRC-16 residue of a good packet *)
  let residual =
    List.fold (bits_of 0 ~count:16) ~init:0xffff ~f:(fun crc bit ->
      Crc.step ~width:16 ~poly:0xa001 ~reflect:true crc ~bit)
  in
  let rec adds n = if n <= 7 then [ n ] else 7 :: adds (n - 7) in
  let anchor =
    List.map (adds half_period) ~f:(fun n -> [%string "    add t, %{n#Int}"])
  in
  let handshake word = [ "    wait t+" ] @ load_isr word ~bits:16 @ [ "    jmp hs" ] in
  List.concat
    [ [ "    pull"; "    mov p, osr"; "idle:"; "    set pins, 2"; "    set pindirs, 4" ]
    ; load_isr (token 0) ~bits:16
    ; [ "    mov osr, isr"
      ; "    mov isr, null"
      ; "    stuff_reset"
      ; "    capture_arm"
      ; [%string "    wait 1 pin %{usb_device_dp_pin#Int}"]
      ; "    mov t, capture"
      ]
    ; anchor
    ; [ "    jmp sync_j" ]
    ; skip "sync" ~count:8 ~next:"pid0"
    ; node "pid0" ~one:"pid1" ~zero:"acked"
    ; node "pid1" ~one:"data2" ~zero:"pid2"
    ; node "data2" ~one:"ignore" ~zero:"data3"
    ; node "data3" ~one:"data1" ~zero:"data0"
    ; node "pid2" ~one:"tok_setup3" ~zero:"tok_inout3"
    ; node "tok_setup3" ~one:"out_token" ~zero:"ignore"
    ; node "tok_inout3" ~one:"in_token" ~zero:"out_token"
    ; both (fun line ->
        [ [%string "%{label \"in_token\" line}:"]
        ; "    set pins, 6"
        ; [%string "    jmp %{label \"check\" line}"]
        ; [%string "%{label \"out_token\" line}:"]
        ; "    set pins, 2"
        ; [%string "    jmp %{label \"check\" line}"]
        ])
    ; field "check" ~count:4 ~next:"clear"
    ; both (fun line ->
        [ [%string "%{label \"clear\" line}:"]
        ; "    mov isr, null"
        ; [%string "    jmp %{label \"token\" line}"]
        ])
    ; field "token" ~count:16 ~next:"match"
    ; join "match"
    ; [ "    mov x, isr"
      ; "    mov isr, null"
      ; "    xor x, osr"
      ; "    mov y, x"
      ; "eop:"
      ; "    wait t+"
      ; "    mov x, pins"
      ; "    jmp x--, eop"
      ; "    jmp y--, endpoint_1"
      ; "    set y, 0"
      ; "ours:"
      ; "    jmp pin, in_reply"
      ; "    jmp idle"
      ; "endpoint_1:"
      ]
    ; load_isr ~through:"x" ((token 0 lxor token 1) - 1) ~bits:16
    ; [ "    mov x, isr"
      ; "    mov isr, null"
      ; "    jmp x!=y, other_kind"
      ; "    set y, 1"
      ; "    jmp ours"
      ; "in_reply:"
      ; "    jmp tx, send"
      ; "nak:"
      ]
    ; handshake 0x5a80
    ; both (fun line ->
        List.concat_map
          [ "data0", 1; "data1", 2 ]
          ~f:(fun (name, tag) ->
            [ [%string "%{label name line}:"]
            ; [%string "    set x, %{tag#Int}"]
            ; "    mov isr, x"
            ; "    push"
            ; [%string "    jmp %{label \"dcheck\" line}"]
            ]))
    ; field "dcheck" ~count:4 ~next:"payload"
    ; both (fun line ->
        [ [%string "%{label \"payload\" line}:"]
        ; "    mov isr, null"
        ; "    crc_init"
        ; [%string "%{label \"word\" line}:"]
        ; "    set y, 15"
        ; [%string "%{label \"data_b\" line}:"]
        ; [%string "    jmp stuff, %{label \"data_f\" line}"]
        ]
        @ sample "data_s" line ~one:"data_1" ~zero:"data_0" ~se0:"data_end"
        @ [ [%string "%{label \"data_1\" line}:"]
          ; "    set x, 1"
          ; "    in x, 1"
          ; [%string "    jmp y--, %{label \"data_b\" line}"]
          ; "    push"
          ; [%string "    jmp %{label \"word\" line}"]
          ; [%string "%{label \"data_0\" line}:"]
          ; "    in null, 1"
          ; [%string "    jmp y--, %{label \"data_b\" line}"]
          ; "    push"
          ; [%string "    jmp %{label \"word\" line}"]
          ; [%string "%{label \"data_f\" line}:"]
          ; "    wait t+"
          ; "    stuff_reset"
          ; [%string "    jmp %{label \"data_b\" (other line)}"]
          ])
    ; [ "data_end:"; "    push"; "    in crc, 16"; "    mov x, isr"; "    wait t+" ]
    ; load_isr residual ~bits:16
    ; [ "    mov y, isr"; "    mov isr, null"; "    jmp x!=y, bad_crc" ]
    ; handshake 0xd280
    ; [ "bad_crc:"; "    irq"; "    jmp idle" ]
    ; both (fun line ->
        [ [%string "%{label \"acked\" line}:"]
        ; "    set x, 3"
        ; "    mov isr, x"
        ; "    push"
        ; "    jmp skip"
        ])
    ; join "other"
    ; [ "other_eop:"
      ; "    wait t+"
      ; "    mov x, pins"
      ; "    jmp x--, other_eop"
      ; "other_kind:"
      ; "    jmp pin, idle"
      ; "    capture_arm"
      ; [%string "    wait 1 pin %{usb_device_dp_pin#Int}"]
      ; "    mov t, capture"
      ]
    ; anchor
    ; [ "    jmp skip" ]
    ; join "ignore"
    ; [ "skip:"; "    wait t+"; "    mov x, pins"; "    jmp x--, skip"; "    jmp idle" ]
    ; [ "send:"
      ; "    wait t+"
      ; "    pull"
      ; "    out x, 8"
      ; "    jmp x!=y, wrong_endpoint"
      ; "    stuff_reset"
      ; "    wait t+"
      ; "    wait t+"
      ; "    set pins, 6"
      ; "    set pindirs, 7"
      ; "    set y, 6"
      ; "sync_bit:"
      ; "    wait t+"
      ; "    nop [2]"
      ; "    mov pins, !pins"
      ; "    jmp y--, sync_bit"
      ; "    wait t+"
      ; "    set y, 7"
      ; "    jmp hs_bit"
      ; "wrong_endpoint:"
      ; "    pull"
      ; "    out null, 8"
      ; "    out x, 8"
      ]
      (* at most four data words, unrolled: a loop on a host count has no bound the
         analyser can see *)
    ; List.concat_map [ 1; 2; 3 ] ~f:(fun n ->
        [ [%string "    jmp x--, drain_%{n#Int}"]
        ; "    jmp drained"
        ; [%string "drain_%{n#Int}:"]
        ; "    pull"
        ])
    ; [ "    jmp x--, drain_4"
      ; "    jmp drained"
      ; "drain_4:"
      ; "    pull"
      ; "drained:"
      ; "    set x, 4"
      ; "    mov isr, x"
      ; "    push"
      ; "    jmp nak"
      ; "hs:"
      ; "    mov osr, isr"
      ; "    wait t+"
      ; "    wait t+"
      ; "    set pins, 2"
      ; "    set pindirs, 7"
      ; "    set y, 15"
      ; "hs_bit:"
      ; "    wait t+"
      ; "    out x, 1"
      ; "    jmp x--, hs_keep"
      ; "    mov pins, !pins"
      ; "hs_keep:"
      ; "    jmp y--, hs_bit"
      ; "    jmp pin, payload_tx"
      ; "eop_tx:"
      ; "    wait t+"
      ; "    nop [2]"
      ; "    set pins, 4"
      ; "    wait t+"
      ; "    wait t+"
      ; "    nop [2]"
      ; "    set pins, 6"
      ; "    wait t+"
      ; "    jmp idle"
      ; "payload_tx:"
      ; "    pull"
      ; "    out y, 8"
      ; "    out null, 16"
      ; "    crc_init"
      ; "    jmp y--, tx_bit"
      ; "    jmp tx_crc"
      ]
    ; List.concat_map
        [ "tx", "tx_crc"; "crc", "crc_done" ]
        ~f:(fun (name, next) ->
          [ [%string "%{name}_bit:"]
          ; [%string "    jmp stuff, %{name}_stuff"]
          ; "    wait t+"
          ; "    out x, 1"
          ; [%string "    jmp x--, %{name}_keep"]
          ; "    mov pins, !pins"
          ; [%string "%{name}_keep:"]
          ; [%string "    jmp y--, %{name}_bit"]
          ; [%string "    jmp %{next}"]
          ; [%string "%{name}_stuff:"]
          ; "    wait t+"
          ; "    nop [2]"
          ; "    mov pins, !pins"
          ; "    stuff_reset"
          ; [%string "    jmp %{name}_bit"]
          ])
    ; [ "tx_crc:"
      ; "    in crc, 16"
      ; "    mov osr, !isr"
      ; "    mov isr, null"
      ; "    set y, 15"
      ; "    jmp crc_bit"
      ; "crc_done:"
      ; "    jmp stuff, last_stuff"
      ; "    jmp eop_tx"
      ; "last_stuff:"
      ; "    wait t+"
      ; "    nop [2]"
      ; "    mov pins, !pins"
      ; "    jmp eop_tx"
      ]
    ]
  |> String.concat ~sep:"\n"
;;
