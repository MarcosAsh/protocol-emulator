open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* National Semiconductor AN-452, MICROWIRE Serial Interface (January 1992): Table I (p.5)
   for the five devices, notes 1-2 and Figure 9 (p.6) for the NM93C06A, and the COP494
   listing (p.10). At 48 MHz SK is 310 cycles (154.8 kHz, 6.46 us), high 155 then low

   155. DI moves 42 after a fall, CS rises 2 SK highs before the first rise and falls one
   after the last fall. An erase/write frame then holds CS low 25.94 ms. *)

let di = 9
let sk = 10
let cs = 11
let do_ = 0
let half = 155

let config =
  { Program_config.default with
    in_base = do_
  ; in_count = 1
  ; out_base = di
  ; out_count = 1
  ; set_base = sk
  ; set_count = 2
  ; in_shift = Left
  ; out_shift = Left
  ; autopull = true
  ; pull_threshold = 16
  }
;;

(* A frame is a header word, bit 15 erase/write and the rest its bits less one, then its
   bits MSB first, 16 a word, which autopull takes. [set pins] drives SK in bit 0 and CS
   in bit 1. DO is sampled after each fall, where sigrok reads it, and the frame's last 16
   samples are pushed. [t] is the next rise on entry to [bit]. An erase/write frame holds
   CS low 65536 waits of 19 cycles from a p after its fall, then high two SK highs with no
   clock, the status window, then low. *)
let firmware =
  [%firmware
    {|
    set pins, 0              ; CS and SK low
    mov pins, null           ; DI low
    set p, 31
idle:
    wait tx
    pull
    out x, 1                 ; erase/write
    out y, 15                ; bits less one
    mov isr, null
    set pins, 2              ; CS rises
    mov t, now
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    wait t
    out pins, 1              ; the start bit, an SK high after CS
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
bit:
    wait t+
    set pins, 3              ; SK rises
    add t, p
    add t, p
    add t, p
    add t, p
    wait t+
    set pins, 2              ; SK falls
    in pins, 1 [3]           ; DO
    add t, p
    add t, p
    add t, p
    add t, p [31]
    jmp y--, next
    mov pins, null           ; DI low, 42 after the last fall
    wait t+
    set pins, 0              ; CS falls an SK high after the last fall
    push
    jmp x--, pulse
rest:
    set x, 1
rest_half:
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    wait t
    jmp x--, rest_half       ; CS low a whole SK period at least
    jmp idle
next:
    out pins, 1              ; DI, 42 after the fall
    jmp bit
pulse:
    mov y, !null
pulse_wait:
    add t, 7
    add t, 7
    add t, 5
    wait t
    jmp y--, pulse_wait
    set pins, 2              ; the status window
    set x, 1
status:
    add t, p
    add t, p
    add t, p
    add t, p
    add t, p
    wait t
    jmp x--, status
    set pins, 0
    jmp rest
|}
      ~config]
;;

let certified = [ Certified.of_firmware "microwire" firmware ]

let frame ?(erase_write = false) bits =
  let n = List.length bits in
  let data =
    List.chunks_of bits ~length:16
    |> List.map ~f:(fun chunk ->
      List.foldi chunk ~init:0 ~f:(fun i word bit ->
        if bit then word lor (1 lsl (15 - i)) else word))
  in
  ((Bool.to_int erase_write lsl 15) lor (n - 1)) :: data
;;

let bits_of ~width value =
  List.init width ~f:(fun i -> (value lsr (width - 1 - i)) land 1 = 1)
;;

(* p.6's instruction set: the start bit, two opcode bits and six more *)
let instruction ~op ~field = bits_of ~width:9 ((1 lsl 8) lor (op lsl 6) lor field)
let ewen_bits = instruction ~op:0b11 ~field:0b000001

(* the 16 data bits the device drives after a dummy 0 *)
let read_bits address =
  instruction ~op:0b00 ~field:address @ List.init 16 ~f:(fun _ -> false)
;;

let write_bits address value =
  instruction ~op:0b10 ~field:address @ bits_of ~width:16 value
;;

let ewen = frame ewen_bits
let read address = frame (read_bits address)
let write address value = frame ~erase_write:true (write_bits address value)
let cycles_ms ms = Float.iround_nearest_exn (ms *. Float.of_int Bench.clock_hz /. 1e3)

(* The NM93C06A as p.6 has it: 16 registers of 16 bits, shifted on SK's rise. READ drives
   a dummy 0 at its last address bit, then the register MSB first, then DI. An erase or
   write is done if enabled and CS then stays low 10 to 30 ms (note 2). DO is 1 otherwise:
   ready, or let go and pulled up. *)
module Eeprom = struct
  type t =
    { cs : bool
    ; sk : bool
    ; cycle : int
    ; started : bool
    ; bits : bool list (* after the start bit, newest first *)
    ; out : bool list
    ; dout : bool
    ; registers : int list
    ; enabled : bool
    ; pending : (string * (int list -> int list)) option
    ; fell : int
    ; log : string list (* newest first *)
    ; violations : string list
    }

  let create () =
    { cs = false
    ; sk = false
    ; cycle = 0
    ; started = false
    ; bits = []
    ; out = []
    ; dout = true
    ; registers = List.init 16 ~f:(fun i -> i * 0x1111)
    ; enabled = false
    ; pending = None
    ; fell = 0
    ; log = []
    ; violations = []
    }
  ;;

  let dout t = (not t.cs) || t.dout
  let log t = List.rev t.log
  let violations t = List.rev t.violations
  let registers t = t.registers
  let note t line = { t with log = line :: t.log }

  let violate t why =
    { t with violations = [%string "%{why} at %{t.cycle#Int}"] :: t.violations }
  ;;

  let value bits = List.fold bits ~init:0 ~f:(fun v b -> (v lsl 1) lor Bool.to_int b)

  let set ~address ~data registers =
    List.mapi registers ~f:(fun i r -> if i = address then data else r)
  ;;

  let erase_write t what f =
    if t.enabled
    then { t with pending = Some (what, f) }
    else note t [%string "%{what} ignored, not enabled"]
  ;;

  (* the instruction once its bits are in: 8 after the start bit, or 24 with data *)
  let decode t =
    let bits = List.rev t.bits in
    let n = List.length bits in
    let op = value (List.take bits 2)
    and field = value (List.take (List.drop bits 2) 6) in
    let address = field land 0xf in
    let data () = value (List.drop bits 8) in
    match op, n with
    | 0b00, 8 ->
      let r = List.nth_exn t.registers address in
      let t = note t [%string "READ %{address#Int}: %{sprintf \"%04X\" r}"] in
      { t with dout = false; out = bits_of ~width:16 r }
    | 0b10, 24 ->
      let data = data () in
      erase_write
        t
        [%string "WRITE %{address#Int} %{sprintf \"%04X\" data}"]
        (set ~address ~data)
    | 0b01, 8 ->
      erase_write t [%string "ERASE %{address#Int}"] (set ~address ~data:0xffff)
    | 0b11, 8 when field = 0b000001 -> note { t with enabled = true } "EWEN"
    | 0b11, 8 when field = 0b000010 -> note { t with enabled = false } "ENDS"
    | 0b11, 24 when field = 0b000100 ->
      let data = data () in
      erase_write
        t
        [%string "WRAL %{sprintf \"%04X\" data}"]
        (List.map ~f:(fun _ -> data))
    | 0b11, 8 when field = 0b000101 ->
      erase_write t "ERAL" (List.map ~f:(fun _ -> 0xffff))
    | _ -> t
  ;;

  let rise t ~di =
    let t =
      match t.out with
      | bit :: out -> { t with dout = bit; out }
      | [] ->
        if t.started && List.length t.bits >= 8 && not t.dout
        then { t with dout = di }
        else t
    in
    if not t.started
    then { t with started = di }
    else if List.length t.bits >= 24
    then t
    else decode { t with bits = di :: t.bits }
  ;;

  let select t =
    let t =
      match t.pending with
      | None -> t
      | Some (what, f) ->
        let low = t.cycle - t.fell in
        let ms = Float.of_int low *. 1e3 /. Float.of_int Bench.clock_hz in
        if low < cycles_ms 10. || low > cycles_ms 30.
        then violate t [%string "%{what} with CS low %{sprintf \"%.3f\" ms} ms"]
        else
          note
            { t with registers = f t.registers }
            [%string "%{what} done, CS low %{sprintf \"%.3f\" ms} ms"]
    in
    { t with
      cs = true
    ; started = false
    ; bits = []
    ; out = []
    ; dout = true
    ; pending = None
    }
  ;;

  let deselect t =
    let t = if t.sk then violate t "CS fell with SK high" else t in
    { t with cs = false; fell = t.cycle }
  ;;

  (* the pins after a cycle *)
  let step t ~cs ~sk ~di =
    let t = { t with cycle = t.cycle + 1 } in
    let t =
      match t.cs, cs with
      | false, true -> select t
      | true, false -> deselect t
      | _ -> t
    in
    if Bool.equal sk t.sk
    then t
    else (
      let t = { t with sk } in
      if not cs then violate t "SK moved with CS low" else if sk then rise t ~di else t)
  ;;
end

let peer () =
  let device = ref (Eeprom.create ()) in
  { Peer.inputs = (fun () -> Bool.to_int (Eeprom.dout !device) lsl do_)
  ; step =
      (fun ~pin_out ~pin_dir:_ ->
        let level pin = Peer.bit pin_out pin = 1 in
        device := Eeprom.step !device ~cs:(level cs) ~sk:(level sk) ~di:(level di))
  }
;;

(* enable, read register 5, write it, and once the write's CS low is over read it back *)
let frames = [ ewen; read 5; write 5 0xa5c3; read 5 ]

let bench =
  { Bench.name = "microwire"
  ; what =
      "Microwire.firmware: CS on OUT6, SK on OUT5, DI on OUT4, DO on IN0, SK at 154.8 \
       kHz; EWEN, READ 5, WRITE 5 with CS then low 25.94 ms and a status window, READ 5"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus = Some { bursts = frames; quiet = 0; cycles = 1_300_000 }
  }
;;

(* SK's rises inside a frame, rise to rise: a low longer than two highs is the idle
   between frames, where SK stops. A CS low after an erase/write is one the status window
   ends: a high under 3 SK highs, as a frame's is 4 at least. *)
let limits =
  let sheet ~part page =
    { Datasheet.Sheet.part
    ; document = "National Semiconductor AN-452, MICROWIRE Serial Interface, January 1992"
    ; page
    }
  in
  let sk_pin = Datasheet.set_pin
  and cs_pin config = Datasheet.set_pin config + 1
  and di_pin (config : Program_config.t) = config.out_base in
  let periods =
    Datasheet.run ~pin:sk_pin (fun ~clock_hz:_ levels ->
      List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, h), (_, l)) ->
        Option.some_if (high && l < 2 * h) (h + l)))
  in
  let erase_write_lows =
    Datasheet.run ~pin:cs_pin (fun ~clock_hz:_ levels ->
      List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, l), (_, h)) ->
        Option.some_if ((not high) && h < 3 * half) l))
  in
  let spacing ~a ~b ~apart =
    Datasheet.Bound.Kernel
      (fun config -> Datasheet.spacing ~a:(a config) ~b:(b config) ~apart ())
  in
  (* before SK's rise, since DI's last edge; DI's edges since SK's last, either way *)
  let di_setup = spacing ~a:sk_pin ~b:di_pin ~apart:(fun ~own ~other:_ -> not own)
  and di_hold = spacing ~a:di_pin ~b:sk_pin ~apart:(fun ~own:_ ~other:_ -> true)
  and cs_setup =
    spacing ~a:sk_pin ~b:cs_pin ~apart:(fun ~own ~other -> (not own) && other)
  and cs_hold = spacing ~a:cs_pin ~b:sk_pin ~apart:(fun ~own ~other:_ -> own) in
  let limit ~part ~page parameter limit bound =
    { Datasheet.firmware = "microwire"
    ; parameter
    ; limit
    ; sheet = sheet ~part page
    ; margin = Cycle
    ; bound
    }
  in
  let table = "Table I, p.5" in
  let device part ~sk_max ?sk_min ~di_setup_ns ?di_hold_ns ~cs_setup_ns ?cs_hold_ns () =
    let row = limit ~part ~page:table in
    List.filter_opt
      [ Some (row "SK clock range" (At_least (1e6 /. sk_max)) periods)
      ; Option.map sk_min ~f:(fun khz ->
          row "SK clock range" (At_most (1e6 /. khz)) periods)
      ; Some (row "Write data DI setup" (At_least di_setup_ns) di_setup)
      ; Option.map di_hold_ns ~f:(fun ns ->
          row "Write data DI hold" (At_least ns) di_hold)
      ; Some (row "Chip enable setup" (At_least cs_setup_ns) cs_setup)
      ; Option.map cs_hold_ns ~f:(fun ns -> row "Chip enable hold" (At_least ns) cs_hold)
      ]
  in
  device
    "DS8908"
    ~sk_max:625.
    ~di_setup_ns:300.
    ~di_hold_ns:800.
    ~cs_setup_ns:300.
    ~cs_hold_ns:800.
    ()
  @ device "MM545X" ~sk_max:500. ~di_setup_ns:300. ~cs_setup_ns:400. ()
  @ device
      "COP472-3"
      ~sk_max:250.
      ~sk_min:4.
      ~di_setup_ns:1_000.
      ~di_hold_ns:100.
      ~cs_setup_ns:1_000.
      ~cs_hold_ns:1_000.
      ()
  @ device
      "COP430 (ADC83X)"
      ~sk_max:200.
      ~sk_min:10.
      ~di_setup_ns:200.
      ~di_hold_ns:200.
      ~cs_setup_ns:200.
      ~cs_hold_ns:200.
      ()
  (* its chip enable hold of 0 asks nothing *)
  @ device "NM93C06A" ~sk_max:250. ~di_setup_ns:400. ~di_hold_ns:400. ~cs_setup_ns:200. ()
  @ [ limit
        ~part:"NM93C06A"
        ~page:"p.6, note 1"
        "SK clock frequency"
        (At_least 4_000.)
        periods
    ; limit
        ~part:"NM93C06A"
        ~page:"p.6, note 1 and Figure 9"
        "SK clock high time"
        (At_least 1_000.)
        (Datasheet.level ~pin:sk_pin ~high:true ())
    ; limit
        ~part:"COP420"
        ~page:"p.6, note 1: the SK period"
        "instruction cycle time"
        (At_least 4_000.)
        periods
    ; limit
        ~part:"COP420"
        ~page:"p.6, note 1: the SK period"
        "instruction cycle time"
        (At_most 10_000.)
        periods
    ; limit
        ~part:"NM93C06A"
        ~page:"p.6, note 2"
        "CS low period following an E/W instruction"
        (At_least 10e6)
        erase_write_lows
    ; limit
        ~part:"NM93C06A"
        ~page:"p.6, note 2"
        "CS low period following an E/W instruction"
        (At_most 30e6)
        erase_write_lows
    ; limit
        ~part:"COP494"
        ~page:"p.10, listing line 83"
        "TWE, VPP width"
        (At_least 20e6)
        erase_write_lows
    ]
;;

(* The scenario's frames: sigrok reads DI at each rise after the start bit, and DO at the
   fall after it, 1 but for READ's dummy 0 and register 5's 5555 *)
let sigrok =
  let frames = [ ewen_bits; read_bits 5; write_bits 5 0xa5c3 ] in
  let ones n = List.init n ~f:(fun _ -> true) in
  let bit name b = sprintf "%s bit: %d" name (Bool.to_int b) in
  { Sigrok.clock_hz = 48_000_000
  ; decoders =
      [ Sigrok.decoder "microwire" ~pins:[ "cs", cs; "sk", sk; "si", di; "so", do_ ] ]
  ; expect =
      [ ( "microwire=start-bit:si-bit"
        , List.concat_map frames ~f:(fun bits ->
            "Start bit" :: List.map (List.tl_exn bits) ~f:(bit "SI"))
          |> Sigrok.lines "microwire" )
      ; ( "microwire=so-bit"
        , ones 8 @ ones 7 @ [ false ] @ bits_of ~width:16 0x5555 @ ones 24
          |> List.map ~f:(bit "SO")
          |> Sigrok.lines "microwire" )
      ]
  ; joins_after = None
  ; rejected = None
  ; (* the start bit low over its rise, and EWEN's CS fall two bits early *)
    teeth =
      [ [ Flip { pin = di; edge = 0; after = 0; cycles = 2 * half } ]
      ; [ Shift { pin = cs; edge = 1; cycles = -4 * half } ]
      ]
  }
;;

let scenario =
  { Scenario.name = "microwire"
  ; peer
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ [ Write (Reg.tx, List.concat [ ewen; read 5; write 5 0xa5c3 ])
        ; Scenario.start
        ; Run 22_000
        ; Read (Reg.rx, 3)
        ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "microwire"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "microwire"
        , "an erase/write holds CS low 1245217 cycles, past the 65536 a stamp tells apart"
        )
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
