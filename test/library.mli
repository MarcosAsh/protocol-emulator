(** The firmware library: every protocol written in a file of its own, and as one more
    what the rest still list in [Certified], [Bench] and [Datasheet]. A new protocol is
    one file and its name in [protocols]. *)

open! Core

(** In the order the generated files list their firmware. *)
val protocols : Protocol.t list

(** The one in [protocols] that is not a file of its own. *)
val rest : Protocol.t

(** Every firmware CI proves a certificate of by induction, but [stamped]. *)
val certified : Certified.t list

val time_triggered : Certified.t list
val stamped : Certified.t

(** Searches [certified], [stamped] and [time_triggered]. *)
val find_certified_exn : string -> Certified.t

(** The firmware python/bench_firmware.py holds for the demos. *)
val bench : Bench.t list

(** Searches [bench] and the protocols' [loaded_from_hex]. *)
val find_bench_exn : string -> Bench.t

val limits : Datasheet.t list

(** Bench firmware with no limits, and why. *)
val exempt : (string * string) list

(** The protocols' runs at the pins. *)
val scenarios : Pin_trace.Scenario.t list

(** The sweep, and what keeps the rest of the firmware out of it, in the order of the
    firmware. *)
val swept : Swept.t list

val not_swept : (string * string) list
