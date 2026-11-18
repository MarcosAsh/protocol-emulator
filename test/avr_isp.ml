open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* Atmel ATmega48/V / 88/V / 168/V datasheet, Atmel-2545W-11/2016: section 32.8
   (pp.377-379) for the algorithm and SCK limits, Table 32-18 (p.380) for the
   instructions. The target is an ATmega88 as shipped, 1 MHz (section 13.2.1), so a CPU
   cycle is 1 us. SCK is 400 cycles at 48 MHz (120 kHz). RESET and SCK start low, as at
   power-up, then a wait of 32769 periods of 30. *)
let sck = 5
let reset = sck + 1
let mosi = 8
let miso = 0
let half = 200

let config =
  { Program_config.default with
    in_base = miso
  ; in_count = 1
  ; out_base = mosi
  ; out_count = 1
  ; set_base = sck
  ; set_count = 2
  ; in_shift = Left
  ; out_shift = Left
  ; autopull = true
  ; pull_threshold = 16
  }
;;

(* An instruction is two host words, its bytes MSB first by autopull, and pushes the last
   16 bits read from MISO, which are its third and fourth bytes. [set pins] drives SCK in
   bit 0 and RESET in bit 1. MISO is read as SCK rises, where sigrok's mode 0 reads it. *)
let firmware =
  [%firmware
    {|
    set pins, 0              ; RESET and SCK low
    set p, 30
    mov t, now
    add t, p
    set y, 16
    add y, y
    add y, y
    add y, y
    add y, y
    add y, y
    add y, y
    add y, y
    add y, y
    add y, y
    add y, y
    add y, y
hold:
    wait t+
    jmp y--, hold            ; at least 20 ms before the first instruction
cmd:
    wait tx
    pull
    set y, 31
    mov t, now
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
bit:
    out pins, 1              ; MOSI while SCK is low
    wait t
    in pins, 1               ; MISO
    set pins, 1              ; SCK rises
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    wait t
    set pins, 0              ; SCK falls
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    jmp y--, bit
    mov pins, null
    push
    jmp cmd
|}
      ~config]
;;

(* [wait tx] can hold the core indefinitely, far behind its last deadline *)
let certified = [ Certified.of_firmware ~no_wrap:true "avr_isp" firmware ]

let instruction = function
  | [ b1; b2; b3; b4 ] -> [ (b1 lsl 8) lor b2; (b3 lsl 8) lor b4 ]
  | bytes -> raise_s [%message "BUG: an instruction is 4 bytes" (bytes : int list)]
;;

let programming_enable = [ 0xac; 0x53; 0x00; 0x00 ]
let read_signature n = [ 0x30; 0x00; n; 0x00 ]
let read_fuse = [ 0x50; 0x00; 0x00; 0x00 ]

(* Section 32.8.2 (p.378): data goes in on SCK's rise and out on its fall. Each reply byte
   echoes the byte before it on MOSI, but for a read's last, which is the data.
   Instructions are taken with RESET low after 20 ms (p.379), with SCK high and low at
   least two CPU cycles. The signature is Table 32-9's (p.368), the fuse the factory low
   fuse. *)
module Atmega88 = struct
  let signature = [ 0x1e; 0x93; 0x0a ]
  let low_fuse = 0x62

  type t =
    { cycle : int
    ; sck : bool
    ; reset : bool
    ; miso : bool
    ; reset_fell : int
    ; sck_rose : int
    ; sck_fell : int
    ; first : bool
    ; previous : int (* the last byte on MOSI *)
    ; bits : bool list (* of the instruction, newest first *)
    ; log : int list list
    ; violations : string list
    }

  (* an edge long before the run *)
  let never = -1_000_000_000

  let create () =
    { cycle = 0
    ; sck = false
    ; reset = true
    ; miso = false
    ; reset_fell = never
    ; sck_rose = never
    ; sck_fell = never
    ; first = false
    ; previous = 0
    ; bits = []
    ; log = []
    ; violations = []
    }
  ;;

  let miso t = t.miso
  let log t = List.rev t.log
  let violations t = List.rev t.violations

  let violate t why =
    { t with violations = [%string "%{why} at %{t.cycle#Int}"] :: t.violations }
  ;;

  let require t ~since ~ns why =
    if Measured.at_least ~clock_hz:Bench.clock_hz (t.cycle - since) ~ns
    then t
    else violate t why
  ;;

  let byte bits = List.fold bits ~init:0 ~f:(fun v b -> (v lsl 1) lor Bool.to_int b)

  let bytes t =
    List.chunks_of (List.rev t.bits) ~length:8
    |> List.filter ~f:(fun chunk -> List.length chunk = 8)
    |> List.map ~f:byte
  ;;

  (* MISO for the next bit, once the bits so far are in *)
  let next_miso t =
    let n = List.length t.bits in
    let bytes = bytes t in
    let reply =
      match bytes with
      | [] -> t.previous
      | _ when n >= 24 ->
        (match bytes with
         | [ 0x30; 0x00; address ] -> List.nth_exn signature (address land 3)
         | [ 0x50; 0x00; 0x00 ] -> low_fuse
         | _ -> List.nth_exn bytes 2)
      | _ -> List.last_exn bytes
    in
    (reply lsr (7 - (n % 8))) land 1 = 1
  ;;

  let step t ~sck ~reset ~mosi =
    let t = { t with cycle = t.cycle + 1 } in
    let t =
      match t.reset, reset with
      | true, false -> { t with reset; reset_fell = t.cycle; first = true; bits = [] }
      | false, true -> { t with reset; bits = [] }
      | _ -> t
    in
    match t.sck, sck with
    | false, true ->
      let t = require t ~since:t.sck_fell ~ns:2_000 "SCK low under 2 CPU clock cycles" in
      let t =
        if t.first && not t.reset
        then (
          let t =
            require t ~since:t.reset_fell ~ns:20_000_000 "SCK within 20 ms of RESET"
          in
          { t with first = false })
        else t
      in
      let t = if t.reset then t else { t with bits = mosi :: t.bits } in
      { t with sck; sck_rose = t.cycle }
    | true, false ->
      let t = require t ~since:t.sck_rose ~ns:2_000 "SCK high under 2 CPU clock cycles" in
      let t =
        if List.length t.bits = 32
        then (
          let bytes = bytes t in
          { t with log = bytes :: t.log; bits = []; previous = List.last_exn bytes })
        else t
      in
      { t with sck; sck_fell = t.cycle; miso = next_miso t }
    | _ -> t
  ;;
end

let peer () =
  let device = ref (Atmega88.create ()) in
  { Peer.inputs = (fun () -> Bool.to_int (Atmega88.miso !device) lsl miso)
  ; step =
      (fun ~pin_out ~pin_dir:_ ->
        let level pin = Peer.bit pin_out pin = 1 in
        device
        := Atmega88.step !device ~sck:(level sck) ~reset:(level reset) ~mosi:(level mosi))
  }
;;

(* enable programming, read the signature, then the low fuse *)
let instructions =
  [ programming_enable; read_signature 0; read_signature 1; read_signature 2; read_fuse ]
;;

let words = List.concat_map instructions ~f:instruction

let bench =
  { Bench.name = "avr_isp"
  ; what =
      "Avr_isp.firmware: SCK on OUT0, RESET on OUT1, MOSI on OUT3 and MISO on IN0, SCK \
       at 120 kHz; RESET low and a wait of 20.5 ms, then programming enable, the three \
       signature bytes and the low fuse"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus = Some { bursts = [ words ]; quiet = 0; cycles = 1_100_000 }
  }
;;

let limits =
  let sheet ~page =
    { Datasheet.Sheet.part = "ATmega48/88/168, shipped at 1 MHz"
    ; document =
        "Atmel, ATmega48/V / 88/V / 168/V datasheet complete, Atmel-2545W, November 2016"
    ; page
    }
  in
  let sck_pin = Datasheet.set_pin in
  let row ~page parameter limit bound =
    { Datasheet.firmware = "avr_isp"
    ; parameter
    ; limit
    ; sheet = sheet ~page
    ; margin = Cycle
    ; bound
    }
  in
  [ row
      ~page:"section 32.8, p.378"
      "SCK high, more than 2 CPU clock cycles"
      (At_least 2_000.)
      (Datasheet.level ~pin:sck_pin ~high:true ())
  ; row
      ~page:"section 32.8, p.378"
      "SCK low, more than 2 CPU clock cycles"
      (At_least 2_000.)
      (Datasheet.level ~pin:sck_pin ~high:false ())
  ; row
      ~page:"section 32.8.2 step 2, p.379"
      "wait after power-up, RESET and SCK low, before programming enable"
      (At_least 20e6)
      (Datasheet.run ~pin:sck_pin (fun ~clock_hz:_ levels ->
         match levels with
         | (false, wait) :: _ -> [ wait ]
         | _ -> []))
  ]
;;

(* sigrok's spi in mode 0 with no chip select, under its avr_isp, which names the device
   from the signature. The spi lines are each instruction's bytes on MOSI and the reply on
   MISO, which echoes the byte before it but for a read's last. The teeth flip the first
   MOSI bit, so the programming enable reads 0x2C, and the first MISO bit, so its echo of
   0xAC reads 0x2C. *)
let sigrok =
  let hex = sprintf "spi-1: %02X" in
  let line = sprintf "avr_isp-1: %s" in
  let data = function
    | [ 0x30; 0x00; address; _ ] -> Some (List.nth_exn Atmega88.signature address)
    | [ 0x50; 0x00; 0x00; _ ] -> Some Atmega88.low_fuse
    | _ -> None
  in
  let replies =
    List.folding_map instructions ~init:0 ~f:(fun previous bytes ->
      let reply =
        match bytes, data bytes with
        | [ b1; b2; _; _ ], Some data -> [ previous; b1; b2; data ]
        | [ b1; b2; b3; _ ], None -> [ previous; b1; b2; b3 ]
        | _ -> raise_s [%message "BUG: an instruction is 4 bytes" (bytes : int list)]
      in
      List.last_exn bytes, reply)
  in
  { Sigrok.clock_hz = 48_000_000
  ; decoders =
      [ Sigrok.decoder "spi" ~pins:[ "clk", sck; "mosi", mosi; "miso", miso ]
        ^ ","
        ^ Sigrok.decoder "avr_isp"
      ]
  ; expect =
      [ "spi=mosi-data", List.concat_map instructions ~f:(List.map ~f:hex)
      ; "spi=miso-data", List.concat_map replies ~f:(List.map ~f:hex)
      ; ( "avr_isp=pe:rsb0:rsb1:rsb2:rfb:dev"
        , List.map
            ~f:line
            [ "Programming enable"
            ; sprintf "Vendor code: 0x%02x (Atmel)" (List.nth_exn Atmega88.signature 0)
            ; sprintf
                "Part family / memory size: 0x%02x"
                (List.nth_exn Atmega88.signature 1)
            ; sprintf "Part number: 0x%02x" (List.nth_exn Atmega88.signature 2)
            ; "Device: Atmel ATmega88"
            ; sprintf "Read fuse bits: 0x%02x" Atmega88.low_fuse
            ] )
      ]
  ; joins_after = None
  ; rejected = None
  ; teeth =
      [ [ Flip { pin = mosi; edge = 0; after = 0; cycles = 2 * half } ]
      ; [ Flip { pin = miso; edge = 0; after = 0; cycles = 2 * half } ]
      ]
  }
;;

let scenario =
  { Scenario.name = "avr_isp"
  ; peer
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ [ Scenario.start; Write (Reg.tx, words); Run 1_100_000 ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "avr_isp"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ "avr_isp", "RESET is held low 983070 cycles, past the 65536 a stamp tells apart" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
