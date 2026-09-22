(** The analyser's certificate for a firmware, cut down to the lines a protocol is judged
    by: every pin edge, every pin sample, every edge side-set makes and every deadline
    that may be missed, then a one line verdict. *)

open! Core
open Protocol_emulator

val print
  :  ?period:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> string
  -> unit
