open! Core
open Protocol_emulator

let data_pin = 12
let clock_pin = 13
let cycle_ns = 20
let standard_quarter = 20_000 / cycle_ns

(* [set] is the clock and [mov pindirs] the data; a direction bit of 1 pulls the line low.
   The frame is put together in isr, shifting right: the byte, then the parity out of the
   CRC, then the stop bit, then five places more so that the start bit is bit 0. *)
let firmware =
  {|
    wait tx
    pull
    mov p, osr               ; a quarter of the clock period
idle:
    jmp !pin, inhibited      ; the host holds the clock
    jmp tx, send
    jmp idle
inhibited:
    wait 1 pin 13
    mov t, now               ; the host has let the clock go
    mov isr, null
    in pins, 1
    mov x, isr
    jmp x--, idle            ; data is high: not a request to send
    add t, p
    set x, 9                 ; eight data bits, parity, stop
rbit:
    wait t+
    set pindirs, 1           ; clock falls: the host puts the next bit out
    wait t+
    wait t+
    set pindirs, 0           ; clock rises
    wait t+
    in pins, 1               ; the middle of clock high
    jmp x--, rbit
    mov pindirs, !null       ; acknowledge: data low
    wait t+
    set pindirs, 1
    wait t+
    wait t+
    set pindirs, 0
    wait t+
    mov pindirs, null        ; let data go
    in null, 6
    push
    jmp idle
send:
    pull
    crc_init
    mov isr, null
    in osr, 8
    set x, 7
parity:
    out null, 1              ; through the CRC
    jmp x--, parity
    in crc, 1
    set y, 1
    in y, 1                  ; stop
    in null, 5
    mov osr, isr
    set x, 10
    mov t, now
    add t, p
    add t, p
    add t, p
    add t, p                 ; the bus idle for a clock period
sbit:
    out y, 1
    wait t+
    jmp !pin, abort          ; the host has taken the clock
    mov pindirs, !y          ; data moves in the middle of clock high
    wait t+
    set pindirs, 1           ; clock falls: the host samples
    wait t+
    wait t+
    set pindirs, 0           ; clock rises
    jmp x--, sbit
    jmp idle
abort:
    mov pindirs, null
    irq
    jmp idle
|}
;;

let config =
  { Program_config.default with
    in_base = data_pin
  ; out_base = data_pin
  ; out_count = 1
  ; set_base = clock_pin
  ; set_count = 1
  ; jmp_pin = clock_pin
  ; crc_width = 1
  ; crc_poly = 1
  ; crc_init = 1
  ; crc_reflect = false
  }
;;

module Host = struct
  module Action = struct
    type t =
      | Inhibit
      | Send of int
    [@@deriving sexp_of]
  end

  module Mode = struct
    type t =
      | Listening of int list (* the bits of the frame so far, newest first *)
      | Inhibiting of
          { left : int
          ; send : int option
          }
      | Requesting of
          { left : int
          ; byte : int
          }
      | Sending of
          { byte : int
          ; pending : int list
          ; falls : int
          }
  end

  type t =
    { cycle_ns : int
    ; script : (int * Action.t) list
    ; now : int
    ; mode : Mode.t
    ; clock_low : bool
    ; data_low : bool
    ; clock : int
    ; data : int
    ; clock_run : int
    ; data_run : int
    ; own_clock : bool (* this host held the clock at some point of the current run *)
    ; data_moved : bool (* since the clock last fell *)
    ; log : string list
    ; measured : Measured.t
    ; violations : string list
    }

  let inhibit_us = 100
  let request_overlap_us = 10

  let create ~cycle_ns script =
    { cycle_ns
    ; script
    ; now = 0
    ; mode = Listening []
    ; clock_low = false
    ; data_low = false
    ; clock = 1
    ; data = 1
    ; clock_run = 0
    ; data_run = 0
    ; own_clock = false
    ; data_moved = false
    ; log = []
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let clock_low t = t.clock_low
  let data_low t = t.data_low
  let ns t cycles = cycles * t.cycle_ns
  let cycles t us = us * 1000 / t.cycle_ns
  let log_line t line = { t with log = line :: t.log }
  let violation t line = { t with violations = line :: t.violations }

  let checked t ~name ~ns ~at_least ~at_most =
    let t = { t with measured = Measured.add t.measured ~name ~ns } in
    if at_least <= ns && ns <= at_most
    then t
    else violation t [%string "%{name} of %{ns#Int} ns"]
  ;;

  let odd_parity byte = 1 - (Int.popcount byte land 1)

  let frame_done t bits =
    match List.rev bits with
    | start :: rest when List.length rest = 10 ->
      let data = List.take rest 8 in
      let tail = List.drop rest 8 in
      let byte = List.foldi data ~init:0 ~f:(fun i acc b -> acc lor (b lsl i)) in
      (match tail with
       | [ parity; 1 ] when start = 0 && parity = odd_parity byte ->
         log_line t (sprintf "byte 0x%02x" byte)
       | _ -> log_line t (sprintf "bad frame 0x%02x" byte))
    | _ -> raise_s [%message "BUG: a frame is 11 bits" (List.length bits : int)]
  ;;

  let in_frame t =
    match t.mode with
    | Listening (_ :: _) -> true
    | Sending { falls; _ } -> falls > 0
    | Listening [] | Inhibiting _ | Requesting _ -> false
  ;;

  let data_changed t =
    match t.mode with
    | Listening _ when t.clock = 0 -> violation t "data moved while the clock was low"
    | Listening bits ->
      let t = { t with data_moved = true } in
      if List.is_empty bits
      then t
      else
        checked
          t
          ~name:"hold"
          ~ns:(ns t t.clock_run)
          ~at_least:5_000
          ~at_most:Int.max_value
    | Inhibiting _ | Requesting _ | Sending _ -> t
  ;;

  let clock_fell t ~data =
    let t =
      if in_frame t && not t.own_clock
      then
        checked
          t
          ~name:"clock high"
          ~ns:(ns t t.clock_run)
          ~at_least:30_000
          ~at_most:50_000
      else t
    in
    let t =
      match t.mode with
      | Listening bits ->
        let t =
          if t.data_moved
          then
            checked t ~name:"setup" ~ns:(ns t t.data_run) ~at_least:5_000 ~at_most:25_000
          else t
        in
        let bits = data :: bits in
        if List.length bits = 11
        then { (frame_done t bits) with mode = Listening [] }
        else { t with mode = Listening bits }
      | Sending { byte; pending = bit :: pending; falls } ->
        { t with data_low = bit = 0; mode = Sending { byte; pending; falls = falls + 1 } }
      | Sending { byte; pending = []; falls = 9 } ->
        { t with data_low = false; mode = Sending { byte; pending = []; falls = 10 } }
      | Sending { byte; _ } ->
        log_line
          { t with mode = Listening [] }
          (sprintf
             "sent 0x%02x, %s"
             byte
             (if data = 0 then "acknowledged" else "not acknowledged"))
      | Inhibiting _ | Requesting _ -> t
    in
    { t with data_moved = false }
  ;;

  let clock_rose t =
    if t.own_clock
    then t
    else
      checked t ~name:"clock low" ~ns:(ns t t.clock_run) ~at_least:30_000 ~at_most:50_000
  ;;

  let observe t ~clock ~data =
    let t = if data <> t.data then data_changed t else t in
    let t =
      if clock = t.clock || t.clock_low
      then t
      else if clock = 0
      then clock_fell t ~data
      else clock_rose t
    in
    { t with
      clock
    ; data
    ; clock_run = (if clock = t.clock then t.clock_run + 1 else 1)
    ; data_run = (if data = t.data then t.data_run + 1 else 1)
    ; own_clock = (clock = t.clock && t.own_clock) || t.clock_low
    }
  ;;

  let act t =
    match t.mode with
    | Listening bits ->
      (match t.script with
       | (cycle, action) :: script when cycle <= t.now ->
         let t =
           if List.is_empty bits
           then t
           else log_line t [%string "gave up a frame after %{List.length bits#Int} bits"]
         in
         let send =
           match (action : Action.t) with
           | Inhibit -> None
           | Send byte -> Some byte
         in
         { t with
           script
         ; clock_low = true
         ; mode = Inhibiting { left = cycles t inhibit_us; send }
         }
       | _ -> t)
    | Inhibiting { left = 0; send = None } ->
      log_line { t with clock_low = false; mode = Listening [] } "inhibited"
    | Inhibiting { left = 0; send = Some byte } ->
      { t with
        data_low = true
      ; mode = Requesting { left = cycles t request_overlap_us; byte }
      }
    | Inhibiting { left; send } -> { t with mode = Inhibiting { left = left - 1; send } }
    | Requesting { left = 0; byte } ->
      let pending = List.init 8 ~f:(fun i -> (byte lsr i) land 1) @ [ odd_parity byte ] in
      { t with clock_low = false; mode = Sending { byte; pending; falls = 0 } }
    | Requesting { left; byte } -> { t with mode = Requesting { left = left - 1; byte } }
    | Sending _ -> t
  ;;

  let step t ~clock ~data =
    let t = act (observe t ~clock ~data) in
    { t with now = t.now + 1 }
  ;;

  let log t = List.rev t.log
  let measured t = t.measured
  let violations t = List.rev t.violations
end
