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

(* the first word from the host is the bit period *)
let uart_tx_host_rate = [%string "    pull\n    mov p, osr%{uart_tx_frame}"]

(* half period one short: the sample lands a cycle after the release *)
let uart_rx ~period =
  [%string
    {|
    set p, %{period#Int}
    set y, %{(period / 2) - 1#Int}
    wait 1 pin 0             ; line idle
    capture_arm
idle:
    wait 0 pin 0             ; start bit, its edge cycle is in capture
    mov t, capture
    add t, y
    add t, p                 ; middle of bit 0
    set x, 7
bit:
    wait t+
    in pins, 1
    jmp x--, bit
    capture_arm              ; watch for the next start edge from here on
    in null, 8
    push
    wait t                   ; middle of the stop bit
    jmp pin, idle
    irq                      ; framing error
    wait 1 pin 0
    capture_arm
    jmp idle
|}]
;;

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

(* Mode 0 slave, no chip select: sample mosi on the rising edge, shift the next miso bit
   out on the falling edge. Replies come from the host as [byte lsl 8] and autopull at 8
   bits; received bytes autopush at 8. The loop needs sck half periods of at least four
   cycles. *)
let spi_slave =
  {|
    out pins, 1              ; first bit of the first reply
bit:
    wait 1 pin 1             ; rising edge
    in pins, 1
    wait 0 pin 1             ; falling edge
    out pins, 1
    jmp bit
|}
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

let sda = 12
let scl = 13

(* host word: start[15] read[14] data[13:6] stop[5]; p is a quarter period *)
let i2c_master ~quarter =
  [%string
    {|
    .side_set 1
    set p, %{quarter#Int} side 0
idle:
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
  ; out_shift = Left
  ; in_shift = Left
  }
;;

(* Slave at the address the host sends first as [address lsl 1]. Every byte the master
   writes, the address byte included, goes to the host; bytes the master reads come from
   the host. The first bit of each written byte is watched for a start or stop condition
   while SCL is high. Never stretches the clock. *)
let i2c_slave =
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

(* Two protocols on one core: read a byte from the I2C slave at 0x50, then log it over
   UART on OUT0, forever. Quarter and bit periods are immediates so the timing is fixed at
   assembly. The I2C data bit goes through [set pindirs] on either branch of a jump, so
   that an edge lands the same number of cycles after its release whichever way the bit
   falls. *)
let i2c_logger =
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
;;

let logger_uart_pin = 5

let i2c_logger_config =
  { i2c_config with out_base = logger_uart_pin; out_count = 1; out_shift = Left }
;;

(* USB low speed transmitter. The host sends the bit period, then per packet the SYNC
   byte, the PID, the number of data bytes less one, and the data; the core appends the
   CRC-16 and the EOP. Every data bit goes out on a scratch pin first, which is how the
   CRC and the stuff counter see it and how [jmp pin] reads it back; a zero toggles D+ and
   D- for NRZI, and after six ones a forced zero goes in. Each toggle lands four cycles
   after its deadline whichever path it takes. *)
let usb_tx =
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

(* USB low speed receiver. The host sends the bit period; the half period is assembled in
   as immediates so the analyser can follow it. The first K of SYNC is captured and the
   line is sampled half a bit later and every bit after: an unchanged line is a one, a
   change is a zero, and SE0 ends the packet. Decoded bits go through [in] one at a time
   so the CRC and the stuff counter see them and autopush hands each byte to the host;
   after the EOP the CRC register follows as one more word for the host to check. A forced
   zero after six ones is consumed without being recorded. *)
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

let i2c_word ?(start = false) ?(read = false) ?(stop = false) data =
  (Bool.to_int start lsl 15)
  lor (Bool.to_int read lsl 14)
  lor (data lsl 6)
  lor (Bool.to_int stop lsl 5)
;;
