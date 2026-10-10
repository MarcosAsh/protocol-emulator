open! Core
open Protocol_emulator

val assemble : string -> int list

(** Pushes the low 16 bits of [now] for every edge on [pin], rising and falling, starting
    with the first edge after it starts. Edges have to come at least five cycles apart. *)
val edge_logger : pin:int -> string

val edge_logger_config : pin:int -> Program_config.t
