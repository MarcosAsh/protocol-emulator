(** Runs the engine and the [Machine] model side by side and compares the architectural
    state after every clock edge. *)

open! Core
open Protocol_emulator

module State : sig
  type t [@@deriving sexp_of]
end

(** What the host does in one cycle. *)
module Host : sig
  type t =
    { tx : int option
    ; pop_rx : bool
    ; clear_irq : bool
    ; stop : bool
    }

  val idle : t
end

(** [preload] is pushed into the tx fifo before the start pulse. [inputs] and [host] are
    asked once per cycle; [react] sees the model after each step, which is where a peer on
    the pins advances. Stops at the first mismatch and returns it with the cycle.
    [coverage] is told about every step of the model. *)
val run
  :  ?cycles:int
  -> ?preload:int list
  -> ?host:(int -> Host.t)
  -> ?react:(Machine.t -> unit)
  -> ?coverage:Coverage.t
  -> config:Program_config.t
  -> program:int list
  -> inputs:(int -> int)
  -> unit
  -> Machine.t * (int * State.t * State.t) option

(** [run], printing whether the two held together. *)
val lockstep
  :  ?cycles:int
  -> ?preload:int list
  -> ?host:(int -> Host.t)
  -> ?react:(Machine.t -> unit)
  -> ?coverage:Coverage.t
  -> config:Program_config.t
  -> program:int list
  -> inputs:(int -> int)
  -> unit
  -> Machine.t

(** [programs] runs of [run], each under a random configuration, random pins and a host
    that writes and reads at random; prints the seeds that did not hold. Without [wrap]
    the program counter only wraps at the end of memory. *)
val random_programs
  :  ?coverage:Coverage.t
  -> ?wrap:bool
  -> programs:int
  -> cycles:int
  -> (Splittable_random.t -> config:Program_config.t -> int list)
  -> unit
