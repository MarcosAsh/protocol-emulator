(** Bit stuffing in the line path, for [Line_code.Modes.tx_stuff]. A stuffed bit takes a
    bit time the firmware never spends: the out it lands on sends a 0 and keeps its own
    bit owed, and every out after sends the oldest owed bit and keeps its own, so the
    core's timing never depends on the data. After [finish] outs take no bits, only pay
    what is owed, until an out finds nothing owed and no stuffing, which takes its bit
    again. *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; start : 'a
    ; enable : 'a
    ; step : 'a (** A single-bit [out pins] steps the transmit table. *)
    ; stuffing : 'a (** The table flagged the last step. *)
    ; data : 'a (** The out's own bit. *)
    ; finish : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { sent : 'a (** The bit the table takes. *)
    ; owed : 'a
    ; held : 'a (** The bits taken, latest lowest. *)
    ; count : 'a (** How many of them are owed. *)
    ; draining : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
