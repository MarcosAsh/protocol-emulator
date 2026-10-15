open! Core
open Protocol_emulator

let data_pin = 12
let clock_pin = 13
let cycle_ns = 20
let standard_quarter = 20_000 / cycle_ns

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

(* [set] is the clock and [mov pindirs] the data; a direction bit of 1 pulls low. isr
   builds the frame shifting right: byte, parity from the CRC, stop, then five more so the
   start bit is bit 0. *)
let firmware =
  [%firmware
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
      ~config
      ~period_floor:8]
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

open Pin_trace
module Reg = Host_port.Reg

(* The host lets each frame end, then holds the clock low for 100 us as it takes the byte
   in. That fall is also the twelfth sigrok 0.5.3's ps2 decoder waits for before it reads
   a frame of eleven clocks. *)
let scenario =
  let quarter = standard_quarter in
  let bytes = [ 0x1c; 0xf0; 0x1c ] in
  let peer () =
    let clock = ref 1
    and data = ref 1
    and falls = ref 0
    and inhibit_in = ref None
    and holding = ref 0 in
    { Peer.inputs = (fun () -> (!clock lsl clock_pin) lor (!data lsl data_pin))
    ; step =
        (fun ~pin_out:_ ~pin_dir ->
          let was = !clock in
          (match !inhibit_in with
           | Some 0 ->
             inhibit_in := None;
             holding := 100_000 / cycle_ns
           | Some n -> inhibit_in := Some (n - 1)
           | None -> if !holding > 0 then decr holding);
          clock := if Peer.bit pin_dir clock_pin = 1 || !holding > 0 then 0 else 1;
          data := 1 - Peer.bit pin_dir data_pin;
          if was = 1 && !clock = 0 && !holding = 0 then incr falls;
          if was = 0 && !clock = 1 && !falls = 11
          then (
            falls := 0;
            inhibit_in := Some quarter))
    }
  in
  (* a frame is a clock period of idle and eleven clocks, 48 quarters *)
  let send byte = [ Step.Write (Reg.tx, [ byte ]); Run ((48 * quarter) + 10_000) ] in
  { Scenario.name = "ps2"
  ; peer
  ; script =
      Scenario.load ~config ~program:(Timed_program.words firmware)
      @ [ Scenario.start; Write (Reg.tx, [ quarter ]) ]
      @ List.concat_map bytes ~f:send
  ; sigrok =
      Some
        { clock_hz = 1_000_000_000 / cycle_ns
        ; decoders = [ Sigrok.decoder "ps2" ~pins:[ "clk", clock_pin; "data", data_pin ] ]
        ; expect =
            [ ( "ps2=start-bit:word:parity-ok:stop-bit"
              , List.concat_map bytes ~f:(fun byte ->
                  [ "Start bit"; sprintf "Data: %02x" byte; "Parity OK"; "Stop bit" ])
                |> Sigrok.lines "ps2" )
            ; (* sigrok checks neither the start nor the stop bit, only labels them *)
              ( "ps2=bit"
              , List.concat_map bytes ~f:(fun byte ->
                  let data = List.init 8 ~f:(fun i -> (byte lsr i) land 1) in
                  let parity = 1 - (List.sum (module Int) data ~f:Fn.id % 2) in
                  (0 :: data) @ [ parity; 1 ])
                |> List.map ~f:Int.to_string
                |> Sigrok.lines "ps2" )
            ]
        ; joins_after = None
        ; rejected = None
        ; (* edge 2 is the first byte's fall at bit 5, three bits before its parity *)
          teeth =
            [ [ Flip
                  { pin = data_pin; edge = 2; after = 12 * quarter; cycles = 4 * quarter }
              ]
            ; (* edge 3 raises the first byte's stop bit: held low instead *)
              [ Flip { pin = data_pin; edge = 3; after = 0; cycles = 4 * quarter } ]
            ]
        }
  }
;;

(* the firmware on the bench's clock, at a 20 us quarter, sending one byte *)
let bench =
  let quarter = Bench.cycles_in ~us:20 in
  { Bench.name = "ps2"
  ; what =
      [%string
        "Ps2.firmware: the keyboard's end, %{quarter#Int} cycles a quarter clock, \
         %{Bench.rate ~unit:\"Hz\" (4 * quarter)}, data on IO0 and clock on IO1, which \
         no demo has wired yet"]
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Floor 8
  ; clock_hz = Bench.clock_hz
  ; load = Some quarter
  ; stimulus = Some { bursts = [ [ 0x1c ] ]; quiet = 0; cycles = 60 * quarter }
  }
;;

(* IBM's receiving data timings, figure 8: T1 at each fall of the clock, since data last
   moved, T2 at each move of data, since the clock rose, and the clock's lows and highs,
   but the high from reset before the frame. A direction bit of 1 pulls the line low. The
   kernel bounds a high from the device letting the clock go to its taking it again, 969
   cycles at least, which counts a host's inhibit and request to send in between, and
   figure 9 leaves the quarter from the host letting go to the first clock untimed; so the
   least high is the run's. *)
let limits =
  let sheet parameter =
    { Datasheet.Sheet.part = "PS/2 keyboard and auxiliary device"
    ; document = "IBM Personal System/2 Hardware Interface Technical Reference, May 1988"
    ; page =
        [%string
          "Keyboard and Auxiliary Device Controller, Figure 8, p. 13, %{parameter}"]
    }
  in
  let clock (config : Program_config.t) = config.set_base
  and data (config : Program_config.t) = config.out_base in
  let spacing ~a ~b ~apart =
    Datasheet.Bound.Kernel
      (fun config -> Datasheet.spacing ~dirs:true ~a:(a config) ~b:(b config) ~apart ())
  in
  let highs =
    Datasheet.run ~pin:clock (fun ~clock_hz:_ levels ->
      List.drop levels 1 |> List.filter_map ~f:(fun (high, n) -> Option.some_if high n))
  in
  let limit parameter what limit bound =
    { Datasheet.firmware = "ps2"
    ; parameter = what
    ; limit
    ; sheet = sheet parameter
    ; margin = Cycle
    ; bound
    }
  in
  [ limit
      "T1"
      "data to CLK fall"
      (At_least 5_000.)
      (spacing ~a:clock ~b:data ~apart:(fun ~own ~other:_ -> not own))
  ; limit
      "T2"
      "CLK rise to data"
      (At_least 5_000.)
      (spacing ~a:data ~b:clock ~apart:(fun ~own:_ ~other -> not other))
  ; limit
      "T3"
      "CLK low"
      (At_least 30_000.)
      (Datasheet.level ~dirs:true ~pin:clock ~high:true ())
  ; limit
      "T3"
      "CLK low"
      (At_most 50_000.)
      (Datasheet.run ~pin:clock (fun ~clock_hz:_ levels -> Datasheet.lows levels))
  ; limit "T4" "CLK high" (At_least 30_000.) highs
  ; limit "T4" "CLK high" (At_most 50_000.) highs
  ]
;;

let protocol =
  { Protocol.name = "ps2"
  ; certified =
      [ Certified.plain
          ~period:standard_quarter
          ~period_floor:8
          "ps2"
          (Timed_program.source firmware)
          config
      ]
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ "ps2", "open drain, which a wire does not show, and the host holds the clock" ]
  ; scenarios = []
  ; decoded = [ scenario ]
  }
;;
