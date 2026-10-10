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
