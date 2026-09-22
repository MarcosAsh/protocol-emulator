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

val create : ?engines:int -> unit -> t

(** The config fields of every engine in register order. *)
val configs : t -> int list list

(** What a write does given every engine's status, with the engine each event reaches.
    Config fields change only on a halted engine. *)
val write
  :  t
  -> statuses:int Host_port.Status.t list
  -> reg:int
  -> int
  -> t * (int * Event.t) list

(** The word a read returns given every engine's status, and what the read does. *)
val read
  :  t
  -> statuses:int Host_port.Status.t list
  -> reg:int
  -> int * (int * Event.t) list
