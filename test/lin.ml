open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* LIN Specification Package, Revision 2.2A (LIN Consortium, December 31, 2010): the frame
   of 2.3.1-2.3.2 (pp. 29-33), the bit rate tolerances of Tables 6.1-6.3 (p. 113) *)

(* IO0, open drain: the bus is a wired AND, dominant low *)
let pin = Isa.first_bidir_pin

let config =
  { Program_config.default with
    in_base = pin
  ; in_count = 1
  ; out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  ; jmp_pin = pin
  ; capture_pin = pin
  ; capture_rising = false
  }
;;

(* The master: a header, then the slave's response read back a byte a word. The host loads
   half a bit, then per frame the response's bytes less one (checksum included) and the
   PID. [t] steps half a bit; each pin write follows its [wait t+]. A response sampled as
   [Uart.rx_host_rate_on] does, its start edges captured. *)
let firmware =
  [%firmware
    {|
    wait tx
    pull
    mov p, osr               ; half a bit
    set pins, 0              ; the line is only ever pulled low
    set pindirs, 0
frame:
    wait tx
    pull
    mov y, osr               ; response bytes less one
    wait tx
    pull
    mov osr, !osr            ; the PID; a released line is a one
    mov t, now
    add t, p
    wait t+
    set pindirs, 1           ; break, 13.5 bits dominant
    set x, 25
break:
    wait t+
    jmp x--, break
    wait t+
    set pindirs, 0           ; delimiter, 1.5 bits
    wait t+
    wait t+
    set x, 4
sync:
    wait t+
    set pindirs, 1           ; 0x55 with its start bit, a low and a high a pass
    wait t+
    wait t+
    set pindirs, 0
    wait t+
    jmp x--, sync
    wait t+
    set pindirs, 1           ; the PID's start bit
    wait t+
    set x, 7
pid:
    wait t+
    out pindirs, 1
    wait t+
    jmp x--, pid
    wait t+
    set pindirs, 0           ; stop bit
    wait t                   ; its middle: the slave may start only after it ends
arm:
    capture_arm
    wait 0 pin 12            ; start bit, its edge cycle is in capture
    mov t, capture
    add t, p
    add t, p
    add t, p
    sub t, 1                 ; middle of bit 0, less the cycle the sample lands after
    set x, 7
bit:
    wait t+
    in pins, 1
    add t, p
    jmp x--, bit
    in null, 8
    push
    wait t                   ; the middle of the stop bit
    jmp pin, stop
    irq                      ; framing error
    jmp frame
stop:
    jmp y--, arm
    jmp frame
|}
      ~config
      ~period_floor:16
      ~single_capture_edge:true]
;;

(* half a bit at 19200 baud on the bench's 48 MHz *)
let half = Bench.half ~hz:19_200

(* 2.3.1.3: P0 = ID0 ^ ID1 ^ ID2 ^ ID4, P1 = !(ID1 ^ ID3 ^ ID4 ^ ID5) *)
let pid id =
  let b i = (id lsr i) land 1 in
  let p0 = b 0 lxor b 1 lxor b 2 lxor b 4
  and p1 = 1 lxor b 1 lxor b 3 lxor b 4 lxor b 5 in
  id lor (p0 lsl 6) lor (p1 lsl 7)
;;

(* 2.3.1.5: the inverted eight bit sum with carry; enhanced takes the PID in too *)
let checksum bytes =
  let sum =
    List.fold bytes ~init:0 ~f:(fun sum byte ->
      let sum = sum + byte in
      if sum >= 256 then sum - 255 else sum)
  in
  lnot sum land 0xff
;;

let enhanced ~pid data = checksum (pid :: data)

(* The host words of a frame: the response's bytes less one, then the PID. *)
let words ~id ~data = [ List.length data; pid id ]

(* A slave node at the master's bit rate. It takes a dominant run of 11 bits for a break
   (2.3.1.1), samples each byte field mid bit from its start edge, and answers a PID it
   publishes a bit after the PID's stop bit with its data and enhanced checksum. *)
module Slave = struct
  module Field = struct
    type t =
      | Wait_break
      | Sync
      | Pid
      | Responding
    [@@deriving sexp_of, equal]
  end

  type t =
    { clock_hz : int
    ; bit : int
    ; publishes : (int * int list) list
    ; now : int
    ; low : bool
    ; fell : int
    ; rose : int
    ; after_break : bool
    ; field : Field.t
    ; start : int option
    ; bits : int list (* this byte's, last first *)
    ; drive : bool list (* dominant from now on, a cycle each *)
    ; headers : int list
    ; measured : Measured.t
    ; violations : string list
    }

  let create ~clock_hz ~bit ~publishes =
    { clock_hz
    ; bit
    ; publishes
    ; now = 0
    ; low = false
    ; fell = 0
    ; rose = 0
    ; after_break = false
    ; field = Wait_break
    ; start = None
    ; bits = []
    ; drive = []
    ; headers = []
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let drive_low t = List.hd t.drive |> Option.value ~default:false
  let violation t text = { t with violations = text :: t.violations }

  let measure t ~name ~cycles =
    { t with
      measured =
        Measured.add t.measured ~name ~ns:(Measured.ns ~clock_hz:t.clock_hz cycles)
    }
  ;;

  (* the response, a bit after the stop bit that ends at [ends], LSB first *)
  let respond t data ~pid ~ends =
    let bytes = data @ [ enhanced ~pid data ] in
    let bits =
      List.concat_map bytes ~f:(fun byte ->
        (true :: List.init 8 ~f:(fun i -> (byte lsr i) land 1 = 0)) @ [ false ])
    in
    let space = ends + t.bit - t.now in
    { t with
      field = Responding
    ; drive =
        List.init space ~f:(fun _ -> false)
        @ List.concat_map bits ~f:(fun d -> List.init t.bit ~f:(fun _ -> d))
    }
  ;;

  let byte_done t ~start =
    let bits = List.rev t.bits in
    let byte =
      List.foldi (List.sub bits ~pos:1 ~len:8) ~init:0 ~f:(fun i byte b ->
        byte lor (b lsl i))
    in
    let stop = List.last_exn bits = 1 in
    let t = { t with start = None; bits = [] } in
    let t = if stop then t else violation t [%string "framing error at %{t.now#Int}"] in
    match t.field with
    | Sync ->
      let t =
        if byte = 0x55 then t else violation t [%string "sync of 0x%{byte#Int.Hex}"]
      in
      { t with field = Pid }
    | Pid ->
      let t = { t with headers = byte :: t.headers } in
      let id = byte land 0x3f in
      if pid id <> byte
      then { (violation t [%string "parity of PID %{byte#Int}"]) with field = Wait_break }
      else (
        match List.Assoc.find t.publishes id ~equal:Int.equal with
        | Some data -> respond t data ~pid:byte ~ends:(start + (10 * t.bit))
        | None -> { t with field = Wait_break })
    | Wait_break | Responding -> t
  ;;

  (* the levels sampled mid bit: start, eight data bits LSB first, stop *)
  let sample t ~start =
    let at = t.now - start - (t.bit / 2) in
    if at >= 0 && at mod t.bit = 0
    then (
      let t = { t with bits = Bool.to_int (not t.low) :: t.bits } in
      if at / t.bit = 9 then byte_done t ~start else t)
    else t
  ;;

  (* a high inside a frame: the delimiter after the break, else a bit's *)
  let fell t =
    let cycles = t.now - t.rose in
    let t =
      match t.field, t.after_break with
      | _, true -> measure t ~name:"delimiter" ~cycles
      | (Sync | Pid | Responding), false -> measure t ~name:"recessive" ~cycles
      | Wait_break, false -> t
    in
    let t = { t with fell = t.now; after_break = false } in
    match t.field, t.start with
    | (Sync | Pid), None -> { t with start = Some t.now }
    | _ -> t
  ;;

  let rose t =
    let cycles = t.now - t.fell in
    let t = { t with rose = t.now } in
    if cycles >= 11 * t.bit
    then (
      let t = measure t ~name:"break" ~cycles in
      let t =
        if cycles >= 13 * t.bit
        then t
        else violation t [%string "break of %{cycles#Int} cycles"]
      in
      { t with field = Sync; start = None; bits = []; after_break = true })
    else measure t ~name:"dominant" ~cycles
  ;;

  let step t ~low =
    let t =
      match t.low, low with
      | false, true -> fell { t with low }
      | true, false -> rose { t with low }
      | _ -> t
    in
    let t =
      match t.start with
      | Some start -> sample t ~start
      | None -> t
    in
    let t =
      match t.field, t.drive with
      | Responding, [] -> { t with field = Wait_break }
      | _, [] -> t
      | _, _ :: drive -> { t with drive }
    in
    { t with now = t.now + 1 }
  ;;

  let headers t = List.rev t.headers
  let measured t = t.measured
  let violations t = List.rev t.violations
end

let certified = [ Certified.of_firmware ~period:half ~no_wrap:true "lin" firmware ]

(* the header of frame 0x16 at 19200 baud; with no slave on the bench, the run ends
   waiting for the response *)
let bench =
  { Bench.name = "lin"
  ; what =
      [%string
        "Lin.firmware: a master's header, %{half#Int} cycles a half bit for %{Bench.rate \
         ~unit:\"baud\" (2 * half)}, on IO0"]
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Receiver half
  ; clock_hz = Bench.clock_hz
  ; load = Some half
  ; stimulus =
      Some
        { bursts = [ words ~id:0x16 ~data:[ 0; 0; 0 ] ]
        ; quiet = 0
        ; cycles = 50 * 2 * half
        }
  }
;;

(* TODO a row for each parameter of the spec's timing table, then [unlimited] empty. Each
   is bounded by the kernel over every path, [Datasheet.level] or [Datasheet.spacing], or
   by [bench]'s run, [Datasheet.run], which a loop of waits needs as the kernel counts one
   pass of it. For example
   { Datasheet.firmware = bench.name
   ; parameter = "tLOW"
   ; limit = At_least 4700.
   ; sheet = { part = "I2C"; document = "NXP UM10204 Rev. 7.0"; page = "Table 11, p.44" }
   ; margin = Cycle
   ; bound = Datasheet.level ~pin:Datasheet.set_pin ~high:false ()
   } *)
let limits : Datasheet.t list = []

(* 32 cycles a bit at 19200 baud keeps the run short *)
let trace_bit = 32
let trace_hz = trace_bit * 19_200

(* frame 0x16 published by the slave, "LIN" *)
let id = 0x16
let data = [ 0x4c; 0x49; 0x4e ]

let peer () =
  let slave =
    ref (Slave.create ~clock_hz:trace_hz ~bit:trace_bit ~publishes:[ id, data ])
  in
  let low = ref false in
  { Peer.inputs = (fun () -> if !low then 0 else 1 lsl pin)
  ; step =
      (fun ~pin_out:_ ~pin_dir ->
        low := Peer.bit pin_dir pin = 1 || Slave.drive_low !slave;
        slave := Slave.step !slave ~low:!low)
  }
;;

(* sigrok's lin stacks on its uart, which reads 8N1 at the bit rate *)
let sigrok =
  { Sigrok.clock_hz = trace_hz
  ; decoders =
      [ Sigrok.decoder "uart" ~pins:[ "rx", pin ] ~options:[ "baudrate", "19200" ]
        ^ ","
        ^ Sigrok.decoder "lin"
      ]
  ; expect = []
  ; joins_after = None
  ; rejected = None
  ; teeth = []
  }
;;

(* One frame: the header, then the slave's three bytes and enhanced checksum. The host
   reads the data and leaves the checksum, as a read never empties the fifo. *)
let scenario =
  { Scenario.name = "lin"
  ; peer
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Write (Reg.tx, [ trace_bit / 2 ])
        ; Scenario.start
        ; Write (Reg.tx, words ~id ~data)
        ; Run (90 * trace_bit)
        ; Read (Reg.rx, List.length data)
        ; Read (Reg.status, 1)
        ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "lin"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = [ "lin", "TODO the rows of the spec's timing table" ]
  ; swept = []
  ; not_swept = [ "lin", "TODO why the sweep does not stamp it, or a Swept.t" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
