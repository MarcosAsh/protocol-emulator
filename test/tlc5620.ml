open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* TI TLC5620C/I, SLAS081E (November 2001): the serial word and update modes on p.3, the
   limits in the recommended operating conditions on p.6. CLK is 60 cycles at 48 MHz (800
   kHz), DATA moves 20 before each fall and holds 20 after, LOAD and LDAC pulse 20. *)
let clk = 5
let load = clk + 1
let ldac = clk + 2
let data = clk + 3

let config =
  { Program_config.default with
    out_base = data
  ; out_count = 1
  ; set_base = clk
  ; set_count = 3
  ; out_shift = Left
  }
;;

(* A host word is bit 15 to pulse LDAC alone, else the 11 bits A1 A0 RNG D7-D0 in its low
   bits. [set pins] drives CLK in bit 0, LOAD in 1 and LDAC in 2. *)
let firmware =
  [%firmware
    {|
    set pins, 6              ; CLK low, LOAD and LDAC high
    set p, 20
idle:
    wait tx
    pull
    out x, 1
    out null, 4
    set y, 10
    mov t, now
    add t, p
    jmp x--, pulse
bit:
    wait t+
    out pins, 1              ; DATA while CLK is low
    wait t+
    set pins, 7              ; CLK rises
    wait t+
    set pins, 6              ; CLK falls, which shifts DATA in
    jmp y--, bit
    wait t+
    set pins, 4              ; LOAD low after the eleventh fall
    wait t+
    set pins, 6
    jmp idle
pulse:
    wait t+
    set pins, 2              ; LDAC low
    wait t+
    set pins, 6
    jmp idle
|}
      ~config]
;;

(* [wait tx] can hold the core indefinitely, far behind its last deadline *)
let certified = [ Certified.of_firmware ~no_wrap:true "tlc5620" firmware ]
let command ~dac ~range code = (dac lsl 9) lor (Bool.to_int range lsl 8) lor code
let update = 0x8000

(* Table 2 (p.4): four DACs, each with a range bit and 8 bits. LOAD stores a word and a
   later LDAC low moves all four outputs. *)
module Dac = struct
  type t =
    { cycle : int
    ; clk : bool
    ; data : bool
    ; load : bool
    ; ldac : bool
    ; changed : int (* DATA's last edge *)
    ; fell : int (* CLK's last fall *)
    ; rose : int (* CLK's last rise *)
    ; load_edge : int
    ; ldac_edge : int
    ; bits : bool list (* newest first *)
    ; stored : int list
    ; outputs : int list
    ; violations : string list
    }

  (* an edge long before the run *)
  let never = -1_000_000

  let create () =
    { cycle = 0
    ; clk = false
    ; data = false
    ; load = true
    ; ldac = true
    ; changed = never
    ; fell = never
    ; rose = never
    ; load_edge = never
    ; ldac_edge = never
    ; bits = []
    ; stored = [ 0; 0; 0; 0 ]
    ; outputs = [ 0; 0; 0; 0 ]
    ; violations = []
    }
  ;;

  let outputs t = t.outputs
  let violations t = List.rev t.violations

  let violate t why =
    { t with violations = [%string "%{why} at %{t.cycle#Int}"] :: t.violations }
  ;;

  let require t ~since ~ns why =
    if Measured.at_least ~clock_hz:Bench.clock_hz (t.cycle - since) ~ns
    then t
    else violate t why
  ;;

  let value bits = List.fold bits ~init:0 ~f:(fun v b -> (v lsl 1) lor Bool.to_int b)

  let store t =
    let bits = List.rev (List.take t.bits 11) in
    if List.length bits < 11
    then violate t "LOAD with fewer than 11 clocks"
    else (
      let dac = value (List.take bits 2)
      and range = Bool.to_int (List.nth_exn bits 2)
      and code = value (List.drop bits 3) in
      { t with
        stored =
          List.mapi t.stored ~f:(fun n old -> if n = dac then code * (1 + range) else old)
      })
  ;;

  let step t ~clk ~data ~load ~ldac =
    let t = { t with cycle = t.cycle + 1 } in
    let t =
      if Bool.equal data t.data
      then t
      else (
        let t =
          if t.clk
          then t
          else require t ~since:t.fell ~ns:50 "DATA valid under 50 ns after CLK falls"
        in
        { t with data; changed = t.cycle })
    in
    let t =
      match t.clk, clk with
      | false, true ->
        let t = require t ~since:t.rose ~ns:1_000 "CLK period under 1 us" in
        { t with clk; rose = t.cycle }
      | true, false ->
        let t = require t ~since:t.changed ~ns:50 "DATA setup under 50 ns" in
        let t = require t ~since:t.load_edge ~ns:50 "LOAD rose under 50 ns before CLK" in
        { t with clk; fell = t.cycle; bits = t.data :: t.bits }
      | _ -> t
    in
    let t =
      match t.load, load with
      | true, false ->
        let t =
          require t ~since:t.fell ~ns:50 "CLK's last fall under 50 ns before LOAD"
        in
        { (store t) with load; load_edge = t.cycle; bits = [] }
      | false, true ->
        let t = require t ~since:t.load_edge ~ns:250 "LOAD low under 250 ns" in
        { t with load; load_edge = t.cycle }
      | _ -> t
    in
    match t.ldac, ldac with
    | true, false -> { t with ldac; ldac_edge = t.cycle; outputs = t.stored }
    | false, true ->
      let t = require t ~since:t.ldac_edge ~ns:250 "LDAC low under 250 ns" in
      { t with ldac }
    | _ -> t
  ;;
end

let peer () =
  let dac = ref (Dac.create ()) in
  { Peer.inputs = (fun () -> 0)
  ; step =
      (fun ~pin_out ~pin_dir:_ ->
        let level pin = Peer.bit pin_out pin = 1 in
        dac
        := Dac.step
             !dac
             ~clk:(level clk)
             ~data:(level data)
             ~load:(level load)
             ~ldac:(level ldac))
  }
;;

(* DACA at half scale, DACB 0x40 at 2x, DACC full scale, DACD 1, then all four at once *)
let words =
  [ command ~dac:0 ~range:false 0x80
  ; command ~dac:1 ~range:true 0x40
  ; command ~dac:2 ~range:false 0xff
  ; command ~dac:3 ~range:false 0x01
  ; update
  ]
;;

let bench =
  { Bench.name = "tlc5620"
  ; what =
      "Tlc5620.firmware: CLK on OUT0, LOAD on OUT1, LDAC on OUT2 and DATA on OUT3, CLK \
       at 800 kHz; four DAC words, then an LDAC pulse"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus = Some { bursts = [ words ]; quiet = 0; cycles = 4_000 }
  }
;;

(* CLK is judged rise to rise. tsu(LOAD-LDAC) is 0, which asks nothing. *)
let limits =
  let sheet =
    { Datasheet.Sheet.part = "TLC5620C, TLC5620I"
    ; document =
        "Texas Instruments, TLC5620C, TLC5620I Quadruple 8-Bit Digital-to-Analog \
         Converters, SLAS081E, November 2001"
    ; page = "p.6, recommended operating conditions"
    }
  in
  let clk_pin = Datasheet.set_pin
  and load_pin config = Datasheet.set_pin config + 1
  and ldac_pin config = Datasheet.set_pin config + 2
  and data_pin (config : Program_config.t) = config.out_base in
  let periods =
    Datasheet.run ~pin:clk_pin (fun ~clock_hz:_ levels ->
      List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, h), (_, l)) ->
        Option.some_if high (h + l)))
  in
  let spacing ~a ~b ~apart =
    Datasheet.Bound.Kernel
      (fun config -> Datasheet.spacing ~a:(a config) ~b:(b config) ~apart ())
  in
  let row parameter limit bound =
    { Datasheet.firmware = "tlc5620"; parameter; limit; sheet; margin = Cycle; bound }
  in
  [ row "CLK frequency, at most 1 MHz" (At_least 1_000.) periods
  ; row
      "Setup time, data input, tsu(DATA-CLK)"
      (At_least 50.)
      (spacing ~a:clk_pin ~b:data_pin ~apart:(fun ~own ~other:_ -> own))
  ; row
      "Valid time, data input valid after CLK falls, tv(DATA-CLK)"
      (At_least 50.)
      (spacing ~a:data_pin ~b:clk_pin ~apart:(fun ~own:_ ~other -> not other))
  ; row
      "Setup time, CLK eleventh falling edge to LOAD, tsu(CLK-LOAD)"
      (At_least 50.)
      (spacing ~a:load_pin ~b:clk_pin ~apart:(fun ~own ~other -> own && not other))
  ; row
      "Setup time, LOAD rises to CLK falls, tsu(LOAD-CLK)"
      (At_least 50.)
      (spacing ~a:clk_pin ~b:load_pin ~apart:(fun ~own ~other -> own && other))
  ; row
      "Pulse duration, LOAD, tw(LOAD)"
      (At_least 250.)
      (Datasheet.level ~pin:load_pin ~high:false ())
  ; row
      "Pulse duration, LDAC, tw(LDAC)"
      (At_least 250.)
      (Datasheet.level ~pin:ldac_pin ~high:false ())
  ]
;;

(* sigrok's tlc5620 at its default 3.3 V references. It reads DATA at every CLK fall and
   shows a word when LOAD falls: the fields, the 11 bits, then the register write. The
   LDAC fall shows all four outputs. The teeth flip DATA's first one bit, so DACA reads 0,
   and pull LOAD's first fall 100 cycles early, 11 clocks short. *)
let sigrok =
  let vref = 3.3 in
  let volts code ~range = sprintf "%.2fV" (vref *. Float.of_int code /. 256. *. range) in
  let words = List.take words 4 in
  let fields word =
    (word lsr 9) land 3, Float.of_int (1 + ((word lsr 8) land 1)), word land 0xff
  in
  let name dac = sprintf "DAC%c" (Char.of_int_exn (Char.to_int 'A' + dac)) in
  let write word =
    let dac, range, code = fields word in
    [ sprintf "DAC select: %s" (name dac)
    ; sprintf "Gain: x%.0f" range
    ; sprintf "DAC value: %d" code
    ]
    @ List.init 11 ~f:(fun n -> Int.to_string ((word lsr (10 - n)) land 1))
    @ [ "Falling edge on LOAD"
      ; sprintf "Setting %s register value to %s" (name dac) (volts code ~range)
      ]
  in
  let updated =
    List.map words ~f:(fun word ->
      let dac, range, code = fields word in
      sprintf "%s=%s" (name dac) (volts code ~range))
  in
  { Sigrok.clock_hz = 48_000_000
  ; decoders =
      [ Sigrok.decoder
          "tlc5620"
          ~pins:[ "clk", clk; "data", data; "load", load; "ldac", ldac ]
      ]
  ; expect =
      [ ( "tlc5620=dac-select:gain:value:bit:data-latch:reg-write:voltage-update-all"
        , Sigrok.lines
            "tlc5620"
            (List.concat_map words ~f:write
             @ [ "Updating voltages: " ^ String.concat ~sep:" " updated ]) )
      ]
  ; joins_after = None
  ; rejected = None
  ; teeth =
      [ [ Flip { pin = data; edge = 0; after = 0; cycles = 60 } ]
      ; [ Shift { pin = load; edge = 1; cycles = -100 } ]
      ]
  }
;;

let scenario =
  { Scenario.name = "tlc5620"
  ; peer
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ [ Scenario.start; Write (Reg.tx, words); Run 4_000 ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "tlc5620"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ "tlc5620", "a word waits on the host, so there is no fixed edge to stamp" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
