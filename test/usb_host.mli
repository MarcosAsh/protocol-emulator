(** A USB host port and the demo board, around a [Machine] that runs
    [Firmware.usb_device], with D+ and D- as a shared wire. The host side sends tokens and
    data and listens; the board side reads the words the core pushes, answers requests
    from a table of descriptors after [latency] cycles, which is what makes the core send
    NAKs, and reloads the core when the address changes. *)

open! Core
open Protocol_emulator

module Request : sig
  type t =
    { request_type : int
    ; request : int
    ; value : int
    ; index : int
    ; length : int
    }

  val get_descriptor : ?interface:bool -> kind:int -> length:int -> unit -> t
  val set_address : int -> t
  val set_configuration : int -> t
end

type t

(** Cycles to a bit: 48 MHz. *)
val bit_period : int

(** [descriptors] by descriptor type. *)
val create
  :  ?reset_cycles:int
  -> descriptors:(int * int list) list
  -> latency:int
  -> unit
  -> t

(** The host holds SE0 long enough for a bus reset. The board sees it on the wire and
    reloads the core for address 0. *)
val reset : t -> unit

(** A control read: SETUP, IN until the data is complete, the status OUT. *)
val control_in : t -> Request.t -> int list

(** A control write with no data: SETUP and the status IN. *)
val control_out : t -> Request.t -> unit

(** The board queues a report for the next IN on the interrupt endpoint. *)
val report : t -> int list -> unit

(** One IN; [None] is a NAK. *)
val interrupt_in : t -> endpoint:int -> int list option

(** What each load of the core saw, in order: the address it was assembled for and, per
    cycle, the input pins and the word the board wrote, if any. Enough to run the same
    thing again somewhere else. *)
val recording : t -> (int * (int * int option) list) list

val naks : t -> int
val faults : t -> Machine.Fault.t
