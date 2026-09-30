open! Core
open Protocol_emulator

let pin = 5
let cycle_ns = 20
let standard_tick = 3_000 / cycle_ns
let shortest_tick = 21

(* [t] is the next fall on entry to [pulse], and [x] the nibble. Every loop that moves [t]
   waits on each pass, so [t] is at most seven ticks ahead whatever the tick. *)
let firmware =
  {|
    wait tx
    pull
    mov p, osr               ; the tick
    mov t, now
    set pins, 1              ; idle high
    wait tx
    mov t, now
    add t, p
frame:
    pull                     ; status and data 1 to 3
    wait t
    set pins, 0              ; sync: 5 ticks low, 51 high
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    wait t
    set pins, 1
    set x, 16
sync:
    add t, p
    add t, p
    wait t+
    jmp x--, sync
    out x, 4                 ; status, not in the CRC
    crc_init
    set y, 7                 ; pulses after this one
pulse:
    wait t
    set pins, 0
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    wait t
    set pins, 1
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
length:
    wait t+
    jmp x--, length          ; the next fall 12 + x ticks after this one
    jmp y--, next
    wait t
    set pins, 0              ; the CRC ends, the pause begins
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    wait t
    set pins, 1
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p                 ; 12 ticks of pause, more if the host is late
    jmp tx, frame
    wait t                   ; late: the 12 ticks out first
    wait tx
    mov t, now
    add t, p
    jmp frame
next:
    set x, 0
    jmp x!=y, data
    in crc, 4                ; the CRC nibble, through the osr to bound x
    mov osr, isr
    out x, 4
    jmp pulse
data:
    set x, 3
    jmp x!=y, extract
    pull                     ; data 4 to 6
extract:
    mov isr, osr
    out x, 4
    mov osr, isr             ; the same nibble again, a bit at a time through the CRC
    out null, 1
    out null, 1
    out null, 1
    out null, 1
    jmp pulse
|}
;;

let config =
  { Program_config.default with
    out_base = pin
  ; set_base = pin
  ; out_shift = Left
  ; in_shift = Right
  ; crc_width = 4
  ; crc_poly = 0xd
  ; crc_init = 3
  ; crc_reflect = false
  }
;;

(* x^4 + x^3 + x^2 + 1 from seed 0101. The table method takes each nibble a nibble late,
   so the core's shift register starts from the seed moved on by one, table.(5), 3. *)
let crc4 nibbles =
  let table = [| 0; 13; 7; 10; 14; 3; 9; 4; 1; 12; 6; 11; 15; 2; 8; 5 |] in
  table.(List.fold nibbles ~init:5 ~f:(fun crc nibble -> table.(crc) lxor nibble))
;;

module Frame = struct
  type t =
    { status : int
    ; data : int list
    }
  [@@deriving sexp_of, compare, equal]
end

let words ({ status; data } : Frame.t) =
  match data with
  | [ d1; d2; d3; d4; d5; d6 ] ->
    let word = List.fold ~init:0 ~f:(fun w n -> (w lsl 4) lor n) in
    [ word [ status; d1; d2; d3 ]; word [ d4; d5; d6; 0 ] ]
  | _ -> raise_s [%message "BUG: six data nibbles" (data : int list)]
;;

let decode ~cycle_ns levels =
  let open Or_error.Let_syntax in
  let levels = Array.of_list levels in
  let edges ~falling =
    List.range 1 (Array.length levels)
    |> List.filter ~f:(fun i ->
      Bool.equal levels.(i - 1) falling && Bool.equal levels.(i) (not falling))
  in
  let falls = edges ~falling:true in
  let rises = edges ~falling:false in
  (* each pulse as its length and its low time, in cycles *)
  let pulses =
    List.zip_exn (List.take falls (List.length falls - 1)) (List.drop falls 1)
    |> List.map ~f:(fun (fall, next) ->
      let rise = List.find_exn rises ~f:(fun r -> r > fall) in
      next - fall, rise - fall)
  in
  let ticks ~sync cycles =
    let n = ((56 * cycles) + (sync / 2)) / sync in
    if abs ((56 * cycles) - (n * sync)) * 8 <= sync
    then return n
    else Or_error.error_s [%message "not whole ticks" (cycles : int) (sync : int)]
  in
  (* J2716 5.2.1: every pulse, the sync and the pause too, is low 4 ticks or more *)
  let low_enough ~sync ~name low =
    if 56 * low >= 4 * sync
    then return ()
    else Or_error.error_s [%message "low under 4 ticks" name (low : int) (sync : int)]
  in
  let rec frames pulses ~previous_sync decoded measured =
    match pulses with
    | [] -> return (List.rev decoded, measured)
    | (sync, sync_low) :: rest ->
      let%bind () = low_enough ~sync ~name:"sync" sync_low in
      let%bind () =
        match previous_sync with
        | Some previous when abs (sync - previous) * 64 > previous ->
          Or_error.error_s [%message "sync drifts" (sync : int) (previous : int)]
        | _ -> return ()
      in
      let measured = Measured.add measured ~name:"sync" ~ns:(sync * cycle_ns) in
      let nibbles, rest = List.take rest 8, List.drop rest 8 in
      if List.length nibbles < 8
      then return (List.rev decoded, measured)
      else (
        let%bind nibbles, measured =
          List.fold_result
            nibbles
            ~init:([], measured)
            ~f:(fun (nibbles, measured) (cycles, low) ->
              let%bind n = ticks ~sync cycles in
              let%bind () =
                if n >= 12 && n <= 27
                then return ()
                else Or_error.error_s [%message "no nibble" (n : int)]
              in
              let%map () = low_enough ~sync ~name:"nibble" low in
              (n - 12) :: nibbles, Measured.add measured ~name:"low" ~ns:(low * cycle_ns))
        in
        let status, data, crc =
          match List.rev nibbles with
          | status :: rest ->
            let data, crc = List.take rest 6, List.drop rest 6 in
            status, data, List.hd_exn crc
          | [] -> raise_s [%message "BUG: eight nibbles"]
        in
        let%bind () =
          if crc4 data = crc
          then return ()
          else Or_error.error_s [%message "CRC" (crc : int) ~expected:(crc4 data : int)]
        in
        let decoded = { Frame.status; data } :: decoded in
        match rest with
        | [] -> return (List.rev decoded, measured)
        | (pause, pause_low) :: rest ->
          let%bind () =
            if 56 * pause >= 12 * sync && 56 * pause <= 768 * sync
            then return ()
            else Or_error.error_s [%message "no pause" (pause : int) (sync : int)]
          in
          let%bind () = low_enough ~sync ~name:"pause" pause_low in
          frames
            rest
            ~previous_sync:(Some sync)
            decoded
            (Measured.add measured ~name:"pause" ~ns:(pause * cycle_ns)))
  in
  frames pulses ~previous_sync:None [] Measured.empty
;;
