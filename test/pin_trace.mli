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
    | Until of int (** Cycles with the host idle up to this one, counted from 0. *)
    | Drive of
        { pin : int
        ; levels : int list
        } (** One level per cycle on an input pin, over the peer's. *)
end

(** What sigrok's protocol decoders should read off the pins, for [demo/decode.py]. A pin
    is named as [pin_name] gives it wherever sigrok-cli wants a channel. *)
module Sigrok : sig
  (** A change to one pin's waveform, edges counted from 0. *)
  module Corruption : sig
    type t =
      | Shift of
          { pin : int
          ; edge : int
          ; cycles : int
          } (** The edge [cycles] later, or earlier if negative. *)
      | Flip of
          { pin : int
          ; edge : int
          ; after : int
          ; cycles : int
          } (** The pin inverted for [cycles] from [after] cycles past the edge. *)
  end

  type t =
    { clock_hz : int
    ; decoders : string list (** One [-P] of sigrok-cli each. *)
    ; expect : (string * string list) list
    (** Per [-A] of sigrok-cli, classes that carry the payload, every line it prints. *)
    ; joins_after : (int * string) option
    (** Cycles the first pin idles high before the decoders join, as a CAN node waits for
        eleven recessive bits, and why they misread the line before: the check from reset
        then has to fail. *)
    ; rejected : string option
    (** Why the decoders refuse the waveform, when they are known to: the check then has
        to fail. *)
    ; teeth : Corruption.t list list (** Each must make the check fail. *)
    }

  (** IN0 to IN4, OUT0 to OUT6 and IO0 to IO7. *)
  val pin_name : int -> string

  (** [name:channel=PIN:option=value...]. *)
  val decoder
    :  ?pins:(string * int) list
    -> ?options:(string * string) list
    -> string
    -> string
end

module Scenario : sig
  type t =
    { name : string
    ; peer : unit -> Peer.t
    ; script : Step.t list
    ; sigrok : Sigrok.t option
    }

  (** The frames that configure the core and load a program at address 0. *)
  val load : config:Program_config.t -> program:int list -> Step.t list

  val start : Step.t
end

(** The pins on every cycle, and the words each [Read] returned. *)
val run : Scenario.t -> Line.t list * int list list

(** One line per run of identical cycles: the run length in decimal, then [ui_in],
    [uio_in], [uo_out], [uio_out] and [uio_oe] in hex. Lines starting with [#] are
    comments, and those starting with [# sigrok] carry [Sigrok.t]. *)
val to_string : Scenario.t -> Line.t list -> string
