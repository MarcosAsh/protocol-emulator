open! Core
open Protocol_emulator

let tck_pin = 5
let tdi_pin = 6
let tms_pin = 7
let tdo_pin = 0
let cycle_ns = 20
let shortest_half = 4

(* each wait carries the level TCK already has *)
let firmware ~half_period =
  [%string
    {|
    .side_set 1
    set p, %{half_period#Int} side 0
idle:
    wait tx side 0
    pull side 0
    set x, 7 side 0
    mov t, now side 0
    add t, p side 0
    wait t+ side 0
    out pins, 2 side 0       ; the first TMS and TDI, half a period before the first rise
clock:
    wait t+ side 0
    in pins, 1 side 1        ; rise: the TAP takes TMS and TDI, and we take TDO
    wait t+ side 1
    out pins, 2 side 0       ; fall, the next TMS and TDI
    jmp x--, clock
    push side 0
    jmp idle
|}]
;;

let config =
  { Program_config.default with
    side_set_count = 1
  ; side_set_base = tck_pin
  ; out_base = tdi_pin
  ; in_base = tdo_pin
  }
;;

module Clock = struct
  type t =
    { tms : bool
    ; tdi : bool
    }
  [@@deriving sexp_of]
end

let tms bits = List.map bits ~f:(fun tms -> { Clock.tms = tms = 1; tdi = false })
let reset = tms [ 1; 1; 1; 1; 1; 0 ]

(* the last bit leaves the shift state as it goes in *)
let shift ~bits value =
  List.init bits ~f:(fun i ->
    { Clock.tms = i = bits - 1; tdi = (value lsr i) land 1 = 1 })
;;

let ir_shift_offset = 4
let dr_shift_offset = 3
let scan_ir ~bits value = tms [ 1; 1; 0; 0 ] @ shift ~bits value @ tms [ 1; 0 ]
let scan_dr ~bits value = tms [ 1; 0; 0 ] @ shift ~bits value @ tms [ 1; 0 ]

let words clocks =
  let pad = List.length clocks % 8 in
  let pad = if pad = 0 then 0 else 8 - pad in
  clocks @ List.init pad ~f:(fun _ -> { Clock.tms = false; tdi = false })
  |> List.chunks_of ~length:8
  |> List.map ~f:(fun clocks ->
    List.foldi clocks ~init:0 ~f:(fun i word { Clock.tms; tdi } ->
      word lor (Bool.to_int tdi lsl (2 * i)) lor (Bool.to_int tms lsl ((2 * i) + 1))))
;;

let shifted_out ~pushed ~first ~bits =
  let pushed = Array.of_list pushed in
  List.init bits ~f:(fun i ->
    let clock = first + i in
    ((pushed.(clock / 8) lsr (8 + (clock % 8))) land 1) lsl i)
  |> List.fold ~init:0 ~f:( lor )
;;

module Tap = struct
  module State = struct
    type t =
      | Test_logic_reset
      | Run_test_idle
      | Select_dr
      | Capture_dr
      | Shift_dr
      | Exit1_dr
      | Pause_dr
      | Exit2_dr
      | Update_dr
      | Select_ir
      | Capture_ir
      | Shift_ir
      | Exit1_ir
      | Pause_ir
      | Exit2_ir
      | Update_ir

    (* IEEE 1149.1 figure 6-1, TMS high then low *)
    let next t ~tms =
      let high, low =
        match t with
        | Test_logic_reset -> Test_logic_reset, Run_test_idle
        | Run_test_idle -> Select_dr, Run_test_idle
        | Select_dr -> Select_ir, Capture_dr
        | Capture_dr -> Exit1_dr, Shift_dr
        | Shift_dr -> Exit1_dr, Shift_dr
        | Exit1_dr -> Update_dr, Pause_dr
        | Pause_dr -> Exit2_dr, Pause_dr
        | Exit2_dr -> Update_dr, Shift_dr
        | Update_dr -> Select_dr, Run_test_idle
        | Select_ir -> Test_logic_reset, Capture_ir
        | Capture_ir -> Exit1_ir, Shift_ir
        | Shift_ir -> Exit1_ir, Shift_ir
        | Exit1_ir -> Update_ir, Pause_ir
        | Pause_ir -> Exit2_ir, Pause_ir
        | Exit2_ir -> Update_ir, Shift_ir
        | Update_ir -> Select_dr, Run_test_idle
      in
      if tms then high else low
    ;;
  end

  let idcode = 0x4ba00477
  let minimum_ns = 40
  let ir_bits = 4
  let idcode_instruction = 0x1
  let user_instruction = 0x2

  type t =
    { cycle_ns : int
    ; now : int
    ; state : State.t
    ; ir : int
    ; user : int
    ; shift : int (* what is shifting, bit 0 next out *)
    ; length : int
    ; tdo : int
    ; tck : int
    ; tms : int
    ; tdi : int
    ; rose : int option
    ; fell : int option
    ; moved : int option (* when TMS or TDI last changed *)
    ; held : bool (* whether the hold after the last rise has been timed *)
    ; measured : Measured.t
    ; violations : string list
    }

  let create ~cycle_ns =
    { cycle_ns
    ; now = 0
    ; state = Test_logic_reset
    ; ir = idcode_instruction
    ; user = 0
    ; shift = 0
    ; length = 1
    ; tdo = 0
    ; tck = 0
    ; tms = 0
    ; tdi = 0
    ; rose = None
    ; fell = None
    ; moved = None
    ; held = true
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let tdo t = t.tdo
  let user t = t.user
  let measured t = t.measured
  let violations t = List.rev t.violations

  let timed t ~name ~since =
    match since with
    | None -> t
    | Some since ->
      let ns = (t.now - since) * t.cycle_ns in
      let t = { t with measured = Measured.add t.measured ~name ~ns } in
      if ns >= minimum_ns
      then t
      else { t with violations = [%string "%{name} of %{ns#Int} ns"] :: t.violations }
  ;;

  let data_register t =
    if t.ir = idcode_instruction
    then idcode, 32
    else if t.ir = user_instruction
    then t.user, 8
    else 0, 1
  ;;

  (* capture, shift and update happen on the rise, in the state the TAP is leaving *)
  let rise t =
    let t = timed t ~name:"TCK low" ~since:t.fell in
    let t = timed t ~name:"setup" ~since:t.moved in
    let t =
      match t.state with
      | Capture_dr ->
        let shift, length = data_register t in
        { t with shift; length }
      | Capture_ir -> { t with shift = 0b0001; length = ir_bits }
      | Shift_dr | Shift_ir ->
        { t with shift = (t.shift lsr 1) lor (t.tdi lsl (t.length - 1)) }
      | Update_dr when t.ir = user_instruction -> { t with user = t.shift land 0xff }
      | Update_ir -> { t with ir = t.shift land ((1 lsl ir_bits) - 1) }
      | _ -> t
    in
    let state = State.next t.state ~tms:(t.tms = 1) in
    let t = { t with state; rose = Some t.now; held = false } in
    match state with
    | Test_logic_reset -> { t with ir = idcode_instruction }
    | _ -> t
  ;;

  let fall t =
    let t = timed t ~name:"TCK high" ~since:t.rose in
    let tdo =
      match t.state with
      | Shift_dr | Shift_ir -> t.shift land 1
      | _ -> 0
    in
    { t with tdo; fell = Some t.now }
  ;;

  let step t ~tck ~tms ~tdi =
    let t =
      if tms <> t.tms || tdi <> t.tdi
      then (
        let t =
          if t.held then t else timed { t with held = true } ~name:"hold" ~since:t.rose
        in
        { t with tms; tdi; moved = Some t.now })
      else t
    in
    let t =
      if tck = t.tck
      then t
      else if tck = 1
      then rise { t with tck }
      else fall { t with tck }
    in
    { t with now = t.now + 1 }
  ;;
end
