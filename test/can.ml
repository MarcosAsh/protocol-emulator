open! Core
open Protocol_emulator

let tx_pin = 6
let period = 96
let shortest_period = 15

(* The level before each bit is read back from the pin: a change starts a run, the same
   level counts it down in y, and y running out is five equal bits. A stuff bit is the
   complement of the pin and starts a run. SOF is not shifted through the CRC, but a
   dominant bit from 0 leaves it at 0. *)
let firmware =
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
    set x, 11                ; ACK slot and delimiter, EOF, intermission
tail:
    wait t+
    jmp x--, tail
    jmp frame
|}
;;

let config =
  { Program_config.default with
    in_base = tx_pin
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

module Frame = struct
  type t =
    { id : int
    ; rtr : bool
    ; dlc : int
    ; data : int list
    }
  [@@deriving sexp_of, compare, equal]

  let data ~id data = { id; rtr = false; dlc = List.length data; data }
  let remote ~id ~dlc = { id; rtr = true; dlc; data = [] }
end

let msb_first value ~width =
  List.init width ~f:(fun i -> (value lsr (width - 1 - i)) land 1 = 1)
;;

let crc15 bits =
  List.fold bits ~init:0 ~f:(fun crc bit ->
    Crc.step ~width:15 ~poly:0x4599 ~reflect:false crc ~bit:(Bool.to_int bit))
;;

(* ID, RTR, IDE, r0, DLC and data: what the host sends *)
let fields (f : Frame.t) =
  if f.id < 0 || f.id >= 1 lsl 11 || f.dlc < 0 || f.dlc > 15
  then raise_s [%message "BUG: not a CAN 2.0A frame" (f : Frame.t)];
  msb_first f.id ~width:11
  @ [ f.rtr; false; false ]
  @ msb_first f.dlc ~width:4
  @ List.concat_map f.data ~f:(msb_first ~width:8)
;;

let stuff bits =
  List.fold bits ~init:([], None, 0) ~f:(fun (sent, last, run) bit ->
    let run = if Option.equal Bool.equal last (Some bit) then run + 1 else 1 in
    if run = 5
    then not bit :: bit :: sent, Some (not bit), 1
    else bit :: sent, Some bit, run)
  |> fun (sent, _, _) -> List.rev sent
;;

let line f =
  let unstuffed = false :: fields f in
  stuff (unstuffed @ msb_first (crc15 unstuffed) ~width:15)
  @ List.init 13 ~f:(fun _ -> true)
;;

let words f =
  let fields = fields f in
  (List.length fields - 1)
  :: (List.chunks_of fields ~length:16
      |> List.map ~f:(fun chunk ->
        List.foldi chunk ~init:0 ~f:(fun i word bit ->
          word lor (Bool.to_int bit lsl (15 - i)))))
;;

(* A cursor over the line that removes stuff bits while [stuffed] and fails on one that
   does not change the level. *)
let decode levels =
  let open Or_error.Let_syntax in
  let rest = ref levels
  and last = ref None
  and run = ref 0
  and index = ref 0 in
  let raw () =
    match !rest with
    | [] -> Or_error.error_s [%message "the line ends" (!index : int)]
    | bit :: tail ->
      rest := tail;
      incr index;
      Ok bit
  in
  let rec stuffed () =
    let%bind bit = raw () in
    if !run = 5
    then
      if Option.equal Bool.equal !last (Some bit)
      then Or_error.error_s [%message "stuff error" ~bit:(!index - 1 : int)]
      else (
        last := Some bit;
        run := 1;
        stuffed ())
    else (
      run := if Option.equal Bool.equal !last (Some bit) then !run + 1 else 1;
      last := Some bit;
      return bit)
  in
  let rec take n ~f =
    if n = 0
    then return []
    else (
      let%bind bit = f () in
      let%map bits = take (n - 1) ~f in
      bit :: bits)
  in
  let value bits = List.fold bits ~init:0 ~f:(fun v b -> (v lsl 1) lor Bool.to_int b) in
  let%bind sof = stuffed () in
  let%bind () = if sof then Or_error.error_s [%message "no SOF"] else return () in
  let%bind id = take 11 ~f:stuffed in
  let%bind rtr = stuffed () in
  let%bind ide_r0 = take 2 ~f:stuffed in
  let%bind () =
    if List.exists ide_r0 ~f:Fn.id
    then Or_error.error_s [%message "IDE or r0 recessive"]
    else return ()
  in
  let%bind dlc = take 4 ~f:stuffed in
  let dlc = value dlc in
  let bytes = if rtr then 0 else Int.min dlc 8 in
  let%bind data = take (8 * bytes) ~f:stuffed in
  let unstuffed = (false :: id) @ (rtr :: ide_r0) @ msb_first dlc ~width:4 @ data in
  let%bind crc = take 15 ~f:stuffed in
  (* a stuff bit after the CRC's last five, if they were equal *)
  let%bind () =
    if !run = 5
    then (
      let%bind bit = raw () in
      if Option.equal Bool.equal !last (Some bit)
      then Or_error.error_s [%message "stuff error after the CRC"]
      else return ())
    else return ()
  in
  let%bind () =
    if value crc = crc15 unstuffed
    then return ()
    else
      Or_error.error_s
        [%message
          "CRC" ~sent:(value crc : Int.Hex.t) ~expected:(crc15 unstuffed : Int.Hex.t)]
  in
  let%bind tail = take 13 ~f:raw in
  let%bind () =
    if List.for_all tail ~f:Fn.id
    then return ()
    else Or_error.error_s [%message "delimiter, ACK or EOF dominant" (tail : bool list)]
  in
  return
    { Frame.id = value id
    ; rtr
    ; dlc
    ; data = List.chunks_of data ~length:8 |> List.map ~f:value
    }
;;
