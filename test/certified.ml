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
  }

let plain
  ?period
  ?period_floor
  ?(single_capture_edge = false)
  ?(no_wrap = false)
  name
  source
  config
  =
  { name; source; config; period; period_floor; single_capture_edge; no_wrap }
;;

let receiver = plain ~single_capture_edge:true ~no_wrap:true
