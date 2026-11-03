open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* LIN Specification Package, Revision 2.2A (LIN Consortium, December 31, 2010): the frame
   of 2.3.1-2.3.2 (pp. 29-33), the bit rate tolerances of Tables 6.1-6.3 (p. 113) *)

(* IO5, open drain: the bus is a wired AND, dominant low. On the bench IO5 is analyser A's
   D7; IO0 reaches no analyser *)
let pin = Isa.first_bidir_pin + 5

let config =
  { Program_config.default with
    in_base = pin
  ; in_count = 1
  ; out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  ; jmp_pin = pin
  }
;;

(* The master: a header, then the slave's response read back a byte a word. The host loads
   half a bit, then per frame the response's bytes less one (checksum included) and the
   PID. [t] steps half a bit; each pin write follows its [wait t+]. A response sampled as
   [Uart.rx_host_rate_on] does; the core already waits at each start edge, so [now] a
   cycle after the wait releases is the edge's cycle and one. *)
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
byte:
    wait 0 pin 17            ; start bit, on IO5
    mov t, now
    add t, p
    add t, p
    add t, p
    sub t, 2                 ; middle of bit 0, less the cycle the sample lands after
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
    jmp y--, byte
    jmp frame
|}
      ~config
      ~period_floor:16]
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
         ~unit:\"baud\" (2 * half)}, on IO5"]
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Floor 16
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

(* The header's timing at the pin, every row the run's: the break is a loop of waits,
   which the kernel counts one pass of. A header runs from the break's fall to the PID's
   start bit, the seventh fall, and its ten bits after (2.3.1, 2.3.2). Single bits, the
   levels under a bit and a half, carry the bit rate. Slave-side, wake up, sleep and
   transport layer rows do not apply to this firmware. *)
let limits =
  let sheet page =
    { Datasheet.Sheet.part = "LIN master"
    ; document = "LIN Specification Package Revision 2.2A"
    ; page
    }
  in
  let tbit = 1e9 /. 19_200. in
  let bit ~clock_hz = clock_hz / 19_200 in
  (* each break, from its low on *)
  let headers ~clock_hz levels =
    let rec from = function
      | [] -> []
      | (false, low) :: _ as rest when low >= 11 * bit ~clock_hz ->
        rest :: from (List.tl_exn rest)
      | _ :: rest -> from rest
    in
    from levels
  in
  let run f = Datasheet.run ~pin:Datasheet.set_pin f in
  let break =
    run (fun ~clock_hz levels ->
      List.map (headers ~clock_hz levels) ~f:(fun header -> snd (List.hd_exn header)))
  and delimiter =
    run (fun ~clock_hz levels ->
      List.filter_map (headers ~clock_hz levels) ~f:(fun header ->
        Option.map (List.nth header 1) ~f:snd))
  and break_field =
    run (fun ~clock_hz levels ->
      List.filter_map (headers ~clock_hz levels) ~f:(function
        | (_, low) :: (_, high) :: _ -> Some (low + high)
        | _ -> None))
  and header =
    run (fun ~clock_hz levels ->
      List.filter_map (headers ~clock_hz levels) ~f:(fun header ->
        let falls =
          List.folding_map header ~init:0 ~f:(fun at (high, cycles) ->
            at + cycles, Option.some_if (not high) at)
          |> List.filter_opt
        in
        Option.map (List.nth falls 6) ~f:(fun pid -> pid + (10 * bit ~clock_hz))))
  and bits =
    run (fun ~clock_hz levels ->
      List.concat_map (headers ~clock_hz levels) ~f:(fun header ->
        List.filter_map (List.tl_exn header) ~f:(fun (_, cycles) ->
          Option.some_if (2 * cycles < 3 * bit ~clock_hz) cycles)))
  in
  let limit parameter limit page bound =
    { Datasheet.firmware = bench.name
    ; parameter
    ; limit
    ; sheet = sheet page
    ; margin = Cycle
    ; bound
    }
  in
  [ limit "break field" (At_least (13. *. tbit)) "2.3.1.1, p. 30" break
  ; limit "break delimiter" (At_least tbit) "2.3.1.1, p. 30" delimiter
  ; limit
      "break field length (dominant + delimiter)"
      (At_least (14. *. tbit))
      "Table 2.3, p. 52"
      break_field
  ; limit
      "THeader_Maximum, 1.4 * THeader_Nominal of 34 TBit"
      (At_most (1.4 *. 34. *. tbit))
      "2.3.2 eq. (3), p. 32, eq. (6), p. 33"
      header
  ; limit "FTOL_RES_MASTER, bit" (At_least (tbit *. 0.995)) "Table 6.1, p. 113" bits
  ; limit "FTOL_RES_MASTER, bit" (At_most (tbit *. 1.005)) "Table 6.1, p. 113" bits
  ; limit "bit rate, 20 kbit/s" (At_least 50_000.) "6.3, p. 112" bits
  ; limit "bit rate, 1 kbit/s" (At_most 1e6) "6.3, p. 112" bits
  ]
;;

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

(* sigrok's lin stacks on its uart, which reads 8N1 at the bit rate. It shows a frame once
   the line idles two byte times; a valid checksum is a data line. *)
let sigrok =
  { Sigrok.clock_hz = trace_hz
  ; decoders =
      [ Sigrok.decoder "uart" ~pins:[ "rx", pin ] ~options:[ "baudrate", "19200" ]
        ^ ","
        ^ Sigrok.decoder "lin"
      ]
  ; expect =
      [ ( "lin=data:control"
        , Sigrok.lines
            "lin"
            ([ "Break condition"
             ; "Sync"
             ; sprintf "ID: %02X Parity: %d (ok)" id (pid id lsr 6)
             ]
             @ List.map data ~f:(sprintf "Data: 0x%02X")
             @ [ sprintf "Checksum: 0x%02X" (enhanced ~pid:(pid id) data) ]) )
      ; (* the break is a uart break and frame error, once each; one more is a fault *)
        ( "uart=rx-warnings:rx-break"
        , Sigrok.lines "uart" [ "Frame error"; "Break condition" ] )
      ]
  ; joins_after = None
  ; rejected = None
  ; teeth =
      [ (* edge 1 ends the break at 8.5 bits, under the uart's 10 for a break *)
        [ Shift { pin; edge = 1; cycles = -5 * trace_bit } ]
      ; (* edge 18 starts the response: its first data bit flipped, the checksum wrong *)
        [ Flip { pin; edge = 18; after = trace_bit; cycles = trace_bit } ]
      ]
  }
;;

(* One frame: the header, then the slave's three bytes and enhanced checksum. The host
   reads the data and leaves the checksum, as a read never empties the fifo. *)
let scenario =
  { Scenario.name = "lin"
  ; peer
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
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
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ "lin", "open drain, which a wire does not show, and it waits for a slave's answer"
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
