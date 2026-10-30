open! Core
open Protocol_emulator
open Protocol_models

let dp_pin = Isa.first_bidir_pin
let dm_pin = dp_pin + 1
let finished_pin = Isa.first_status_pin
let good_pin = Isa.first_status_pin + 1
let receiving_pin = Isa.first_status_pin + 2
let rx_base = 0
let nak_record = 16
let ack_record = 18
let first_record = 20
let turnaround = 17
let none = 1

let config =
  { Program_config.default with
    out_base = dp_pin
  ; out_count = 2
  ; set_base = dp_pin
  ; set_count = 2
  ; in_shift = Left
  ; out_shift = Right
  ; autopull = true
  ; pull_threshold = 16
  ; autopull_data = true
  ; line_code = true
  }
;;

let line_table = Line_code.usb_stuffing

(* the adds that put the reply [turnaround] cycles after [mov t, now] *)
let adds =
  let rec go n = if n <= 7 then [ n ] else 7 :: go (n - 7) in
  go turnaround
;;

let add n = [%string "    add t, %{n#Int}"]

(* [record] sent from the data memory: [seek] to x, the bit count, then the line bits
   through the line table's NRZI at four cycles a bit, SE0 for two bits and J for one *)
let send ~name ~then_ =
  [ [%string "%{name}:"]
  ; "    seek"
  ; add (List.nth_exn adds 0)
  ; add (List.nth_exn adds 1)
  ]
  @ [ "    out x, 16"; "    set pindirs, 3"; add (List.nth_exn adds 2); "    wait t" ]
  @ [ [%string "%{name}_bit:"]
    ; "    out pins, 1 [1]"
    ; [%string "    jmp x--, %{name}_bit"]
    ; "    set pins, 0 [7]"
    ; "    set pins, 1 [3]"
    ; "    set pindirs, 0"
    ; [%string "    jmp %{then_}"]
    ]
;;

(* A reply's record from x: its data bits plus one, 0 for a handshake, SYNC and the PID,
   then the data. Every bit is four cycles: the PID's last bit decides whether data
   follows, [crc_init] lands after it and [crc_send] after the data, so the CRC unit sends
   the CRC-16; the line stuffs, and after the CRC's last bit [stuff_reset] has the outs
   pay what it owes. *)
let send_data ~name ~then_ =
  let handshake = name ^ "_handshake" in
  let packet = name ^ "_packet" in
  let head = name ^ "_head" in
  let pid = name ^ "_pid" in
  let empty = name ^ "_empty" in
  let more = name ^ "_more" in
  let data = name ^ "_data" in
  let crc = name ^ "_crc" in
  let owed = name ^ "_owed" in
  (* SE0 for two bits, as [crc_init] stops the CRC sending and y goes back to [none] *)
  let eop =
    [ "    set pins, 0"
    ; "    crc_init"
    ; [%string "    set y, %{none#Int} [5]"]
    ; "    set pins, 1 [3]"
    ; "    set pindirs, 0"
    ; [%string "    jmp %{then_}"]
    ]
  in
  List.concat
    [ [ [%string "%{name}:"]
      ; "    seek"
      ; add (List.nth_exn adds 0)
      ; add (List.nth_exn adds 1)
      ; "    out y, 16"
      ; "    set pindirs, 3"
      ; "    set x, 13"
      ; add (List.nth_exn adds 2)
      ; [%string "    jmp y--, %{packet}"]
      ; "    wait t"
      ; [%string "%{handshake}:"]
      ; "    out pins, 1 [1]"
      ; [%string "    jmp x--, %{handshake}"]
      ; "    out pins, 1 [3]"
      ; "    out pins, 1 [3]"
      ]
    ; eop
    ; [ [%string "%{packet}:"]
      ; "    wait t"
      ; [%string "%{head}:"]
      ; "    out pins, 1 [1]"
      ; [%string "    jmp x--, %{head}"]
      ; "    out pins, 1"
      ; [%string "    jmp y--, %{pid}"]
      ; "    nop"
      ; "    out pins, 1"
      ; "    crc_init"
      ; "    crc_send"
      ; "    set x, 15"
      ; [%string "%{empty}:"]
      ; "    out pins, 1 [1]"
      ; [%string "    jmp x--, %{empty}"]
      ]
    ; eop
    ; [ [%string "%{pid}:"]
      ; "    nop"
      ; "    out pins, 1"
      ; "    crc_init"
      ; "    set x, 14"
      ; [%string "%{more}:"]
      ; "    nop"
      ; [%string "%{data}:"]
      ; "    out pins, 1"
      ; [%string "    jmp y--, %{more}"]
      ; "    crc_send"
      ; [%string "%{crc}:"]
      ; "    out pins, 1 [1]"
      ; [%string "    jmp x--, %{crc}"]
      ; "    out pins, 1"
      ; "    stuff_reset"
      ; [%string "    jmp stuff, %{owed}"]
      ]
    ; eop
    ; [ [%string "%{owed}:"]; "    out pins, 1 [1]"; [%string "    jmp stuff, %{owed}"] ]
    ; eop
    ]
;;

(* [v] of the PID in x, xored with IN's, its low nibble then its check nibble; falls
   through where both are [v], else to [ignore] *)
let pid_is v ~ignore =
  let subs n =
    let rec go n = if n <= 7 then [ n ] else 7 :: go (n - 7) in
    if n = 0 then [] else List.map (go n) ~f:(fun n -> [%string "    sub x, %{n#Int}"])
  in
  List.concat
    [ [ "    out x, 4" ]
    ; subs v
    ; [ [%string "    jmp x--, %{ignore}"]; "    out x, 4" ]
    ; subs v
    ; [ [%string "    jmp x--, %{ignore}"] ]
    ]
;;

(* Registers: p the IN token word for endpoint 0 at this address, y the pending reply's
   (none is 1, which no token is), x scratch. The receiver lands each packet from rx_base;
   the program waits on receiving then good, anchors t and compares word 0 in one jmp, so
   every reply's SYNC starts [turnaround] cycles after the anchor. A bit is four cycles,
   with no room for [jmp stuff], so the line table's [tx_stuff] stuffs. *)
let device =
  List.concat
    [ [ "    set pins, 1"
      ; "    set pindirs, 0"
      ; "    pull"
      ; "    out p, 16"
      ; [%string "    set y, %{none#Int}"]
      ; "entry:"
      ; "    mov osr, null"
      ; "    out null, 16"
      ; "    mov x, null"
      ; "    seek"
      ; "    mov x, y"
      ; [%string "    sub x, %{none#Int}"]
      ; "    jmp x--, idle"
      ; "    jmp !tx, idle"
      ; "    pull"
      ; "    out y, 16"
      ; "    mov x, y"
      ; "    xor x, p"
      ; "    mov x, ::x"
      ; "    jmp x--, not_ep0"
      ; "    jmp idle"
      ; "not_ep0:"
      ; "    jmp x--, new_address"
      ; "    jmp idle"
      ; "new_address:"
      ; "    mov p, y"
      ; [%string "    set y, %{none#Int}"]
      ; "idle:"
      ; [%string "    wait 1 pin %{receiving_pin#Int}"]
      ; [%string "    wait 1 pin %{good_pin#Int}"]
      ; "    mov t, now"
      ; "    out x, 16"
      ; "    jmp x!=y, other"
      ; "    jmp !tx, nak"
      ; "    pull"
      ; "    out x, 16"
      ]
    ; send_data ~name:"reply" ~then_:"await_ack"
    ; [ "other:"
      ; "    xor x, p"
      ; "    mov x, ::x"
      ; "    jmp x--, not_in_ep0"
      ; "    jmp nak"
      ; "not_in_ep0:"
      ; "    jmp x--, quiet"
      ; "nak:"
      ; [%string "    set x, %{nak_record#Int}"]
      ]
    ; send ~name:"handshake" ~then_:"entry"
    ; [ "await_ack:"
      ; "    mov osr, null"
      ; "    out null, 16"
      ; "    mov x, null"
      ; "    seek"
      ; [%string "    wait 1 pin %{receiving_pin#Int}"]
      ; [%string "    wait 1 pin %{finished_pin#Int}"]
      ; "    nop [1]"
      ; "    out x, 4"
      ; "    sub x, 2"
      ; "    jmp x--, no_ack"
      ; "    jmp !rx, entry"
      ; "    set x, 3"
      ; "    mov isr, x"
      ; "    push"
      ; "    jmp entry"
      ; "no_ack:"
      ; "    jmp !rx, quiet"
      ; "    set x, 4"
      ; "    mov isr, x"
      ; "    push"
      ; "quiet:"
      ; "    mov osr, null"
      ; "    out null, 16"
      ; "    mov x, null"
      ; "    seek"
      ; "    nop"
      ; "    out x, 16"
      ; "    xor x, p"
      ; "    mov osr, x"
      ]
    ; pid_is 4 ~ignore:"not_setup"
    ; [ "    out x, 8"; "    jmp x--, entry"; "    jmp setup_data" ]
    ; [ "not_setup:"
      ; "    mov osr, null"
      ; "    out null, 16"
      ; "    mov x, null"
      ; "    seek"
      ; "    nop"
      ; "    out x, 16"
      ; "    xor x, p"
      ; "    mov osr, x"
      ]
    ; pid_is 8 ~ignore:"entry"
    ; [ "    out x, 8"; "    jmp x--, entry" ]
    ; List.concat_map
        [ "out_data", "out_acked", false; "setup_data", "forward", true ]
        ~f:(fun (name, then_, forwards) ->
          [ [%string "%{name}:"]
          ; "    mov osr, null"
          ; "    out null, 16"
          ; "    mov x, null"
          ; "    seek"
          ; [%string "    jmp !rx, %{name}_full"]
          ; [%string "    wait 1 pin %{receiving_pin#Int}"]
          ; [%string "    wait 1 pin %{good_pin#Int}"]
          ; "    mov t, now"
          ; "    out x, 16"
          ]
          (* a SETUP's PID and first byte go to the host before the ACK, as its echo lands
             over them *)
          @ (if forwards
             then [ "    mov isr, x"; "    push" ]
             else [ "    mov isr, null" ])
          @ [ "    in x, 2"
            ; "    mov x, isr"
            ; "    sub x, 3"
            ; "    jmp x--, quiet"
            ; [%string "    set x, %{ack_record#Int}"]
            ]
          @ send ~name:(name ^ "_ack") ~then_
          @ [ [%string "%{name}_full:"]
            ; [%string "    wait 1 pin %{receiving_pin#Int}"]
            ; [%string "    wait 1 pin %{good_pin#Int}"]
            ; "    mov t, now"
            ; [%string "    set x, %{ack_record#Int}"]
            ; [%string "    jmp %{name}_ack"]
            ])
    ; [ "out_acked:"
      ; "    jmp !rx, entry"
      ; "    set x, 2"
      ; "    mov isr, x"
      ; "    push"
      ; "    jmp entry"
      ; "forward:"
      ; "    mov osr, null"
      ; "    out null, 16"
      ; [%string "    set x, %{rx_base + 1#Int}"]
      ; "    seek"
      ; "    set x, 3"
      ; "forward_word:"
      ; "    jmp !rx, entry"
      ; "    out isr, 16"
      ; "    push"
      ; "    jmp x--, forward_word"
      ; "    jmp entry"
      ]
    ]
  |> String.concat ~sep:"\n"
;;

(* SYNC and the packet's bits, first bit first, a 0 after every six 1s, for a handshake *)
let line_bits packet =
  Usb_ls.bits_of_bytes (0x80 :: packet)
  |> List.folding_map ~init:0 ~f:(fun ones bit ->
    match bit, ones with
    | 1, 5 -> 0, [ 1; 0 ]
    | 1, _ -> ones + 1, [ 1 ]
    | _ -> 0, [ 0 ])
  |> List.concat
;;

let record packet =
  let bits = line_bits packet in
  (List.length bits - 1)
  :: (List.chunks_of bits ~length:16
      |> List.map ~f:(List.foldi ~init:0 ~f:(fun n word bit -> word lor (bit lsl n))))
;;

let data_record = function
  | [] -> raise_s [%message "BUG: a packet needs its PID"]
  | [ pid ] when pid land 3 = 2 -> [ 0; 0x80 lor (pid lsl 8) ]
  | pid :: data ->
    ((8 * List.length data) + 1)
    :: (0x80 lor (pid lsl 8))
    :: (List.chunks_of data ~length:2
        |> List.map
             ~f:(List.foldi ~init:0 ~f:(fun n word byte -> word lor (byte lsl (8 * n)))))
;;

let in_token ~address ~endpoint = 0x69 lor (address lsl 8) lor ((endpoint land 1) lsl 15)

module Layout = struct
  type t =
    { words : int array
    ; addresses : (int list * int) list
    }

  let create packets =
    let words = Array.create ~len:(1 lsl Isa.data_addr_bits) 0 in
    let put at record =
      List.iteri record ~f:(fun n word -> words.(at + n) <- word);
      at + List.length record
    in
    let (_ : int) = put nak_record (record [ 0x5a ]) in
    let (_ : int) = put ack_record (record [ 0xd2 ]) in
    let _, addresses =
      List.fold_map packets ~init:first_record ~f:(fun at packet ->
        put at (data_record packet), (packet, at))
    in
    { words; addresses }
  ;;

  let address t packet = List.Assoc.find_exn t.addresses packet ~equal:[%equal: int list]
end

let certified = Certified.plain ~no_wrap:true ~any_data:true "usb_fs_device" device config

let protocol =
  { Protocol.name = "usb_fs"
  ; certified = [ certified ]
  ; time_triggered = []
  ; bench = []
  ; loaded_from_hex = []
  ; limits = []
  ; unlimited = []
  ; swept = []
  ; not_swept = [ "usb_fs_device", "a device: a USB host has to talk first" ]
  ; scenarios = []
  ; decoded = []
  }
;;
