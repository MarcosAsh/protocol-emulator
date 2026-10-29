open! Core
open Protocol_emulator

let period = 10
let wire = Isa.num_pins
let sck_pin = Spi.sck_pin
let mosi_pin = Spi.mosi_pin

(* [Uart.rx_on ~pin:0 ~period:10], its push gone and a good stop bit sending [isr] on the
   wire as [Uart.tx] sends a host word, both at [p] cycles a bit *)
let relay_source =
  {|
    set p, 10
    set y, 4
    set pins, 1              ; the wire idles high
idle:
    wait 1 pin 0             ; line idle
arm:
    capture_arm
    wait 0 pin 0             ; start bit, its edge cycle is in capture
    mov t, capture
    add t, y
    add t, p                 ; middle of bit 0
    set x, 7
bit:
    wait t+
    in pins, 1
    jmp x--, bit
    in null, 8
    sub t, 2
    wait t                   ; the check, a slow sender's stop bit has begun
    jmp pin, send            ; high: send the byte
    irq                      ; framing error
    jmp idle
send:
    mov osr, isr
    set x, 7
    mov t, now               ; anchor the frame
    set pins, 0              ; start bit
    add t, p
wire_bit:
    wait t+
    out pins, 1
    jmp x--, wire_bit
    wait t+
    set pins, 1              ; stop bit
    wait t
    jmp idle
|}
;;

(* [Uart.rx_on ~pin:20 ~period:10] the same, a good stop bit clocking [isr]'s low byte out
   as [Spi.master ~half_period:10] does a host word's; no MISO, so its [in] shifts null *)
let controller_source =
  {|
    .side_set 1
    set p, 10 side 0
    set y, 4 side 0
idle:
    wait 1 pin 20 side 0     ; line idle
arm:
    capture_arm side 0
    wait 0 pin 20 side 0     ; start bit, its edge cycle is in capture
    mov t, capture side 0
    add t, y side 0
    add t, p side 0          ; middle of bit 0
    set x, 7 side 0
bit:
    wait t+ side 0
    in pins, 1 side 0
    jmp x--, bit
    in null, 8 side 0
    sub t, 2 side 0
    wait t side 0            ; the check, a slow sender's stop bit has begun
    jmp pin, send            ; high: send the byte
    irq side 0               ; framing error
    jmp idle
send:
    mov osr, isr side 0
    out null, 8 side 0
    set x, 7 side 0
    mov t, now side 0
    add t, p side 0
    wait t+ side 0
    out pins, 1 side 0       ; first bit, half a period before the first edge
spi_bit:
    wait t+ side 0
    in null, 1 side 1        ; rising edge
    wait t+ side 1
    out pins, 1 side 0       ; falling edge, next bit
    jmp x--, spi_bit
    jmp idle
|}
;;

let relay =
  Timed_program.of_source_exn
    ~single_capture_edge:true
    ~config:{ Uart.rx_config with set_base = wire; out_base = wire }
    relay_source
;;

let controller =
  Timed_program.of_source_exn
    ~single_capture_edge:true
    ~config:
      { Spi.config with
        in_base = wire
      ; jmp_pin = wire
      ; capture_pin = wire
      ; capture_rising = false
      ; in_shift = Right
      }
    controller_source
;;

let spacing = 276

(* start bit, eight bits LSB first, stop bit *)
let line frames cycle =
  List.find_map frames ~f:(fun (start, byte) ->
    let bit = (cycle - start) / period in
    if cycle < start || bit > 9
    then None
    else if bit = 0
    then Some 0
    else if bit = 9
    then Some 1
    else Some ((byte lsr (bit - 1)) land 1))
  |> Option.value ~default:1
;;

module Frame = struct
  type t =
    { stop : int
    ; wire_fall : int
    ; first_rise : int
    ; last_fall : int
    ; byte : int
    }
  [@@deriving sexp_of]
end

module Outcome = struct
  type t =
    { frames : Frame.t list
    ; faults : Machine.Fault.t list
    ; irq : bool list
    ; mismatch : System_lockstep.Mismatch.t option
    }
  [@@deriving sexp_of]
end

(* The pins after each cycle's edge, which show from the next cycle, as IN0's level shows
   in its cycle: the wire as engine 0 drives it, SCK and MOSI as the chip does. Each frame
   is the wire's falls, then SCK's rises and falls in eights. *)
module Watch = struct
  type t =
    { mutable cycle : int
    ; mutable wire : int
    ; mutable sck : int
    ; wire_falls : int Queue.t
    ; rises : (int * int) Queue.t
    ; falls : int Queue.t
    }

  let create () =
    { cycle = 0
    ; wire = 0
    ; sck = 0
    ; wire_falls = Queue.create ()
    ; rises = Queue.create ()
    ; falls = Queue.create ()
    }
  ;;

  let bit v n = (v lsr n) land 1

  let after t (system : System.t) =
    let engine_0 = List.hd_exn system.engines in
    let wire = bit engine_0.pin_out wire in
    let pins = System.pin_out system in
    let sck = bit pins sck_pin in
    t.cycle <- t.cycle + 1;
    (* a start bit's fall, not a data bit's *)
    if t.wire = 1
       && wire = 0
       && Option.for_all (Queue.last t.wire_falls) ~f:(fun last ->
         t.cycle - last >= 10 * period)
    then Queue.enqueue t.wire_falls t.cycle;
    if t.sck = 0 && sck = 1 then Queue.enqueue t.rises (t.cycle, bit pins mosi_pin);
    if t.sck = 1 && sck = 0 then Queue.enqueue t.falls t.cycle;
    t.wire <- wire;
    t.sck <- sck
  ;;

  let frames t frames =
    let rises = Queue.to_list t.rises |> List.chunks_of ~length:8 in
    let falls = Queue.to_list t.falls |> List.chunks_of ~length:8 in
    List.zip_with_remainder
      (List.zip_with_remainder (Queue.to_list t.wire_falls) rises |> fst)
      falls
    |> fst
    |> List.zip_with_remainder frames
    |> fst
    |> List.map ~f:(fun ((start, _), ((wire_fall, rises), falls)) ->
      { Frame.stop = start + (9 * period)
      ; wire_fall
      ; first_rise = fst (List.hd_exn rises)
      ; last_fall = List.last_exn falls
      ; byte = List.fold rises ~init:0 ~f:(fun byte (_, b) -> (byte lsl 1) lor b)
      })
  ;;
end

let setup timed =
  { System_lockstep.Setup.config = Timed_program.config timed
  ; program = Timed_program.words timed
  ; preload = []
  ; data = []
  }
;;

let outcome (watch : Watch.t) frames (system : System.t) mismatch =
  { Outcome.frames = Watch.frames watch frames
  ; faults = List.map system.engines ~f:(fun m -> m.fault)
  ; irq = List.map system.engines ~f:(fun m -> m.irq)
  ; mismatch
  }
;;

let model ~cycles frames =
  let watch = Watch.create () in
  let system =
    List.map [ relay; controller ] ~f:(fun timed ->
      let s = setup timed in
      Machine.create ~config:s.config ~program:s.program |> ok_exn)
    |> System.create
  in
  let system =
    List.fold (List.range 0 cycles) ~init:system ~f:(fun system n ->
      let system = System.step system ~pads:(line frames n) in
      Watch.after watch system;
      system)
  in
  outcome watch frames system None
;;

let rtl ~cycles frames =
  let watch = Watch.create () in
  let system, mismatch =
    System_lockstep.run
      ~cycles
      ~react:(Watch.after watch)
      ~pads:(line frames)
      [ setup relay; setup controller ]
  in
  outcome watch frames system mismatch
;;

(* On the Tiny Tapeout top: the host loads engine 1, starts it, loads and starts engine 0,
   then IN0 carries four frames as far apart as the bridge allows *)
let scenario =
  let open Pin_trace in
  let bytes = [ 0xa5; 0x3c; 0x00; 0xff ] in
  let frames = List.mapi bytes ~f:(fun n byte -> 20 + (n * spacing), byte) in
  let load timed =
    Scenario.load
      ~config:(Timed_program.config timed)
      ~program:(Timed_program.words timed)
  in
  { Scenario.name = "bridge"
  ; peer = (fun () -> Peer.idle 1)
  ; script =
      [ Step.Write (Host_port.Reg.select, [ 1 ]) ]
      @ load controller
      @ [ Scenario.start; Write (Host_port.Reg.select, [ 0 ]) ]
      @ load relay
      @ [ Scenario.start
        ; Drive { pin = 0; levels = List.init (20 + (4 * spacing)) ~f:(line frames) }
        ; Read (Host_port.Reg.status, 1)
        ]
  ; sigrok =
      Some
        { clock_hz = 48_000_000
        ; decoders =
            [ Sigrok.decoder
                "uart"
                ~pins:[ "rx", 0 ]
                ~options:[ "baudrate", Int.to_string (48_000_000 / period) ]
            ; Sigrok.decoder "spi" ~pins:[ "clk", sck_pin; "mosi", mosi_pin ]
            ]
        ; expect =
            [ "uart=rx-data", List.map bytes ~f:(sprintf "uart-1: %02X")
            ; "spi=mosi-data", List.map bytes ~f:(sprintf "spi-1: %02X")
            ]
        ; joins_after = None
        ; rejected = None
        ; (* MOSI inverted over the first byte's first rise *)
          teeth = [ [ Flip { pin = mosi_pin; edge = 0; after = 0; cycles = 20 } ] ]
        }
  }
;;
