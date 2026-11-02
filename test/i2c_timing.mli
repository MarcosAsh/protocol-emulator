(** The bus timings an I2C master drives, bounded from the analyser's certificate. SCL is
    the one side-set pin and SDA the pin [set pindirs] and [mov pindirs] write, both open
    drain: a direction of 1 pulls the line low and 0 lets it go high. A write to SDA while
    SCL is high is a START or a STOP by the level it leaves.

    From every edge the program can make, every way through it is followed to the edge the
    timing ends on, each instruction timed from the analyser's phase and each wait's
    deadline. A wait for the host or a pin may last any time, so a bound holds for every
    run. A way that revisits an instruction is cut, as coming round again only takes
    longer. The schedule at the pins is bounded, not the bus's rise and fall times. *)

open! Core
open Protocol_emulator

module Edge : sig
  type t =
    | Scl_rise
    | Scl_fall
    | Data (** SDA written while SCL is low. *)
    | Start (** SDA pulled low while SCL is high. *)
    | Stop (** SDA let go while SCL is high. *)
  [@@deriving sexp_of]
end

(** The cycles from one edge to the next [until], over the edges in [through]; any other
    edge ends the way. The limit is a minimum. *)
module Timing : sig
  type t =
    { name : string
    ; from : Edge.t
    ; until : Edge.t
    ; through : Edge.t list
    ; min_ns : int
    }
end

(** UM10204 table 11, Fast-mode Plus, for the timings a master drives; the SCL period is
    the 1 MHz most of fSCL. *)
val fast_mode_plus : Timing.t list

(** The same from UM10204 table 11's Standard-mode column, an SCL period of 10 us. *)
val standard_mode : Timing.t list

(** The limit of the timing [name], such as ["tLOW"]. *)
val min_ns : Timing.t list -> string -> int

module Bound : sig
  type t =
    { timing : Timing.t
    ; cycles : Interval.t option (** [None] when no way ends on [until]. *)
    ; met : bool
    }
end

(** A timing is met when its shortest time at [clock_mhz] is at least its limit, or when
    no way ends on it. *)
val check
  :  clock_mhz:int
  -> config:Program_config.t
  -> Asm.Program.t
  -> Timing.t list
  -> Bound.t list
