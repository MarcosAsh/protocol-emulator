open! Core
open! Hardcaml

type t

val create
  :  sck:Bits.t ref
  -> mosi:Bits.t ref
  -> cs_n:Bits.t ref
  -> miso:Bits.t ref
  -> half:int
  -> t

val byte : t -> watch:(int -> unit) @ local -> int -> int
val frame : t -> watch:(int -> unit) @ local -> int list -> int list
val write : t -> watch:(int -> unit) @ local -> int -> int list -> unit
val read : t -> watch:(int -> unit) @ local -> int -> count:int -> int list
