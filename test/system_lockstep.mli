(** Runs [Engines] and the [System] model side by side and compares every engine's
    architectural state and the chip's pins after every clock edge. *)

open! Core
open Protocol_emulator

module Setup : sig
  type t =
    { config : Program_config.t
    ; program : int list
    ; preload : int list (** Pushed into the tx fifo before the start. *)
    ; data : int list
    (** Written into the data memory from address 0 before the start, zeros after, when
        the program autopulls from it. *)
    }
end

module Mismatch : sig
  type t =
    | Engine of
        { cycle : int
        ; engine : int
        ; expected : Lockstep.State.t
        ; actual : Lockstep.State.t
        }
    | Pins of
        { cycle : int
        ; expected : int * int
        ; actual : int * int
        } (** [pin_out] and [pin_dir] of the chip. *)
  [@@deriving sexp_of]
end

(** Every engine starts in the same cycle. [pads] and [host], one action per engine, are
    asked once per cycle; [react] sees the model after each step. Stops at the first
    mismatch. With [journal], two engines and a [Journal] armed eight cycles before the
    start and disarmed after the run, whose ring writes land in the array. *)
val run
  :  ?cycles:int
  -> ?journal:int array
  -> ?host:(int -> Lockstep.Host.t list)
  -> ?react:(System.t -> unit)
  -> pads:(int -> int)
  -> Setup.t list
  -> System.t * Mismatch.t option

(** [run], printing whether the two held together. *)
val lockstep
  :  ?cycles:int
  -> ?journal:int array
  -> ?host:(int -> Lockstep.Host.t list)
  -> ?react:(System.t -> unit)
  -> pads:(int -> int)
  -> Setup.t list
  -> System.t
