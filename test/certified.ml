open! Core
open Protocol_emulator

type t =
  { name : string
  ; source : string
  ; config : Program_config.t
  ; period : int option
  ; period_floor : int option
  ; single_capture_edge : bool
  ; no_wrap : bool
  ; any_data : bool
  }

let plain
  ?period
  ?period_floor
  ?(single_capture_edge = false)
  ?(no_wrap = false)
  ?(any_data = false)
  name
  source
  config
  =
  { name; source; config; period; period_floor; single_capture_edge; no_wrap; any_data }
;;

let receiver ?period ?period_floor name source config =
  plain ?period ?period_floor ~single_capture_edge:true ~no_wrap:true name source config
;;

let of_firmware ?period ?no_wrap ?any_data name firmware =
  let period = Option.first_some (Timed_program.period firmware) period in
  let period_floor = Timed_program.period_floor firmware in
  if Option.is_some period_floor && Option.is_none period
  then
    raise_s
      [%message
        "a firmware checked at a least period needs ~period, the one the host loads" name];
  plain
    ?period
    ?period_floor
    ~single_capture_edge:(Timed_program.single_capture_edge firmware)
    ?no_wrap
    ?any_data
    name
    (Timed_program.source firmware)
    (Timed_program.config firmware)
;;

let assumptions t =
  { System_lockstep.Assumptions.period =
      (if Option.is_some t.period_floor then None else t.period)
  ; period_floor = t.period_floor
  ; single_capture_edge = t.single_capture_edge
  }
;;
