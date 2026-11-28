(** Compiles a one-pin transmitter into firmware for one engine by the frame it sends, not
    its states, running [Bit_sim] with the byte as unknown bits. Refused, naming the
    register or cycle: no idle state to settle in (a free-running baud tick), [valid] read
    while busy, a pin that isn't 0, 1 or an uninverted data bit in LSB-first order. *)

open! Core
open! Hardcaml

module Ports : sig
  type t =
    { reset : (string * Level.t) option (** The input and the level that resets. *)
    ; valid : string
    ; data : string
    ; pin : string (** An output. *)
    ; tied : (string * Bits.t) list (** Inputs held at a constant, as a baud rate port. *)
    }
  [@@deriving sexp_of]
end

module Symbol : sig
  type t =
    | Level of bool
    | Data of int
  [@@deriving compare, equal, sexp_of]
end

module Frame : sig
  type t =
    { warm_up : Bit_sim.State.t array
    (** During each cycle from reset, which is cycle 0, to the first in the idle state. *)
    ; idle : Bit_sim.State.t
    ; pin_idle : bool
    ; states : Bit_sim.State.t array
    (** During each cycle from the take, cycle 0 and in [idle], to [length], back in it. *)
    ; pins : Symbol.t array (** The pin in each of [states]. *)
    ; length : int (** Cycles from a take to the first cycle the next can come. *)
    ; data_width : int
    }

  (** Starts and symbols of the pin's runs from the take, the last at the idle level. *)
  val runs : t -> (int * Symbol.t) list
end

val read : ?limit:int -> Bit_sim.t -> ports:Ports.t -> Frame.t Or_error.t

module Timing : sig
  (** In cycles of a harness that clears the engine in cycle 0, starts it in cycle 1 and
      has it running from cycle 3, with the circuit's reset in cycle 0, like
      write_certificate.exe's. *)
  type t =
    { lag : int (** The engine's pin is the circuit's [lag] cycles before. *)
    ; first_take : int (** The first cycle a take may come in. *)
    ; gap : int
    (** The fewest cycles from one take to the next; at least [length] and [settled]. *)
    ; shortest : int
    (** The fewest cycles between takes at which the engine follows the circuit in
        simulation. [gap] may exceed it. *)
    ; settled : int
    (** Cycles after a take by which both are back where they wait, and stay there. *)
    }
  [@@deriving sexp_of]
end

type t =
  { frame : Frame.t
  ; firmware : Fsm_compiler.Firmware.t
  ; timing : Timing.t
  }

(** [limit] bounds the warm-up and the frame, 65536 cycles by default. *)
val compile : ?limit:int -> Bit_sim.t -> ports:Ports.t -> t Or_error.t

(** The engine's state after [n] steps from the start, for a take in each of [takes],
    counting cycles as the harness above does. [run t ~takes ~cycles] has one entry per
    cycle from 3. *)
val engine_states
  :  Fsm_compiler.Firmware.t
  -> takes:(int * int) list
  -> cycles:int
  -> Machine.t array
