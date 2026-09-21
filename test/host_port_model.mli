(** The register map of [Host_port] as the host sees it, one 16-bit word at a time. Only a
    complete word does anything: a frame cut short before the last bit of a word leaves
    that word without effect. *)

open! Core
open Protocol_emulator

(** What the port tells the core. *)
module Event : sig
  type t =
    | Start
    | Clear_irq
    | Stop
    | Flush
    | Program_write of
        { addr : int
        ; data : int
        }
    | Tx of int
    | Rx_pop
  [@@deriving sexp_of, equal]
end

type t [@@deriving sexp_of]

val create : unit -> t

(** The config fields in register order. *)
val config : t -> int list

val write : t -> reg:int -> int -> t * Event.t list

(** The word a read returns given the core's [status], and what the read does. *)
val read : t -> status:int Host_port.Status.t -> reg:int -> int * Event.t list
