(** Runs the engine and the [Machine] model side by side and compares the architectural
    state after every clock edge. *)

open! Core
open! Hardcaml
open Protocol_emulator

module State : sig
  type t [@@deriving sexp_of, equal]

  val of_machine : Machine.t -> t
  val of_outputs : Bits.t ref Engine.O.t -> t
end

(** What the host does in one cycle. *)
module Host : sig
  type t =
    { tx : int option
    ; pop_rx : bool
    ; clear_irq : bool
    ; stop : bool
    ; flush : bool
    ; resume : bool (** Asked while halted, the model takes it a cycle later. *)
    ; single_step : bool
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
    the program counter only wraps at the end of memory. With [debugger] each run also has
    a breakpoint at a random place, on or off, and a host that stops, resumes and single
    steps the core at random; the programs are the same either way. *)
val random_programs
  :  ?coverage:Coverage.t
  -> ?wrap:bool
  -> ?debugger:bool
  -> programs:int
  -> cycles:int
  -> (Splittable_random.t -> config:Program_config.t -> int list)
  -> unit
