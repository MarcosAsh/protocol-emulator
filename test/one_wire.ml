open! Core
open Protocol_emulator

let pin = 12
let cycle_ns = 20
let standard_unit = 6_000 / cycle_ns

(* host word: bit 0 asks for a reset, otherwise bits 8 to 1 are the byte, LSB first *)
let firmware =
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
    set y, 6
hold:
    wait t+
    jmp y--, hold
    wait t+
    set pindirs, 0           ; 10 units: a zero lets go
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
;;

let config =
  { Program_config.default with
    in_base = pin
  ; out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  }
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
