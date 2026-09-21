(** Runs a firmware on the Tiny Tapeout top the way a board would, host on the SPI pins
    and a peer on the rest, and records every pin on every cycle. The cocotb replay drives
    the recorded inputs into the Verilog, the gate level netlist and the FPGA netlist and
    expects the recorded outputs back.

    Cyclesim does not model the asynchronous reset: its registers start at zero, which is
    the state [rst_n] low leaves the reset synchroniser in. Cycle 0 of a trace is
    therefore the first rising clock edge after [rst_n] is released, and the replay holds
    [rst_n] low before it. Outputs are the values after the edge. *)

open! Core
open Protocol_emulator

module Line : sig
  type t =
    { ui_in : int
    ; uio_in : int
    ; uo_out : int
    ; uio_out : int
    ; uio_oe : int
    }
  [@@deriving sexp_of, equal]
end

(** Whatever is wired to the core's pins, numbered as the engine numbers them. [inputs] is
    asked before every edge and [step] sees the outputs after it. *)
module Peer : sig
  type t =
    { inputs : unit -> int
    ; step : pin_out:int -> pin_dir:int -> unit
    }

  val idle : int -> t
end

module Step : sig
  type t =
    | Write of int * int list (** A host write frame: register, words. *)
    | Read of int * int (** A host read frame: register, number of words. *)
    | Run of int (** Cycles with the host idle. *)
    | Drive of
        { pin : int
        ; levels : int list
        } (** One level per cycle on an input pin, over the peer's. *)
end

module Scenario : sig
  type t =
    { name : string
    ; peer : unit -> Peer.t
    ; script : Step.t list
    }

  (** The frames that configure the core and load a program at address 0. *)
  val load : config:Program_config.t -> program:int list -> Step.t list

  val start : Step.t
end

(** The pins on every cycle, and the words each [Read] returned. *)
val run : Scenario.t -> Line.t list * int list list

(** One line per run of identical cycles: the run length in decimal, then [ui_in],
    [uio_in], [uo_out], [uio_out] and [uio_oe] in hex. Lines starting with [#] are
    comments. *)
val to_string : Scenario.t -> Line.t list -> string
