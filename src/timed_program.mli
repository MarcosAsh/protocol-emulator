(** Firmware the proved kernel accepted, with the analyser's rows it accepted. Only
    [check] makes one, so a loader that takes [t] loads nothing that can reach a deadline
    wait late, under the assumptions [check] was given. *)

open! Core

type t [@@deriving sexp_of]

(** A source line [check] refused, with the pc assembled from it, if it assembled, and
    why, in a sentence for a reader. *)
module Fault : sig
  type t =
    { line : int
    ; pc : int option
    ; reason : string
    }
  [@@deriving sexp_of]
end

(** Why [check] refused: the lines at fault, by pc, and the analyser's verdict if it
    passed. *)
module Refusal : sig
  type t =
    { faults : Fault.t list
    ; verdict : Analyser.Verdict.t option
    ; error : Error.t
    }
  [@@deriving sexp_of]
end

(** Assembles, then [Analyser.check] under its assumptions, then the kernel on the
    analyser's rows, which are not trusted; the kernel covers less, so it can refuse what
    the analyser passes. A [period_floor] is checked at its two ends, which covers every
    load between. Lines count from 1. *)
val check
  :  ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> string
  -> (t, Refusal.t) Result.t

(** [check], raising on a refusal. *)
val of_source_exn
  :  ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> string
  -> t

val source : t -> string
val program : t -> Asm.Program.t

(** The configuration it was checked under, with the program's side-set and wrap. *)
val config : t -> Program_config.t

val words : t -> int list
val rows : t -> Analyser.Row.t list
val verdict : t -> Analyser.Verdict.t
