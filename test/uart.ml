open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

let frame =
  {|
    set pins, 1              ; idle high
idle:
    wait tx
    pull
    set x, 7
    mov t, now               ; anchor the frame
    set pins, 0              ; start bit
    add t, p
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1              ; stop bit
    wait t
    jmp idle
|}
;;

let tx ~period = [%string "    set p, %{period#Int}%{frame}"]

(* [tx ~period:16], checked when it compiles *)
let tx16 =
  [%firmware
    {|
    set p, 16
    set pins, 1              ; idle high
idle:
    wait tx
    pull
    set x, 7
    mov t, now               ; anchor the frame
    set pins, 0              ; start bit
    add t, p
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1              ; stop bit
    wait t
    jmp idle
|}]
;;

(* 26-bit frame: start, the host's byte, the low 16 bits of the cycle the start bit shows,
   both LSB first, stop. [mov y, now] reads four cycles before that edge. *)
let tx_stamped ~period =
  [%string
    {|
    set p, %{period#Int}
    set pins, 1              ; idle high
idle:
    wait tx
    pull
    set x, 7
    mov y, now
    add y, 4                 ; the cycle the start bit shows
    mov t, now               ; anchor the frame
    set pins, 0              ; start bit
    add t, p
byte:
    wait t+
    out pins, 1
    jmp x--, byte
    mov osr, y               ; then the stamp
    set x, 15
stamp:
    wait t+
    out pins, 1
    jmp x--, stamp
    wait t+
    set pins, 1              ; stop bit
    wait t
    jmp idle
|}]
;;

(* the first word from the host is the bit period *)
let tx_host_rate = [%string "    wait tx\n    pull\n    mov p, osr%{frame}"]

(* Time-triggered: a frame every ten periods from one anchor. Each byte autopulls at a
   cycle fixed from the anchor, so a late byte sets the underflow fault and moves no edge. *)
let tx_stream ~period =
  [%string
    {|
    set p, %{period#Int}
    set pins, 1              ; idle high
    mov t, now               ; the only anchor
    add t, p
frame:
    wait t+
    set pins, 0              ; start bit
    set x, 7
bit:
    wait t+
    out pins, 1              ; autopull takes the byte before its first bit
    jmp x--, bit
    wait t+
    set pins, 1              ; stop bit
    jmp frame
|}]
;;

let stream_config = { Program_config.default with autopull = true; pull_threshold = 8 }

(* Half period one short: the sample lands a cycle after the release. The capture is armed
   only while the line is high, as the certificate assumes of every arm: after the stop
   bit is seen high, or after a framing error once the line is high again, two cycles
   after [check]. [check] (rounded (9p - 27) / 19 cycles into the stop bit) balances a
   slow sender's stop bit against a fast sender's next start edge; from 16 cycles a bit up
   that tolerates 4% either way (at 16, 4.3% fast to 4.1% slow). *)
let rx_on ~pin ~period =
  let check = ((9 * period) - 18) / 19 in
  [%string
    {|
    set p, %{period#Int}
    set y, %{(period / 2) - 1#Int}
idle:
    wait 1 pin %{pin#Int}             ; line idle
arm:
    capture_arm
    wait 0 pin %{pin#Int}             ; start bit, its edge cycle is in capture
    mov t, capture
    add t, y
    add t, p                 ; middle of bit 0
    set x, 7
bit:
    wait t+
    in pins, 1
    jmp x--, bit
    in null, 8
    push
    sub t, %{(period / 2) - check#Int}
    wait t                   ; the check, a slow sender's stop bit has begun
    jmp pin, arm             ; high: arm before a fast sender's next start edge
    irq                      ; framing error
    jmp idle
|}]
;;

let rx ~period = rx_on ~pin:0 ~period

let rx_config =
  { Program_config.default with
    in_base = 0
  ; jmp_pin = 0
  ; capture_pin = 0
  ; capture_rising = false
  }
;;

let stamped =
  Certified.plain "uart_tx_stamped" (tx_stamped ~period:8) Program_config.default
;;

(* the keyboard demo loads the certified copy, at the period python/demo_usb.py works out
   from the clock the same way *)
let log =
  let baud = 115_200 in
  let period = (Bench.clock_hz + (baud / 2)) / baud in
  { Bench.name = "uart_log"
  ; what =
      [%string
        "Firmware.uart_tx_host_rate: the keyboard demo's log to Pico B, %{period#Int} \
         cycles a bit for %{Bench.rate ~unit:\"baud\" period}, on OUT0"]
  ; source = tx_host_rate
  ; config = Program_config.default
  ; assumption = Floor 4
  ; clock_hz = Bench.clock_hz
  ; load = Some period
  ; stimulus = Some { bursts = [ [ 0x55; 0x55 ] ]; quiet = 0; cycles = 20_000 }
  }
;;

(* the bit within 2% of 115200 baud, the 'nasty link' budget a receiver shares *)
let limits =
  let sheet =
    { Datasheet.Sheet.part = "UART at 115200 baud"
    ; document = "Maxim AN2141"
    ; page = "p.4, +-3/152, 2%"
    }
  in
  let bit = 1e9 /. 115_200. in
  [ { Datasheet.firmware = "uart_log"
    ; parameter = "bit"
    ; limit = At_least (bit *. 0.98)
    ; sheet
    ; margin = Cycle
    ; bound = Datasheet.level ~pin:Datasheet.set_pin ~high:false ()
    }
  ; { firmware = "uart_log"
    ; parameter = "bit"
    ; limit = At_most (bit *. 1.02)
    ; sheet
    ; margin = Cycle
    ; bound =
        Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz:_ levels ->
          Datasheet.lows levels)
    }
  ]
;;

(* bits of 16 cycles: 3 Mbaud at 48 MHz *)
let trace_hz = 48_000_000

let sigrok ?(teeth = []) ~channel ~pin bytes =
  { Sigrok.clock_hz = trace_hz
  ; decoders =
      [ Sigrok.decoder
          "uart"
          ~pins:[ channel, pin ]
          ~options:[ "baudrate", Int.to_string (trace_hz / 16) ]
      ]
  ; expect =
      [ [%string "uart=%{channel}-data"], List.map bytes ~f:(sprintf "uart-1: %02X") ]
  ; joins_after = None
  ; rejected = None
  ; teeth
  }
;;

let tx_scenario =
  { Scenario.name = "uart_tx"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:Program_config.default
        ~program:(Firmware.assemble (tx ~period:16))
      @ [ Write (Reg.tx, [ 0x55; 0xa3 ]); Scenario.start; Run 400; Read (Reg.status, 1) ]
  ; sigrok =
      (* the first stop bit, edge 10, 12 cycles late: sampled low, a framing error *)
      Some
        (sigrok
           ~channel:"tx"
           ~pin:Program_config.default.out_base
           ~teeth:
             [ [ Shift { pin = Program_config.default.out_base; edge = 10; cycles = 12 } ]
             ]
           [ 0x55; 0xa3 ])
  }
;;

(* A read frame ends with the next rx head on miso; after emptying the fifo that is
   unwritten RAM, zero here but X in Verilog. So the host always leaves a word behind. *)
let rx_scenario =
  let period = 16 in
  let first = [ 0x55; 0xa3; 0xff; 0x00 ]
  and second = [ 0x0f; 0xf0; 0x5a ] in
  let drive bytes =
    Step.Drive { pin = 0; levels = Protocol_models.serial_levels bytes ~period ~stop:1 }
  in
  { Scenario.name = "uart_rx"
  ; peer = (fun () -> Peer.idle 1)
  ; script =
      Scenario.load ~config:rx_config ~program:(Firmware.assemble (rx ~period))
      @ [ Scenario.start
        ; drive first
        ; Read (Reg.rx, 3)
        ; drive second
        ; Read (Reg.rx, 3)
        ; Read (Reg.status, 1)
        ]
  ; sigrok =
      (* the first stop bit, edge 9, 12 cycles late: a framing error *)
      Some
        (sigrok
           ~channel:"rx"
           ~pin:rx_config.in_base
           ~teeth:[ [ Shift { pin = rx_config.in_base; edge = 9; cycles = 12 } ] ]
           (first @ second))
  }
;;

let protocol =
  let plain = Certified.plain in
  { Protocol.name = "uart"
  ; certified =
      [ plain "uart_tx" (tx ~period:8) Program_config.default
        (* the same UART at the slower bit period the tests use *)
      ; plain "uart_tx16" (Timed_program.source tx16) Program_config.default
      ; plain
          ~period:434
          ~period_floor:4
          ~no_wrap:true
          "uart_tx_host_rate"
          tx_host_rate
          Program_config.default
      ; Certified.receiver "uart_rx" (rx ~period:16) rx_config
      ]
  ; time_triggered = [ plain "uart_tx_stream" (tx_stream ~period:8) stream_config ]
  ; bench = []
  ; loaded_from_hex = [ log ]
  ; limits
  ; unlimited = []
  ; scenarios = [ tx_scenario; rx_scenario ]
  }
;;
