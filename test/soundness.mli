(** Checks the analyser's rows against the model, the firmware run under each stimulus:
    the phase at every issue must fall inside its row's interval, none on an unreachable
    row. An issue that finds its side-set pins at another level moves them, and the row
    must claim a side edge for that cycle, likewise a Manchester bit's second half. A
    refused pull needs a row that may refuse. *)

open! Core
open Protocol_emulator

module Stimulus : sig
  type t =
    { cycles : int
    ; inputs : int -> int (** The pins in a cycle. *)
    ; host : int -> Machine.t -> Machine.t
    (** What the host does to the fifos in a cycle, before the core steps. *)
    }

  (** Random levels on every pin and a host that writes a random word and pops a word,
      each one cycle in four. Random pins break every assumption about the world. *)
  val random : seed:int -> cycles:int -> t
end

type t =
  { issues : int
  ; side_edges : int
  ; flips : int (** Second halves of Manchester bits, each checked like a side edge. *)
  ; gaps : int (** Edges whose distance from the edge before was checked. *)
  ; reached : int (** Rows issued at least once. *)
  ; violations : (int * int * int * int) list
  (** The stimulus, the cycle, the pc and the phase, first to last. *)
  }

(** The assumptions go to the analyser; a stimulus that breaks one is a wrong test, not a
    finding. *)
val check
  :  ?period:int
  -> ?single_capture_edge:bool
  -> ?preload:int list
  -> config:Program_config.t
  -> Stimulus.t list
  -> int list
  -> t
