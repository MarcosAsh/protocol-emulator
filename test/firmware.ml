open! Core
open Protocol_emulator

let assemble source = Asm.assemble source |> ok_exn |> Asm.Program.words |> ok_exn

let uart_tx_frame =
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

let uart_tx ~period = [%string "    set p, %{period#Int}%{uart_tx_frame}"]

(* [uart_tx ~period:16], checked when it compiles *)
let uart_tx16 =
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
let uart_tx_stamped ~period =
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
let uart_tx_host_rate = [%string "    wait tx\n    pull\n    mov p, osr%{uart_tx_frame}"]

(* Time-triggered: a frame every ten periods from one anchor. Each byte autopulls at a
   cycle fixed from the anchor, so a late byte sets the underflow fault and moves no edge. *)
let uart_tx_stream ~period =
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
let uart_rx_on ~pin ~period =
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

let uart_rx ~period = uart_rx_on ~pin:0 ~period

let rx_config =
  { Program_config.default with
    in_base = 0
  ; jmp_pin = 0
  ; capture_pin = 0
  ; capture_rising = false
  }
;;

(* each wait carries the level SCK already has *)
let spi_master ~half_period =
  [%string
    {|
    .side_set 1
    set p, %{half_period#Int} side 0
idle:
    wait tx side 0
    pull side 0
    out null, 8 side 0
    set x, 7 side 0
    mov t, now side 0
    add t, p side 0
    wait t+ side 0
    out pins, 1 side 0       ; first bit, half a period before the first edge
bit:
    wait t+ side 0
    in pins, 1 side 1        ; rising edge
    wait t+ side 1
    out pins, 1 side 0       ; falling edge, next bit
    jmp x--, bit
    push side 0
    jmp idle
|}]
;;

(* Time-triggered: SCK runs from one anchor, a byte every eight bits with no gap, by
   autopull on falling edges and autopush on rising ones. *)
let spi_master_stream ~half_period =
  [%string
    {|
    .side_set 1
    set p, %{half_period#Int} side 0
    mov t, now side 0        ; the only anchor
    add t, p side 0
    wait t+ side 0
    out pins, 1 side 0       ; first bit, half a period before the first edge
bit:
    wait t+ side 0
    in pins, 1 side 1        ; rising edge
    wait t+ side 1
    out pins, 1 side 0       ; falling edge, next bit
    jmp bit
|}]
;;

let sck_pin = 6
let mosi_pin = 5
let miso_pin = 0

let spi_config =
  { Program_config.default with
    side_set_count = 1
  ; side_set_base = sck_pin
  ; out_base = mosi_pin
  ; in_base = miso_pin
  ; out_shift = Left
  ; in_shift = Left
  }
;;

let spi_stream_config =
  { spi_config with
    autopull = true
  ; pull_threshold = 8
  ; autopush = true
  ; push_threshold = 8
  }
;;

let slave_sck_pin = 1
let slave_mosi_pin = 2
let slave_miso_pin = 5

let spi_slave_config =
  { Program_config.default with
    in_base = slave_mosi_pin
  ; out_base = slave_miso_pin
  ; in_shift = Left
  ; out_shift = Left
  ; autopush = true
  ; push_threshold = 8
  ; autopull = true
  ; pull_threshold = 8
  }
;;

(* Mode 0 slave, no chip select. Replies come from the host as [byte lsl 8]. Needs sck
   half periods of at least four cycles. *)
let spi_slave =
  [%firmware
    {|
    out pins, 1              ; first bit of the first reply
bit:
    wait 1 pin 1             ; rising edge
    in pins, 1
    wait 0 pin 1             ; falling edge
    out pins, 1
    jmp bit
|}
      ~config:spi_slave_config]
;;

let sda = 12
let scl = 13

(* UM10204 3.1.16: a slave reset mid-read can hold SDA low, and clocking out its byte
   frees it. Each pulse is a bit's two quarters low and two high. *)
let bus_clear =
  {|
    set x, 8 side 0              ; nine pulses at most
    mov t, now side 0
    add t, p side 0
clear:
    jmp pin, clear_stop          ; SDA high: the bus is free
    wait t+ side 0
    nop side 1                   ; SCL low
    wait t+ side 1
    wait t+ side 1
    nop side 0                   ; SCL high
    wait t+ side 0
    jmp x--, clear
clear_stop:
    wait t+ side 0
    nop side 1
    jmp stop
|}
;;

(* host word: start[15] read[14] data[13:6] stop[5]; p is a quarter period *)
let i2c_master_with ~preamble ~quarter =
  [%string
    {|
    .side_set 1
    set p, %{quarter#Int} side 0%{preamble}idle:
    wait tx side 0
    pull side 0
    mov t, now side 0
    add t, p side 0
    add t, p side 0              ; two quarters of slack for the dispatch
    out x, 1 side 0
    jmp x--, start
    jmp send_or_read
byte:
    wait tx side 1
    pull side 1
    mov t, now side 1
    add t, p side 1
    add t, p side 1
    out x, 1 side 1
    jmp x--, restart
    jmp send_or_read
start:                           ; bus idle, both lines high
    wait t+ side 0
    set pindirs, 1 side 0        ; SDA low while SCL high
    wait t+ side 0
    nop side 1
    add t, p side 1              ; a quarter of slack before the dispatch
    jmp send_or_read
restart:                         ; SCL low after a byte
    set pindirs, 0 side 1        ; release SDA
    wait t+ side 1
    nop side 0
    wait t+ side 0
    set pindirs, 1 side 0        ; SDA low while SCL high
    wait t+ side 0
    nop side 1
    add t, p side 1
send_or_read:
    out y, 1 side 1
    set x, 7 side 1
    jmp y--, read
send:
    wait t+ side 1
    out y, 1 side 1
    mov pindirs, !y side 1       ; SDA follows the bit
    wait t+ side 1
    nop side 0                   ; SCL high
    wait t+ side 0
    wait t+ side 0
    nop side 1                   ; SCL low
    jmp x--, send
    wait t+ side 1
    set pindirs, 0 side 1        ; release SDA for the ack
    wait t+ side 1
    nop side 0
    wait t+ side 0
    in pins, 1 side 0            ; ack bit, 0 means acked
    wait t+ side 0
    nop side 1
    out x, 1 side 1              ; stop flag
    jmp finish
read:
    set pindirs, 0 side 1        ; release SDA
rbit:
    wait t+ side 1
    wait t+ side 1
    nop side 0
    wait t+ side 0
    in pins, 1 side 0
    wait t+ side 0
    nop side 1
    jmp x--, rbit
    out null, 8 side 1           ; the unused data bits
    out x, 1 side 1              ; stop flag, and nack on the last byte
    wait t+ side 1
    mov pindirs, !x side 1
    wait t+ side 1
    nop side 0
    wait t+ side 0
    wait t+ side 0
    nop side 1
    set pindirs, 0 side 1
finish:
    push side 1
    jmp x--, stop
    jmp byte
stop:
    wait t+ side 1
    set pindirs, 1 side 1        ; SDA low
    wait t+ side 1
    nop side 0                   ; SCL high
    wait t+ side 0
    set pindirs, 0 side 0        ; SDA released while SCL high
    wait t+ side 0
    jmp idle
|}]
;;

let i2c_master = i2c_master_with ~preamble:bus_clear
let i2c_master_unclearing = i2c_master_with ~preamble:"\n"

let i2c_config =
  { Program_config.default with
    side_set_count = 1
  ; side_set_base = scl
  ; side_set_pindirs = true
  ; out_base = sda
  ; out_count = 1
  ; set_base = sda
  ; set_count = 1
  ; in_base = sda
  ; jmp_pin = sda
  ; out_shift = Left
  ; in_shift = Left
  }
;;

let i2c_slave_config =
  { Program_config.default with
    jmp_pin = scl
  ; out_base = sda
  ; out_count = 1
  ; set_base = sda
  ; set_count = 1
  ; in_base = sda
  ; out_shift = Left
  ; in_shift = Left
  }
;;

(* Slave at the address the host sends first as [address lsl 1]. Written bytes, address
   included, go to the host; read bytes come from it. Start and stop are only watched for
   on the first bit of a byte. Never stretches the clock. *)
let i2c_slave =
  [%firmware
    {|
    pull
    mov p, osr               ; address << 1
idle:
    set pindirs, 0           ; release SDA
    wait 1 pin 13
    wait fall pin 12
    jmp pin, start           ; SCL still high: a start
    jmp idle
start:
    wait 0 pin 13
    mov isr, null
    set x, 7
abit:
    wait 1 pin 13
    in pins, 1
    wait 0 pin 13
    jmp x--, abit
    mov x, isr
    set y, 0
    add y, p
    jmp x!=y, maybe_read
    push
    set pindirs, 1           ; ack
    wait 1 pin 13
    wait 0 pin 13
    set pindirs, 0
first:                       ; a data bit, or SDA moving while SCL is high
    wait 1 pin 13
    in pins, 2               ; SCL and SDA together
    mov x, isr
watch:
    mov isr, null
    in pins, 2
    mov y, isr
    jmp x!=y, changed
    jmp watch
changed:
    jmp pin, control
    sub x, 2                 ; SCL fell: keep the bit
    mov isr, x
    set x, 6
dbit:
    wait 1 pin 13
    in pins, 1
    wait 0 pin 13
    jmp x--, dbit
    push
    set pindirs, 1           ; ack
    wait 1 pin 13
    wait 0 pin 13
    set pindirs, 0
    jmp first
control:
    mov isr, null
    in pins, 1
    mov x, isr
    jmp x--, idle            ; SDA rose: stop
    jmp start                ; SDA fell: repeated start
maybe_read:
    add y, 1
    jmp x!=y, idle           ; another address
    push
    set pindirs, 1           ; ack
    wait 1 pin 13
    wait 0 pin 13
rbyte:
    pull
    out null, 8
    set x, 7
rbit:
    out y, 1
    mov pindirs, !y          ; SDA follows the bit
    wait 1 pin 13
    wait 0 pin 13
    jmp x--, rbit
    set pindirs, 0           ; release SDA for the master's ack
    mov isr, null
    wait 1 pin 13
    in pins, 1
    wait 0 pin 13
    mov x, isr
    jmp x--, idle            ; nack: the master is done
    jmp rbyte
|}
      ~config:i2c_slave_config]
;;

let logger_uart_pin = 5

let i2c_logger_config =
  { i2c_config with out_base = logger_uart_pin; out_count = 1; out_shift = Left }
;;

(* Two protocols on one core: read a byte from the I2C slave at 0x50, log it over UART on
   OUT0, forever. Periods are immediates so the timing is fixed at assembly. The data bit
   is set on both branches of a jump so its edge lands at the same cycle either way. *)
let i2c_logger =
  [%firmware
    {|
    .side_set 1
    mov pins, !null side 0       ; UART idle high
    set pindirs, 0 side 0        ; SDA released
loop:
    set p, 8 side 0
    mov t, now side 0
    add t, p side 0
    wait t+ side 0               ; START
    set pindirs, 1 side 0
    wait t+ side 0
    nop side 1
    add t, p side 1              ; a quarter of slack to build the address
    set x, 20 side 1             ; address 0x50, read: 0xa1
    add x, x side 1
    add x, x side 1
    add x, x side 1
    add x, 1 side 1
    mov osr, x side 1
    out null, 8 side 1
    set x, 7 side 1
sbit:
    wait t+ side 1
    out y, 1 side 1
    jmp y--, sone
    set pindirs, 1 side 1        ; a zero drives SDA low
    jmp sdone
sone:
    set pindirs, 0 side 1        ; a one releases it
sdone:
    wait t+ side 1
    nop side 0                   ; SCL high
    wait t+ side 0
    wait t+ side 0
    nop side 1                   ; SCL low
    jmp x--, sbit
    wait t+ side 1               ; the slave's ack
    set pindirs, 0 side 1
    wait t+ side 1
    nop side 0
    wait t+ side 0
    wait t+ side 0
    nop side 1
    set x, 7 side 1
    mov isr, null side 1
rbit:
    wait t+ side 1
    wait t+ side 1
    nop side 0
    wait t+ side 0
    in pins, 1 side 0
    wait t+ side 0
    nop side 1
    jmp x--, rbit
    wait t+ side 1               ; nack, SDA stays released
    wait t+ side 1
    nop side 0
    wait t+ side 0
    wait t+ side 0
    nop side 1
    wait t+ side 1               ; STOP
    set pindirs, 1 side 1
    wait t+ side 1
    nop side 0
    wait t+ side 0
    set pindirs, 0 side 0
    wait t+ side 0
    set p, 16 side 0             ; UART frame, LSB first from the reversed byte
    mov osr, ::isr side 0
    set x, 7 side 0
    mov t, now side 0
    mov pins, null side 0        ; start bit
    add t, p side 0
ubit:
    wait t+ side 0
    out pins, 1 side 0
    jmp x--, ubit
    wait t+ side 0
    mov pins, !null side 0       ; stop bit
    wait t side 0
    jmp loop
|}
      ~config:i2c_logger_config]
;;

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

let i2c_word ?(start = false) ?(read = false) ?(stop = false) data =
  (Bool.to_int start lsl 15)
  lor (Bool.to_int read lsl 14)
  lor (data lsl 6)
  lor (Bool.to_int stop lsl 5)
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
