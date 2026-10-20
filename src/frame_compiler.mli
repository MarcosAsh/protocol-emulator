(** Compiles a one-pin transmitter into firmware for one engine by the frame it sends, not
    by its states: [Bit_sim] runs the netlist with the byte as unknown bits, so the coding
    style (counter shapes, indexed or shifted data, one or two processes) does not matter.
    Anything else is refused, naming the register or cycle at fault:

    - From reset, with [valid] low, the circuit settles in a state that holds, and again
      after a frame: the idle state is what the two share. One that keeps moving, like a
      free-running baud tick, is refused.
    - A take is [valid] high in the idle state, with [data] read then and unknown after.
      [valid] is unknown for the rest of the frame, so a circuit that reads it while busy
      is refused, as is one whose control reads the data.
    - In every cycle the pin is 0, 1 or a bit of the data, data bits in rising order (LSB
      first, gaps allowed) and not inverted, and the frame ends back in the idle state.
    - The data is at most 16 bits, the tx fifo's word. Inputs other than reset, valid,
      data and [tied] are unknown.

    An unknown pin is refused with what it depends on: each input, and each register
    unknown in the idle state, that made known alone makes the pin known.

    Every run of the pin starts at a deadline: [wait t+] on [p], the commonest run length,
    then [set pins] or [out pins, 1], then [add t] or extra waits for a run of another
    length. Consecutive data runs of length [p] share a [jmp x--] loop. So every edge is
    at a fixed lag behind the circuit's, whatever the data. *)

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
      has it running from cycle 3, with the circuit's reset in cycle 0, as
      write_certificate.exe's do. *)
  type t =
    { lag : int (** The engine's pin is the circuit's [lag] cycles before. *)
    ; first_take : int (** The first cycle a take may come in. *)
    ; gap : int
    (** The fewest cycles from one take to the next, at least [length] and [settled]. *)
    ; shortest : int
    (** The fewest the engine follows the circuit at in simulation, which [gap] may exceed
        because the invariants want both settled. *)
    ; settled : int
    (** Cycles after a take by which both are back where they wait, and stay. *)
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

(** The engine's state after [n] steps from the start, for a take in each of [takes], as
    the harness above counts cycles: [run t ~takes ~cycles] has an entry per cycle from 3. *)
val engine_states
  :  Fsm_compiler.Firmware.t
  -> takes:(int * int) list
  -> cycles:int
  -> Machine.t array
