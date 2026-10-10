open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

let sda = 12
let scl = 13

(* UM10204 3.1.16: a master reset mid-read can leave a slave holding SDA low, and clocking
   out its byte frees it. Each pulse is a bit's two quarters low and two high. SDA read
   high may be a 1 bit, so a START resets the slave before the STOP. [sda_high] jumps to
   [clear_stop] when SDA reads high; [stop] follows the START. *)
let bus_clear_testing ~sda_high ~stop =
  [%string
    {|
    set x, 8 side 0              ; nine pulses at most
    mov t, now side 0
    add t, p side 0
clear:
%{sda_high}
    wait t+ side 0
    nop side 1                   ; SCL low
    wait t+ side 1
    wait t+ side 1
    nop side 0                   ; SCL high
    wait t+ side 0
    jmp x--, clear
clear_stop:
    wait t+ side 0
    set pindirs, 1 side 0        ; a START, which resets any slave
    wait t+ side 0
    nop side 1
%{stop}
|}]
;;

let bus_clear =
  bus_clear_testing
    ~sda_high:"    jmp pin, clear_stop          ; SDA high"
    ~stop:"    jmp stop"
;;

(* host word: start[15] read[14] data[13:6] stop[5]; p is a quarter period, which [load]
   sets *)
let master_loading ~load ~preamble =
  [%string
    {|
    .side_set 1
%{load}%{preamble}idle:
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

let master_with ~preamble ~quarter =
  master_loading ~load:[%string "    set p, %{quarter#Int} side 0"] ~preamble
;;

let master = master_with ~preamble:bus_clear
let master_without_bus_clear = master_with ~preamble:"\n"

let master_host_rate =
  master_loading
    ~load:"    wait tx side 0\n    pull side 0\n    mov p, osr side 0"
    ~preamble:bus_clear
;;

let config =
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

(* Lets SCL go and polls it every four cycles, 65536 times at most, for a slave holding it
   low. Once high, [t] is set where [master]'s is when SCL rises at once, so what follows
   is timed from the poll that saw it high, 0 to 3 cycles after the input did. *)
let scl_rise ?(stuck = "stuck") label =
  [%string
    {|    mov y, !null side 0          ; SCL let go
%{label}:
    jmp pin, %{label}_high
    jmp y--, %{label}
    jmp %{stuck}
%{label}_high:
    mov t, now side 0
    sub t, 4 side 0              ; the plain master's t when SCL rises at once
    add t, p side 0|}]
;;

(* [master_loading] waiting on SCL after each release. The bus clear reads SDA by
   [mov y, pins], so the jump pin can be SCL, and does not wait on SCL: its STOP is the
   plain master's, so a bus held low from reset answers nothing until a word comes. *)
let master_stretch_loading ~load =
  let bus_clear =
    bus_clear_testing
      ~sda_high:"    mov y, pins side 0\n    jmp y--, clear_stop"
      ~stop:
        {|    wait t+ side 1
    set pindirs, 1 side 1
    wait t+ side 1
    nop side 0
    wait t+ side 0
    set pindirs, 0 side 0
    wait t+ side 0
    jmp idle|}
  in
  [%string
    {|
    .side_set 1
%{load}%{bus_clear}idle:
    wait tx side 0
    pull side 0
    mov t, now side 0
    add t, p side 0
    add t, p side 0              ; two quarters of slack for the dispatch
    jmp !pin, stuck              ; SCL held low: answer at once
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
%{scl_rise "restart_rise"}
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
%{scl_rise "send_rise"}
    wait t+ side 0
    wait t+ side 0
    nop side 1                   ; SCL low
    jmp x--, send
    wait t+ side 1
    set pindirs, 0 side 1        ; release SDA for the ack
    wait t+ side 1
%{scl_rise "ack_rise"}
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
%{scl_rise "read_rise"}
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
%{scl_rise "nack_rise"}
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
%{scl_rise ~stuck:"stop_stuck" "stop_rise"}
    wait t+ side 0
    set pindirs, 0 side 0        ; SDA released while SCL high
    wait t+ side 0
    jmp idle
stop_stuck:                      ; held at the STOP: the word has its reply
    mov t, now side 0
    add t, p side 0
    wait t side 0                ; a quarter, for an SCL let go after the last poll
    set pindirs, 0 side 0
    jmp aborted
stuck:                           ; SCL held low: let both lines go
    mov t, now side 0
    add t, p side 0
    wait t side 0
    set pindirs, 0 side 0
    mov isr, !null side 0        ; 0xffff for the word
    push side 0
aborted:                         ; 0xffff, off the bus, for every word up to a START
    wait tx side 0
    pull side 0
    out x, 1 side 0
    jmp x--, aborted_start
    mov isr, !null side 0
    push side 0
    jmp aborted
aborted_start:
    mov t, now side 0
    add t, p side 0
    add t, p side 0
    jmp !pin, stuck
    jmp start
|}]
;;

let master_stretch ~quarter =
  master_stretch_loading ~load:[%string "    set p, %{quarter#Int} side 0"]
;;

let master_stretch_host_rate =
  master_stretch_loading
    ~load:"    wait tx side 0\n    pull side 0\n    mov p, osr side 0"
;;

let stretch_config = { config with jmp_pin = scl; in_count = 1 }

let slave_config =
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
let slave =
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
      ~config:slave_config]
;;

let logger_uart_pin = 5

let logger_config =
  { config with out_base = logger_uart_pin; out_count = 1; out_shift = Left }
;;

(* Two protocols on one core: read a byte from the I2C slave at 0x50, log it over UART on
   OUT0, forever. Periods are immediates so the timing is fixed at assembly. The data bit
   is set on both branches of a jump so its edge lands at the same cycle either way. *)
let logger =
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
      ~config:logger_config]
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

let word ?(start = false) ?(read = false) ?(stop = false) data =
  (Bool.to_int start lsl 15)
  lor (Bool.to_int read lsl 14)
  lor (data lsl 6)
  lor (Bool.to_int stop lsl 5)
;;

let bench_quarter = Bench.quarter ~hz:250_000

let on_bench_pins ~jmp_pin (config : Program_config.t) =
  { config with
    side_set_base = Bench.scl
  ; out_base = Bench.sda
  ; set_base = Bench.sda
  ; in_base = Bench.sda
  ; jmp_pin
  }
;;

let bench =
  [ { Bench.name = "i2c_master"
    ; what =
        [%string
          "I2c.master_host_rate: the host sends the quarter, %{bench_quarter#Int} cycles \
           for %{Bench.rate (4 * bench_quarter)}, SDA on IO2, SCL on IO3"]
    ; source = master_host_rate
    ; config = on_bench_pins ~jmp_pin:Bench.sda config
    ; assumption = Floor 31
    ; clock_hz = Bench.clock_hz
    ; load = Some bench_quarter
    ; stimulus = None
    }
  ; { name = "i2c_master_stretch"
    ; what =
        "I2c.master_stretch_host_rate: I2c.master waiting on SCL, SDA on IO2, SCL on IO3"
    ; source = master_stretch_host_rate
    ; config = on_bench_pins ~jmp_pin:Bench.scl stretch_config
    ; assumption = Floor 31
    ; clock_hz = Bench.clock_hz
    ; load = Some bench_quarter
    ; stimulus = None
    }
  ; { name = "start_hold"
    ; what =
        "Firmware.start_hold for engine 1: each START's hold in cycles, SDA on IO2, SCL \
         on IO3, both only listened to"
    ; source = start_hold ~sda:Bench.sda ~scl:Bench.scl
    ; config = start_hold_config ~scl:Bench.scl
    ; assumption = Nothing
    ; clock_hz = Bench.clock_hz
    ; load = None
    ; stimulus = None
    }
  ]
;;

(* 24LC256 at 3.3 V, the 2.5 to 5.5 V rows. The kernel times the master's pins, so a width
   from a release to the next edge loses the line's rise, TR of 300 ns at most. *)
let limits firmware =
  let sheet page =
    { Datasheet.Sheet.part = "24LC256"
    ; document = "Microchip DS20001203W, Table 1-2"
    ; page
    }
  in
  let rise = Datasheet.Margin.Ns { ns = 300.; why = "TR, param 4" } in
  let scl = Datasheet.side_pin
  and sda = Datasheet.set_pin in
  (* the bits before an edge are true while the master holds the line low *)
  let pair ?hold ?apart () =
    Datasheet.Bound.Kernel
      (fun config ->
        Datasheet.spacing ~dirs:true ?hold ?apart ~a:(scl config) ~b:(sda config) ())
  in
  let sda_pair ?hold ?apart () =
    Datasheet.Bound.Kernel
      (fun config n ->
        Datasheet.swap
          (Datasheet.spacing ~dirs:true ?hold ?apart ~a:(sda config) ~b:(scl config) () n))
  in
  let limit parameter ns page margin bound =
    { Datasheet.firmware
    ; parameter
    ; limit = At_least ns
    ; sheet = sheet page
    ; margin
    ; bound
    }
  in
  [ limit "THIGH" 600. "p.3, param 2" rise (pair ~hold:(fun ~own ~other:_ -> not own) ())
  ; limit "TLOW" 1300. "p.3, param 3" Cycle (pair ~hold:(fun ~own ~other:_ -> own) ())
  ; limit
      "THD:STA"
      600.
      "p.3, param 6"
      Cycle
      (pair ~apart:(fun ~own ~other -> (not own) && other) ())
  ; limit
      "TSU:STA"
      600.
      "p.3, param 7"
      rise
      (sda_pair ~apart:(fun ~own ~other -> (not own) && not other) ())
  ; limit "TSU:DAT" 100. "p.3, param 9" rise (pair ~apart:(fun ~own ~other:_ -> own) ())
  ; limit
      "TSU:STO"
      600.
      "p.3, param 10"
      rise
      (sda_pair ~apart:(fun ~own ~other -> own && not other) ())
  ; limit
      "TBUF"
      1300.
      "p.4, param 14"
      rise
      (sda_pair ~hold:(fun ~own ~other -> (not own) && not other) ())
  ]
;;

let scenario =
  let memory = List.init 16 ~f:(fun i -> 0x10 + (0x11 * i)) in
  (* the reads that end inside the trace *)
  let read = List.take memory 4 in
  let peer () =
    let slave =
      ref (Protocol_models.I2c_slave.create ~address:0x50 ~memory:(Array.of_list memory))
    in
    let bus_sda = ref 1
    and bus_scl = ref 1 in
    { Peer.inputs = (fun () -> (!bus_sda lsl sda) lor (!bus_scl lsl scl))
    ; step =
        (fun ~pin_out:_ ~pin_dir ->
          bus_sda
          := if Protocol_models.I2c_slave.drive_low !slave
             then 0
             else 1 - Peer.bit pin_dir sda;
          bus_scl := 1 - Peer.bit pin_dir scl;
          slave := Protocol_models.I2c_slave.step !slave ~sda:!bus_sda ~scl:!bus_scl)
    }
  in
  let clock_hz = 48_000_000 in
  { Scenario.name = "i2c_logger"
  ; peer
  ; script =
      Scenario.load ~config:logger_config ~program:(Timed_program.words logger)
      @ [ Scenario.start; Run 3000; Read (Reg.status, 1) ]
  ; sigrok =
      Some
        { clock_hz
        ; decoders =
            [ Sigrok.decoder "i2c" ~pins:[ "scl", scl; "sda", sda ]
            ; Sigrok.decoder
                "uart"
                ~pins:[ "tx", logger_uart_pin ]
                ~options:[ "baudrate", Int.to_string (clock_hz / 16) ]
            ]
        ; expect =
            [ ( "i2c=start:address-read:ack:data-read:nack:stop"
              , List.concat_map read ~f:(fun byte ->
                  [ "Start"
                  ; "Read"
                  ; "Address read: 50"
                  ; "ACK"
                  ; sprintf "Data read: %02X" byte
                  ; "NACK"
                  ; "Stop"
                  ])
                |> List.map ~f:(( ^ ) "i2c-1: ") )
            ; "uart=tx-data", List.map read ~f:(sprintf "uart-1: %02X")
            ]
        ; joins_after = None
        ; rejected = None
        ; (* edge 6 is the slave's ACK of the first address: a NACK instead *)
          teeth = [ [ Flip { pin = sda; edge = 6; after = 0; cycles = 32 } ] ]
        }
  }
;;

let protocol =
  { Protocol.name = "i2c"
  ; certified =
      [ (* the smallest Fast-mode Plus quarter at 50 MHz (test_i2c.ml): assumes zero rise
           time, with tHD;STA, tSU;STA and tSU;STO exactly at their limits *)
        Certified.plain ~no_wrap:true "i2c_master" (master ~quarter:13) config
      ; Certified.plain "i2c_slave" (Timed_program.source slave) slave_config
      ; Certified.plain "i2c_logger" (Timed_program.source logger) logger_config
      ]
  ; time_triggered = []
  ; bench
  ; loaded_from_hex = []
  ; limits = limits "i2c_master" @ limits "i2c_master_stretch"
  ; unlimited = [ "start_hold", "it drives no pin: it listens to Pico B's I2C" ]
  ; swept = []
  ; not_swept =
      [ ( "i2c_master"
        , "open drain, which a wire does not show, and a slave has to acknowledge" )
      ; "i2c_slave", "a slave: the master's clock moves it"
      ; "i2c_logger", "an I2C master: open drain, and a slave has to answer"
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
