open! Core
open Protocol_emulator

let pin = 12
let cycle_ns = 20
let standard_unit = 6_000 / cycle_ns

let config =
  { Program_config.default with
    in_base = pin
  ; out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  }
;;

(* host word: bit 0 asks for a reset, otherwise bits 8 to 1 are the byte, LSB first *)
let firmware =
  [%firmware
    {|
    wait tx
    pull
    mov p, osr               ; the unit
idle:
    wait tx
    pull
    out y, 1
    mov t, now
    add t, p
    jmp y--, reset
    set x, 7
slot:
    wait t+
    set pindirs, 1           ; the slot starts
    out y, 1
    wait t+
    mov pindirs, !y          ; 1 unit: a one or a read lets go
    wait t+
    in pins, 1               ; 2 units: sample
    set y, 7
hold:
    wait t+
    jmp y--, hold
    wait t+
    set pindirs, 0           ; 11 units: a zero lets go
    jmp x--, slot
    in null, 8
    push
    jmp idle
reset:
    wait t+
    set pindirs, 1
    set x, 19
low:
    wait t+
    wait t+
    wait t+
    wait t+
    jmp x--, low
    set pindirs, 0           ; 80 units low
    set x, 11
presence:
    wait t+
    jmp x--, presence
    in pins, 1               ; 12 units after the release
    set x, 16
high:
    wait t+
    wait t+
    wait t+
    wait t+
    jmp x--, high            ; 68 units more
    in null, 15
    push
    jmp idle
|}
      ~config
      ~period_floor:5]
;;

let reset = 1
let byte b = (b land 0xff) lsl 1

let crc8 bytes =
  List.fold bytes ~init:0 ~f:(fun crc b ->
    List.init 8 ~f:(fun i -> (b lsr i) land 1)
    |> List.fold ~init:crc ~f:(fun crc bit ->
      Crc.step ~width:8 ~poly:0x8c ~reflect:true crc ~bit))
;;

let rom ~family ~serial =
  let bytes = family :: List.init 6 ~f:(fun i -> (serial lsr (8 * i)) land 0xff) in
  bytes @ [ crc8 bytes ]
;;

module Slave = struct
  module Phase = struct
    type t =
      | Asleep
      | Presence_in of int
      | Command of
          { bits : int
          ; count : int
          }
      | Rom of int
      | Done
  end

  module Last = struct
    type t =
      | Nothing
      | Reset
      | Slot
  end

  type t =
    { cycle_ns : int
    ; rom : int list
    ; phase : Phase.t
    ; last : Last.t
    ; master_low : bool
    ; run : int (* cycles the master has been as it is *)
    ; since_fall : int
    ; drive : int (* cycles of pulling the line low that are left *)
    ; log : string list
    ; measured : Measured.t
    ; violations : string list
    }

  let read_rom = 0x33
  let presence_delay_us = 30
  let presence_us = 120
  let zero_hold_us = 15

  let create ~cycle_ns ~rom =
    { cycle_ns
    ; rom
    ; phase = Asleep
    ; last = Nothing
    ; master_low = false
    ; run = 0
    ; since_fall = 0
    ; drive = 0
    ; log = []
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let drive_low t = t.drive > 0
  let ns t cycles = cycles * t.cycle_ns
  let cycles t us = us * 1000 / t.cycle_ns
  let log_line t line = { t with log = line :: t.log }
  let timed t ~name ~ns = { t with measured = Measured.add t.measured ~name ~ns }

  let require t ok ~name ~ns =
    if ok
    then t
    else { t with violations = [%string "%{name} of %{ns#Int} ns"] :: t.violations }
  ;;

  let rom_bit t i = (List.nth_exn t.rom (i / 8) lsr (i % 8)) land 1

  let fell t =
    let high = ns t t.run in
    let t =
      match t.last with
      | Nothing -> t
      | Reset -> require t (high >= 480_000) ~name:"high after reset" ~ns:high
      | Slot ->
        let slot = ns t t.since_fall in
        let t = timed (timed t ~name:"slot" ~ns:slot) ~name:"high" ~ns:high in
        let t = require t (slot >= 60_000) ~name:"slot" ~ns:slot in
        require t (high >= 1_000) ~name:"high" ~ns:high
    in
    match t.phase with
    | Rom i ->
      let t = if rom_bit t i = 0 then { t with drive = cycles t zero_hold_us } else t in
      if i = 63
      then log_line { t with phase = Done } "rom sent"
      else { t with phase = Rom (i + 1) }
    | Asleep | Presence_in _ | Command _ | Done -> t
  ;;

  let shift_command t bit =
    match t.phase with
    | Command { bits; count } ->
      let bits = bits lor (bit lsl count) in
      if count < 7
      then { t with phase = Command { bits; count = count + 1 } }
      else
        log_line
          { t with phase = (if bits = read_rom then Rom 0 else Done) }
          (sprintf "command 0x%02x" bits)
    | Asleep | Presence_in _ | Rom _ | Done -> t
  ;;

  let rose t =
    let low = ns t t.run in
    if low >= 480_000
    then
      log_line
        (timed
           { t with phase = Presence_in (cycles t presence_delay_us); last = Reset }
           ~name:"reset low"
           ~ns:low)
        "reset"
    else (
      let t = { t with last = Slot } in
      if 1_000 <= low && low <= 15_000
      then shift_command (timed t ~name:"one low" ~ns:low) 1
      else if 60_000 <= low && low <= 120_000
      then shift_command (timed t ~name:"zero low" ~ns:low) 0
      else require t false ~name:"low" ~ns:low)
  ;;

  let step t ~master_low =
    let t = { t with drive = Int.max 0 (t.drive - 1); since_fall = t.since_fall + 1 } in
    let t =
      match t.phase with
      | Presence_in 0 ->
        log_line
          { t with phase = Command { bits = 0; count = 0 }; drive = cycles t presence_us }
          "presence"
      | Presence_in n -> { t with phase = Presence_in (n - 1) }
      | Asleep | Command _ | Rom _ | Done -> t
    in
    if Bool.equal master_low t.master_low
    then { t with run = t.run + 1 }
    else if master_low
    then { (fell t) with master_low; run = 1; since_fall = 0 }
    else { (rose t) with master_low; run = 1 }
  ;;

  let log t = List.rev t.log
  let measured t = t.measured
  let violations t = List.rev t.violations
end

let bench_unit = Bench.cycles_in ~us:6

(* The library's reset is 80 units, 480 us at the 6 us unit: exactly the least a DS18B20
   takes. One more pass of its low loop makes it 84, 504 us. *)
let bench =
  { Bench.name = "one_wire"
  ; what =
      [%string
        "One_wire.firmware with a reset of 84 units: the host sends the unit, \
         %{bench_unit#Int} cycles for %{Bench.time bench_unit}, so %{Bench.time (84 * \
         bench_unit)}, on IO4"]
  ; source =
      Bench.patch
        (Timed_program.source firmware)
        ~pattern:"    set x, 19\n"
        ~with_:"    set x, 20\n"
  ; config =
      { config with
        in_base = Bench.one_wire
      ; out_base = Bench.one_wire
      ; set_base = Bench.one_wire
      }
  ; assumption = Floor 5
  ; clock_hz = Bench.clock_hz
  ; load = Some bench_unit
  ; stimulus =
      Some
        { bursts = [ [ reset; byte 0x00; byte 0xa5; byte 0xff ] ]
        ; quiet = 0
        ; cycles = 200_000
        }
  }
;;

(* DS18B20: a low under tLOW0's 60 us is a write 1 or a read, one from there to tRSTL's
   480 a write 0, and longer a reset *)
let limits =
  let sheet =
    { Datasheet.Sheet.part = "DS18B20"; document = "Maxim REV 042208"; page = "p.20" }
  in
  let reset ~clock_hz l = l >= Datasheet.cycles ~clock_hz 480_000. in
  let lows_from least ?(below = Float.infinity) () =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter (Datasheet.lows levels) ~f:(fun l ->
        l >= Datasheet.cycles ~clock_hz least
        && Float.(of_int l < below *. of_int clock_hz /. 1e9)))
  in
  (* each low with the high after it *)
  let slots f =
    Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
      List.filter_map (Datasheet.pairs levels) ~f:(fun ((high, l), (_, h)) ->
        if high then None else f ~clock_hz l h))
  in
  let limit parameter limit bound =
    { Datasheet.firmware = "one_wire"; parameter; limit; sheet; margin = Cycle; bound }
  in
  [ limit
      "tLOW1"
      (At_least 1_000.)
      (Datasheet.level ~dirs:true ~pin:Datasheet.set_pin ~high:true ())
  ; limit "tLOW1" (At_most 15_000.) (lows_from 0. ~below:60_000. ())
  ; limit "tLOW0" (At_least 60_000.) (lows_from 60_000. ~below:480_000. ())
  ; limit "tLOW0" (At_most 120_000.) (lows_from 60_000. ~below:480_000. ())
  ; limit
      "tREC"
      (At_least 1_000.)
      (Datasheet.level ~dirs:true ~pin:Datasheet.set_pin ~high:false ())
  ; limit
      "tSLOT + tREC"
      (At_least 61_000.)
      (slots (fun ~clock_hz l h -> Option.some_if (not (reset ~clock_hz l)) (l + h)))
  ; limit "tRSTL" (At_least 480_000.) (lows_from 480_000. ())
  ; limit
      "tRSTH"
      (At_least 480_000.)
      (slots (fun ~clock_hz l h -> Option.some_if (reset ~clock_hz l) h))
  ]
;;

open Pin_trace
module Reg = Host_port.Reg

let scenario =
  let rom = rom ~family:0x28 ~serial:0x0123_4567_89ab in
  let unit = standard_unit in
  let peer () =
    let slave = ref (Slave.create ~cycle_ns ~rom) in
    let low = ref false in
    { Peer.inputs = (fun () -> if !low then 0 else 1 lsl pin)
    ; step =
        (fun ~pin_out:_ ~pin_dir ->
          let master_low = Peer.bit pin_dir pin = 1 in
          low := master_low || Slave.drive_low !slave;
          slave := Slave.step !slave ~master_low)
    }
  in
  (* a reset is 160 units and a byte 96 *)
  let read_four =
    [ Step.Write (Reg.tx, List.init 4 ~f:(fun _ -> byte 0xff))
    ; Run ((4 * 96 * unit) + 1000)
    ; Read (Reg.rx, 4)
    ]
  in
  { Scenario.name = "one_wire"
  ; peer
  ; script =
      Scenario.load ~config ~program:(Timed_program.words firmware)
      @ [ Scenario.start
        ; Write (Reg.tx, [ unit; reset; byte 0x33 ])
        ; Run (((160 + 96) * unit) + 1000)
        ; Read (Reg.rx, 2)
        ]
      @ read_four
      @ read_four
  ; sigrok =
      Some
        { clock_hz = 1_000_000_000 / cycle_ns
        ; decoders =
            [ String.concat
                ~sep:","
                [ Sigrok.decoder "onewire_link" ~pins:[ "owr", pin ]
                ; Sigrok.decoder "onewire_network"
                ]
            ]
        ; expect =
            [ ( "onewire_link=reset:presence"
              , Sigrok.lines "onewire_link" [ "Reset"; "Presence: true" ] )
            ; ( "onewire_network"
              , Sigrok.lines
                  "onewire_network"
                  [ "Reset/presence: true"
                  ; "ROM command: 0x33 'Read ROM'"
                  ; sprintf
                      "ROM: 0x%016x"
                      (List.fold_right rom ~init:0 ~f:(fun byte rest ->
                         (rest lsl 8) lor byte))
                  ] )
            ]
        ; joins_after = None
        ; rejected = None
        ; (* edge 6 starts the command's second slot: 14 us early, the first is 52 us *)
          teeth = [ [ Shift { pin; edge = 6; cycles = -14_000 / cycle_ns } ] ]
        }
  }
;;

let protocol =
  { Protocol.name = "one_wire"
  ; certified =
      [ Certified.plain
          ~period:standard_unit
          ~period_floor:5
          "one_wire"
          (Timed_program.source firmware)
          config
      ]
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ "one_wire", "open drain, which a wire does not show, and a slave has to answer" ]
  ; scenarios = []
  ; decoded = [ scenario ]
  }
;;
