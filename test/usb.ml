open! Core
open Protocol_emulator
open Protocol_models

let scratch_pin = 5
let dp_pin = 6
let dm_pin = 7

let config =
  { Program_config.default with
    in_base = scratch_pin
  ; out_base = scratch_pin
  ; out_count = 3
  ; set_base = dp_pin
  ; set_count = 2
  ; jmp_pin = scratch_pin
  ; out_shift = Right
  ; stuff_threshold = 6
  ; stuff_level = true
  }
;;

(* USB low speed transmitter. The host sends the bit period, then per packet SYNC, PID,
   data length less one and the data; the core adds CRC-16, bit stuffing and EOP. Each
   data bit goes out on a scratch pin first so the CRC sees it and [jmp pin] reads it
   back. Every toggle lands four cycles after its deadline on either path. *)
let tx =
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
      ~config
      ~period:32]
;;

(* USB low speed receiver. The host sends the bit period; the half period is an immediate
   so the analyser can follow it. Sampling starts half a bit after the first K of SYNC.
   Bits go through [in] one at a time so the CRC sees them; after the EOP the CRC register
   follows as one more word for the host to check. Stuffed zeros are dropped. *)
let rx ~half_period =
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

let rx_dm_pin = 3
let rx_dp_pin = 4

let rx_config =
  { Program_config.default with
    in_base = rx_dm_pin
  ; in_count = 2
  ; capture_pin = rx_dp_pin
  ; capture_rising = true
  ; in_shift = Right
  ; autopush = true
  ; push_threshold = 8
  ; stuff_threshold = 6
  ; stuff_level = true
  }
;;

let device_dp_pin = 12
let device_dm_pin = 13
let device_flag_pin = 14

let device_config =
  { Program_config.default with
    in_base = device_dp_pin
  ; in_count = 2
  ; out_base = device_dp_pin
  ; out_count = 2
  ; set_base = device_dp_pin
  ; set_count = 3
  ; jmp_pin = device_flag_pin
  ; capture_pin = device_dp_pin
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
let device ~address ~half_period =
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
      ; [%string "    wait 1 pin %{device_dp_pin#Int}"]
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
      ; [%string "    wait 1 pin %{device_dp_pin#Int}"]
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

let bit_period = 32
let ack = 0xd2
let nak = 0x5a
let data0 = 0xc3
let data1 = 0x4b
let max_packet = 8

module Request = struct
  type t =
    { request_type : int
    ; request : int
    ; value : int
    ; index : int
    ; length : int
    }

  let bytes t =
    [ t.request_type
    ; t.request
    ; t.value land 0xff
    ; t.value lsr 8
    ; t.index land 0xff
    ; t.index lsr 8
    ; t.length land 0xff
    ; t.length lsr 8
    ]
  ;;

  let of_bytes = function
    | [ request_type; request; v0; v1; i0; i1; l0; l1 ] ->
      { request_type
      ; request
      ; value = v0 lor (v1 lsl 8)
      ; index = i0 lor (i1 lsl 8)
      ; length = l0 lor (l1 lsl 8)
      }
    | bytes -> raise_s [%message "a SETUP carries eight bytes" (bytes : int list)]
  ;;

  let get_descriptor ?(interface = false) ~kind ~length () =
    { request_type = (if interface then 0x81 else 0x80)
    ; request = 6
    ; value = kind lsl 8
    ; index = 0
    ; length
    }
  ;;

  let set_address address =
    { request_type = 0; request = 5; value = address; index = 0; length = 0 }
  ;;

  let set_configuration value =
    { request_type = 0; request = 9; value; index = 0; length = 0 }
  ;;
end

(* The demo board (RP2040) side. [latency] models its slowness; the core covers with NAKs. *)
module Board = struct
  type parse =
    | Tag
    | Words of
        { tag : int
        ; left : int
        ; words : int list
        }

  type t =
    { descriptors : (int * int list) list
    ; latency : int
    ; mutable parse : parse
    ; mutable chunks : int list list
    ; mutable toggle : int
    ; mutable report_toggle : int
    ; mutable due : (int * int list) list
    ; mutable new_address : int option
    ; mutable reload : int option
    ; mutable report : int list option
    ; mutable dropped : bool
    }

  let create ~descriptors ~latency =
    { descriptors
    ; latency
    ; parse = Tag
    ; chunks = []
    ; toggle = data1
    ; report_toggle = data0
    ; due = []
    ; new_address = None
    ; reload = None
    ; report = None
    ; dropped = false
    }
  ;;

  let reply ~endpoint ~pid payload =
    let rec words = function
      | [] -> []
      | [ a ] -> [ a ]
      | a :: b :: rest -> (a lor (b lsl 8)) :: words rest
    in
    let data = words payload in
    (endpoint lor (pid lsl 8))
    :: (8 * List.length payload lor (List.length data lsl 8))
    :: data
  ;;

  let queue t ~endpoint ~pid payload =
    t.due <- t.due @ [ t.latency, reply ~endpoint ~pid payload ]
  ;;

  let next_chunk t =
    match t.chunks with
    | [] -> ()
    | chunk :: rest ->
      t.chunks <- rest;
      queue t ~endpoint:0 ~pid:t.toggle chunk;
      t.toggle <- (if t.toggle = data1 then data0 else data1)
  ;;

  let setup t (r : Request.t) =
    t.toggle <- data1;
    match r.request with
    | 6 ->
      let descriptor =
        List.Assoc.find t.descriptors (r.value lsr 8) ~equal:Int.equal
        |> Option.value ~default:[]
      in
      let data = List.take descriptor r.length in
      let chunks = List.chunks_of data ~length:max_packet in
      (* a short transfer ending on a full packet ends with an empty one *)
      let short = List.length data < r.length && List.length data % max_packet = 0 in
      t.chunks <- (if short then chunks @ [ [] ] else chunks);
      next_chunk t
    | 5 ->
      t.new_address <- Some r.value;
      t.chunks <- [ [] ];
      next_chunk t
    | _ ->
      t.chunks <- [ [] ];
      next_chunk t
  ;;

  (* the first bit received is the top bit of a word *)
  let bytes_of_word w =
    let reverse byte =
      List.init 8 ~f:(fun i -> ((byte lsr i) land 1) lsl (7 - i))
      |> List.sum (module Int) ~f:Fn.id
    in
    [ reverse (w lsr 8); reverse (w land 0xff) ]
  ;;

  let word t w =
    match t.parse with
    | Tag ->
      (match w with
       | 1 -> t.parse <- Words { tag = 1; left = 6; words = [] }
       | 2 -> t.parse <- Words { tag = 2; left = 2; words = [] }
       | 3 ->
         if not (List.is_empty t.chunks)
         then next_chunk t
         else if Option.is_some t.report
                 && (not t.dropped)
                 && Option.is_none t.new_address
         then (
           (* the report went out *)
           t.report <- None;
           t.report_toggle <- (if t.report_toggle = data0 then data1 else data0))
         else (
           t.reload <- t.new_address;
           t.new_address <- None)
       | 4 -> t.dropped <- true
       | tag -> raise_s [%message "unknown tag" (tag : int)])
    | Words { tag; left; words } ->
      let words = w :: words in
      if left > 1
      then t.parse <- Words { tag; left = left - 1; words }
      else (
        t.parse <- Tag;
        if tag = 1
        then (
          let bytes = List.concat_map (List.rev words) ~f:bytes_of_word in
          setup t (Request.of_bytes (List.take bytes 8))))
  ;;

  let reset t =
    t.parse <- Tag;
    t.chunks <- [];
    t.toggle <- data1;
    t.report_toggle <- data0;
    t.due <- [];
    t.new_address <- None;
    t.reload <- None;
    t.report <- None;
    t.dropped <- false
  ;;

  let send_report t payload = queue t ~endpoint:1 ~pid:t.report_toggle payload

  let report t payload =
    t.report <- Some payload;
    send_report t payload
  ;;

  (* a report the core had to drop goes back in once the control transfer is through *)
  let requeue t =
    match t.report with
    | Some payload when t.dropped && List.is_empty t.chunks && List.is_empty t.due ->
      t.dropped <- false;
      send_report t payload
    | _ -> ()
  ;;
end

let reply = Board.reply

type t =
  { mutable machine : Machine.t
  ; mutable sniffer : Usb_ls.Sniffer.t
  ; mutable ends : int
  ; mutable se0 : bool
  ; mutable se0_cycles : int
  ; reset_cycles : int
  ; mutable address_loaded : int
  ; mutable cycles : (int * int option) list
  ; mutable loads : (int * (int * int option) list) list
  ; mutable address : int
  ; mutable naks : int
  ; board : Board.t
  }

(* the program's first instruction pulls the bit period, behind whatever is [queued] *)
let load ~queued ~address =
  let machine =
    Machine.create
      ~config:device_config
      ~program:(Firmware.assemble (device ~address ~half_period:(bit_period / 2)))
    |> ok_exn
  in
  List.fold (queued @ [ bit_period ]) ~init:machine ~f:(fun machine word ->
    Machine.write_tx machine word |> ok_exn)
;;

(* two and a half milliseconds at 48 MHz *)
let reset_cycles = 120_000
let faults t = t.machine.fault
let naks t = t.naks

(* Stop, flush, program, start. A start leaves the fifos alone, so a reply the flush left
   behind would reach the new program first. Keeps one list of cycles per load. *)
let reload t ~address =
  let halted = Machine.flush (Machine.stop t.machine) in
  t.loads <- (t.address_loaded, List.rev t.cycles) :: t.loads;
  t.cycles <- [];
  t.address_loaded <- address;
  t.machine <- load ~queued:halted.tx_fifo ~address
;;

let recording t = List.rev ((t.address_loaded, List.rev t.cycles) :: t.loads)

(* one clock of host, board and sniffer *)
let cycle t (line : Usb_ls.Line.t) =
  let dp, dm =
    match line with
    | J -> 0, 1
    | K -> 1, 0
    | Se0 -> 0, 0
  in
  let inputs = (dp lsl device_dp_pin) lor (dm lsl device_dm_pin) in
  let before = t.machine in
  t.machine <- Machine.step t.machine ~inputs;
  if not ([%equal: Machine.Fault.t] t.machine.fault Machine.Fault.none)
  then
    raise_s
      [%message
        "the core faulted"
          (t.machine.fault : Machine.Fault.t)
          ~pc:(before.pc : int)
          ~phase:(before.now - before.t : int)
          (before.x : int)
          (before.y : int)];
  (match Machine.read_rx t.machine with
   | Some (word, machine) ->
     t.machine <- machine;
     Board.word t.board word
   | None -> ());
  (* at most one word a cycle, as over SPI, whole replies only *)
  let written =
    match t.board.due with
    | (0, []) :: rest ->
      t.board.due <- rest;
      None
    | (0, word :: words) :: rest
      when List.length t.machine.tx_fifo + 1 + List.length words <= Machine.fifo_depth ->
      t.machine <- Machine.write_tx t.machine word |> ok_exn;
      t.board.due <- (0, words) :: rest;
      Some word
    | (0, _) :: _ -> None
    | (n, words) :: rest ->
      t.board.due <- (n - 1, words) :: rest;
      None
    | [] ->
      Board.requeue t.board;
      None
  in
  t.cycles <- (inputs, written) :: t.cycles;
  let pin n level =
    if (t.machine.pin_dir lsr n) land 1 = 1
    then (t.machine.pin_out lsr n) land 1
    else level
  in
  let dp = pin device_dp_pin dp in
  let dm = pin device_dm_pin dm in
  (* a packet is over when the line comes back from SE0 *)
  let se0 = dp = 0 && dm = 0 in
  if t.se0 && not se0
  then (
    t.ends <- t.ends + 1;
    (* an SE0 of 2.5 ms is a bus reset: back to address 0, nothing pending *)
    if t.se0_cycles >= t.reset_cycles
    then (
      reload t ~address:0;
      Board.reset t.board));
  t.se0_cycles <- (if se0 then t.se0_cycles + 1 else 0);
  t.se0 <- se0;
  t.sniffer <- Usb_ls.Sniffer.step t.sniffer ~dp ~dm
;;

let bits t line ~count =
  Fn.apply_n_times ~n:(count * bit_period) (fun () -> cycle t line) ()
;;

let create ?(reset_cycles = reset_cycles) ~descriptors ~latency () =
  let t =
    { machine = load ~queued:[] ~address:0
    ; sniffer = Usb_ls.Sniffer.create ~bit_period
    ; ends = 0
    ; se0 = false
    ; se0_cycles = 0
    ; reset_cycles
    ; address_loaded = 0
    ; cycles = []
    ; loads = []
    ; address = 0
    ; naks = 0
    ; board = Board.create ~descriptors ~latency
    }
  in
  (* settle time after attach; the core needs a few cycles *)
  bits t J ~count:20;
  t
;;

let send t packet = List.iter (Usb_ls.encode packet) ~f:(fun line -> bits t line ~count:1)

(* bus released until the device ends a packet; times out after the longest packet, not
   the standard's eighteen bit times *)
let listen t =
  let ends = t.ends in
  let rec wait left =
    if t.ends > ends
    then (
      bits t J ~count:3;
      List.last (Usb_ls.Sniffer.packets t.sniffer))
    else if left = 0
    then None
    else (
      bits t J ~count:1;
      wait (left - 1))
  in
  wait 160
;;

let token ~address ~pid ~endpoint =
  let bits_ =
    List.init 11 ~f:(fun i ->
      if i < 7 then (address lsr i) land 1 else (endpoint lsr (i - 7)) land 1)
  in
  [ pid
  ; address lor ((endpoint land 1) lsl 7)
  ; (endpoint lsr 1) lor (Usb_ls.crc5 bits_ lsl 3)
  ]
;;

let data ~pid payload =
  let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes payload) in
  (pid :: payload) @ [ crc land 0xff; crc lsr 8 ]
;;

let expect_ack t what =
  match listen t with
  | Some [ pid ] when pid = ack -> ()
  | other -> raise_s [%message "no ACK" what (other : int list option)]
;;

(* an IN, again after every NAK; the payload once the CRC has been checked *)
let rec in_ t ~endpoint ~tries =
  send t (token ~address:t.address ~pid:0x69 ~endpoint);
  match listen t with
  | Some [ pid ] when pid = nak ->
    t.naks <- t.naks + 1;
    if tries = 0
    then None
    else (
      bits t J ~count:200;
      in_ t ~endpoint ~tries:(tries - 1))
  | Some (pid :: rest) when pid = data0 || pid = data1 ->
    let payload = List.take rest (List.length rest - 2) in
    if not ([%equal: int list] (data ~pid payload) (pid :: rest))
    then raise_s [%message "bad CRC from the device" (rest : int list)];
    send t [ ack ];
    bits t J ~count:4;
    Some payload
  | other -> raise_s [%message "no answer to IN" (other : int list option)]
;;

let setup t (request : Request.t) =
  send t (token ~address:t.address ~pid:0x2d ~endpoint:0);
  bits t J ~count:3;
  send t (data ~pid:data0 (Request.bytes request));
  expect_ack t "SETUP";
  bits t J ~count:4
;;

let control_in t request =
  setup t request;
  let rec stage acc =
    match in_ t ~endpoint:0 ~tries:50 with
    | None -> raise_s [%message "the device never answered"]
    | Some payload ->
      let acc = acc @ payload in
      if List.length payload < max_packet || List.length acc >= request.length
      then acc
      else stage acc
  in
  let bytes = stage [] in
  send t (token ~address:t.address ~pid:0xe1 ~endpoint:0);
  bits t J ~count:3;
  send t (data ~pid:data1 []);
  expect_ack t "status";
  bits t J ~count:4;
  bytes
;;

let control_out t request =
  setup t request;
  (match in_ t ~endpoint:0 ~tries:50 with
   | Some [] -> ()
   | other -> raise_s [%message "no status packet" (other : int list option)]);
  (* reload with the new address once the status stage is acknowledged *)
  bits t J ~count:((t.board.latency / bit_period) + 10);
  match t.board.reload with
  | Some address ->
    t.board.reload <- None;
    reload t ~address;
    t.address <- address;
    bits t J ~count:20
  | None -> ()
;;

(* a host resets the bus for ten milliseconds or more; three are enough here *)
let reset t =
  Fn.apply_n_times ~n:(t.reset_cycles + (t.reset_cycles / 5)) (fun () -> cycle t Se0) ();
  t.address <- 0;
  bits t J ~count:40
;;

let report t payload = Board.report t.board payload
let interrupt_in t ~endpoint = in_ t ~endpoint ~tries:0

open Pin_trace
module Reg = Host_port.Reg

(* A low speed host on D+ and D-: each group of packets at its cycle, three bit times
   apart, and an ACK three bit times after each data packet the device sends. *)
let low_speed_host groups () =
  let open Protocol_models.Usb_ls in
  let bit_period = bit_period in
  let dp = device_dp_pin
  and dm = device_dm_pin in
  let now = ref 0
  and pending = ref groups
  and lines = ref []
  and held = ref 0
  and line = ref Line.J
  and sniffer = ref (Sniffer.create ~bit_period)
  and seen = ref 0
  and device = ref false in
  let levels : Line.t -> int * int = function
    | J -> 0, 1
    | K -> 1, 0
    | Se0 -> 0, 0
  in
  let queue packets =
    List.map packets ~f:encode |> List.intersperse ~sep:[ Line.J; J; J ] |> List.concat
  in
  { Peer.inputs =
      (fun () ->
        let p, m = levels !line in
        (p lsl dp) lor (m lsl dm))
  ; step =
      (fun ~pin_out ~pin_dir ->
        let host_dp, host_dm = levels !line in
        let pin n level = if Peer.bit pin_dir n = 1 then Peer.bit pin_out n else level in
        if Peer.bit pin_dir dp = 1 then device := true;
        sniffer := Sniffer.step !sniffer ~dp:(pin dp host_dp) ~dm:(pin dm host_dm);
        let packets = Sniffer.packets !sniffer in
        if List.length packets > !seen
        then (
          seen := List.length packets;
          (match List.last packets with
           | Some (pid :: _) when !device && (pid = data0 || pid = data1) ->
             pending
             := List.sort
                  ((!now + (3 * bit_period), [ [ ack ] ]) :: !pending)
                  ~compare:(Comparable.lift Int.compare ~f:fst)
           | _ -> ());
          device := false);
        incr now;
        if !held > 1
        then decr held
        else (
          (match !pending with
           | (cycle, packets) :: rest when List.is_empty !lines && cycle <= !now ->
             pending := rest;
             lines := queue packets
           | _ -> ());
          match !lines with
          | next :: rest ->
            line := next;
            lines := rest;
            held := bit_period
          | [] ->
            line := J;
            held := 0))
  }
;;

(* The first request of an enumeration, GET_DESCRIPTOR for eight bytes of the device
   descriptor, then a mouse report on the interrupt endpoint, a pixel up and left, whose
   0xff bytes need stuff bits, and an IN with nothing queued, which gets a NAK. *)
let scenario =
  let bit_period = bit_period in
  let address = 0 in
  let at bits = 120_000 + (bits * bit_period) in
  let setup = 0x2d
  and in_ = 0x69
  and out = 0xe1 in
  let token pid endpoint = token ~address ~pid ~endpoint in
  let get_descriptor = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x08; 0x00 ] in
  let descriptor = [ 0x12; 0x01; 0x10; 0x01; 0x00; 0x00; 0x00; 0x08 ] in
  let report = [ 0x02; 0x00; 0xff; 0xff ] in
  let packet name endpoint = sprintf "%s ADDR %d EP %d" name address endpoint in
  let data_packet name payload =
    sprintf "%s [ %s]" name (String.concat (List.map payload ~f:(sprintf "%02X ")))
  in
  let hex bytes = String.concat (List.map bytes ~f:(sprintf " %02X")) in
  let host =
    [ at 0, [ token setup 0; data ~pid:data0 get_descriptor ]
    ; at 300, [ token in_ 0 ]
    ; at 600, [ token out 0; data ~pid:data1 [] ]
    ; at 900, [ token in_ 1 ]
    ; at 1200, [ token in_ 1 ]
    ]
  in
  { Scenario.name = "usb"
  ; peer = low_speed_host host
  ; script =
      Scenario.load
        ~config:device_config
        ~program:(Firmware.assemble (device ~address ~half_period:(bit_period / 2)))
      @ [ Write (Reg.tx, bit_period :: reply ~endpoint:0 ~pid:data1 descriptor)
        ; Scenario.start
        ; Until (at 280)
        ; Read (Reg.rx, 7)
        ; Until (at 580)
        ; Read (Reg.rx, 1)
        ; Until (at 880)
        ; Read (Reg.rx, 3)
        ; Write (Reg.tx, reply ~endpoint:1 ~pid:data0 report)
        ; Until (at 1180)
        ; Read (Reg.rx, 1)
        ; Until (at 1400)
        ]
  ; sigrok =
      Some
        { clock_hz = 48_000_000
        ; decoders =
            [ String.concat
                ~sep:","
                [ Sigrok.decoder
                    "usb_signalling"
                    ~pins:[ "dp", device_dp_pin; "dm", device_dm_pin ]
                    ~options:[ "signalling", "low-speed" ]
                ; Sigrok.decoder "usb_packet" ~options:[ "signalling", "low-speed" ]
                ; Sigrok.decoder "usb_request"
                ]
            ]
        ; expect =
            [ ( (* every packet class, so one more of any kind is a difference *)
                [ "out"
                ; "in"
                ; "sof"
                ; "setup"
                ; "data0"
                ; "data1"
                ; "data2"
                ; "mdata"
                ; "ack"
                ; "nak"
                ; "stall"
                ; "nyet"
                ; "pre"
                ; "err"
                ; "split"
                ; "ping"
                ; "reserved"
                ; "invalid"
                ]
                |> List.map ~f:(( ^ ) "packet-")
                |> String.concat ~sep:":"
                |> ( ^ ) "usb_packet="
              , Sigrok.lines
                  "usb_packet"
                  [ packet "SETUP" 0
                  ; data_packet "DATA0" get_descriptor
                  ; "ACK"
                  ; packet "IN" 0
                  ; data_packet "DATA1" descriptor
                  ; "ACK"
                  ; packet "OUT" 0
                  ; data_packet "DATA1" []
                  ; "ACK"
                  ; packet "IN" 1
                  ; data_packet "DATA0" report
                  ; "ACK"
                  ; packet "IN" 1
                  ; "NAK"
                  ] )
            ; ( "usb_request"
              , Sigrok.lines
                  "usb_request"
                  [ sprintf
                      "SETUP in: [%s ][%s ] : ACK"
                      (hex get_descriptor)
                      (hex descriptor)
                  ; sprintf "BULK in: [%s ] : ACK" (hex report)
                  ] )
            ]
        ; joins_after = None
        ; rejected = None
        ; (* a bit time of the descriptor the device sends inverted on both lines, 46
             cycles past a K to J, edges 152 of D+ and 156 of D- *)
          teeth =
            [ [ Flip { pin = device_dp_pin; edge = 152; after = 46; cycles = 32 }
              ; Flip { pin = device_dm_pin; edge = 156; after = 46; cycles = 32 }
              ]
            ; (* the report's second stuff bit a bit time late, edges 349 of D+ and 357 of
                 D-: seven ones in a row *)
              [ Shift { pin = device_dp_pin; edge = 349; cycles = 32 }
              ; Shift { pin = device_dm_pin; edge = 357; cycles = 32 }
              ]
            ]
        }
  }
;;

let protocol =
  { Protocol.name = "usb"
  ; certified =
      [ Certified.plain ~period:32 "usb_tx" (Timed_program.source tx) config
      ; Certified.receiver ~period:32 "usb_rx" (rx ~half_period:16) rx_config
      ; Certified.receiver
          ~period:32
          "usb_device"
          (device ~address:0 ~half_period:16)
          device_config
      ]
  ; time_triggered = []
  ; bench = []
  ; loaded_from_hex = []
  ; limits = []
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "usb_tx"
        , "certified at 32 cycles a bit only, where 9 edges come in 256: the fifo holds 8"
        )
      ; "usb_rx", "a receiver: nothing on the chip sends to it"
      ; "usb_device", "a device: a USB host has to talk first"
      ]
  ; scenarios = []
  ; decoded = [ scenario ]
  }
;;
