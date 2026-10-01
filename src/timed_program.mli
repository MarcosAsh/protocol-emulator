(** Firmware the proved kernel accepted, with the analyser's rows it accepted. Only
    [check] makes one, so a loader that takes [t] loads nothing that can reach a deadline
    wait late, under the assumptions [check] was given. *)

open! Core

type t [@@deriving sexp_of]

(** Why [check] refused: the pcs at fault, so a caller can point at the source, and the
    analyser's verdict if it passed. *)
module Refusal : sig
  type t =
    { pcs : int list
    ; verdict : Analyser.Verdict.t option
    ; error : Error.t
    }
  [@@deriving sexp_of]
end

(** [Analyser.check] under its assumptions, then the kernel on the analyser's rows, which
    are not trusted; the kernel covers less, so it can refuse what the analyser passes. A
    [period_floor] is checked at its two ends, which covers every load between. *)
val check
  :  ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> Asm.Program.t
  -> (t, Refusal.t) Result.t

(** Assembles and checks, raising on either refusal. *)
val of_source_exn
  :  ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> string
  -> t

val program : t -> Asm.Program.t

(** The configuration it was checked under, with the program's side-set and wrap. *)
val config : t -> Program_config.t

val words : t -> int list
val rows : t -> Analyser.Row.t list
val verdict : t -> Analyser.Verdict.t
