(** Holds the analyser to its word on the model. The firmware runs under each stimulus and
    the phase at every issue has to fall inside its row's interval; no issue may land on a
    row the analyser calls unreachable. A wait that stalls issues again every cycle, and
    only its first issue counts as an entry.

    Side-set is checked on its own: an issue that finds its side-set pins at another level
    moves them, and the row must claim a side edge that covers the cycle they show it. So
    is the second half of a Manchester bit, which the issue after the [out] brings, and
    every data pull the model refuses must be on a row that says it may be. *)

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
