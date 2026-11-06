(** Static timing of a PIO program over every path, in state machine cycles. Each edge
    gets a lower bound on the pulse it ends and each rule gets its worst case. [phase]
    counts from the last [wait] on a pin, which is where a receiver locks. Times are at
    the pin driver, not at the bus's 30% and 70% levels, so the caller has to subtract
    rise and fall times. On an open-drain pin another driver may stretch a low we release,
    unless [no_stretch] is set. *)

open! Core

module Pin_ref : sig
  type t =
    | Side of int
    | Set of int
    | Out of int
    | In of int
    | Jmp_pin
    | Gpio of int
  [@@deriving sexp_of, equal]
end

module Drive : sig
  (** How a write shows on the pin. [Level] is the output level. [Dir] and [Dir_low] use
      the direction bit (open drain): with [Dir] the pin is high when the bit is set
      (output enable inverted), with [Dir_low] it is low when the bit is set (driving 0). *)
  type t =
    | Level
    | Dir
    | Dir_low
    | Input
  [@@deriving sexp_of]
end

module Pin : sig
  type t =
    { name : string
    ; bindings : (Pin_ref.t * Drive.t) list
    ; initial : bool option
    (** Output level on entry, unknown when [None]. An open-drain pin that is unknown at
        entry may already be held low by another driver, so its first rise isn't tracked. *)
    }
  [@@deriving sexp_of]

  (** Parses a name followed by bindings, like ["sda=set0:dir,out0:dir,in0,jmp"]. A
      binding is [side|set|out]N with an optional [:dir] or [:!dir], or [inN], [gpioN] or
      [jmp]. *)
  val of_string : string -> t Or_error.t
end

module Edge : sig
  type t =
    { pin : string
    ; rising : bool option (** Matches either edge when [None]. *)
    }
  [@@deriving sexp_of]
end

module Time : sig
  type t =
    | Cycles of int
    | Ns of float
  [@@deriving sexp_of]
end

(** Every [target] edge must come at least [at_least] after the last [source] edge. Works
    for minimum pulse widths and for setup and hold times between pins. *)
module Rule : sig
  type t =
    { name : string
    ; source : Edge.t
    ; target : Edge.t
    ; at_least : Time.t
    }
  [@@deriving sexp_of]

  (** Parses a rule like ["t_hd_sta: sda- -> scl- >= 4us"]. An edge ends in [+], [-] or
      nothing for either. Times are in [ns], [us] or cycles ([cy]). *)
  val of_string : string -> t Or_error.t
end

module Clock : sig
  type t =
    { sys_hz : float
    ; clkdiv : float
    }
  [@@deriving sexp_of]

  (** The divider the hardware actually uses when [clkdiv] is the float passed to
      [sm_config_set_clkdiv]. It has 16 integer and 8 fraction bits, and pico-sdk rounds
      to the nearest 1/256 by default. *)
  val effective_div : t -> float
end

module Exec_sequence : sig
  type t =
    { guard : (string * int) list
    (** Output levels, [x] or [y] that the sequence may start from. When it does start,
        the registers are assumed to hold these values. *)
    ; instructions : Pioasm.Instruction.t list
    }
  [@@deriving sexp_of]

  (** Parses a sequence like
      ["x=1,scl=1: set pindirs, 0 side 1 [7] | set pindirs, 0 side 0 [7]"]. The guard is
      optional. *)
  val of_string : Pioasm.Program.t -> string -> t Or_error.t
end

module Config : sig
  type t =
    { pins : Pin.t list
    (** When empty, uses [side0], [set0], [out0] and the inputs by position. *)
    ; autopull : bool
    ; autopush : bool
    ; fifo_ready : bool
    (** FIFO accesses never stall because the CPU or DMA keeps up. Waits still stall. *)
    ; irq_wait_halts : bool
    (** An [irq wait] never releases into the next instruction, since the CPU restarts the
        machine elsewhere, as SDK error handlers do. *)
    ; set_count : int
    ; out_count : int
    ; exec : Exec_sequence.t list
    (** The sequences that [out exec] and [mov exec] run. Each runs whole and in order,
        and any sequence whose guard the pins may meet can follow any other. It is an
        error if no guard can hold for an exec, or if a guard names anything but [x], [y]
        or an output. *)
    ; clock : Clock.t option
    ; rules : Rule.t list
    ; cell : int option
    (** Cycles per bit cell of an input that locks at each [wait]. Gives the sender clock
        error that every sample tolerates, in system clocks when [clock] is known. *)
    ; entry : string option (** The label the state machine starts at, or address 0. *)
    ; no_stretch : string list
    (** Open-drain outputs that no other driver holds low, so a release rises at once. On
        any other pin, a release after our low rises at some unknown later time until a
        [wait] sees it high. Other drivers can only hold a low, never start one. *)
    }
  [@@deriving sexp_of]

  val default : t
end

module Report : sig
  type t [@@deriving sexp_of]

  (** True when every rule was checked on some path and none is broken, and every path was
      modelled. With a [cell], also true only if every sample lands in its cell with a
      sender at the requested rate. *)
  val passed : t -> bool

  (** The fewest cycles each rule sees over all paths, or [None] if it is never checked. *)
  val rule_bounds : t -> int option list

  (** One row per instruction (and per [exec]'d instruction) with address, text, cycles
      ([+] if it may stall), phase at issue, then edges ([pin+ width], [pin- width]),
      samples, and [anchor] where a wait releases. Each rule's worst case follows. *)
  val to_string : t -> string
end

val analyse : Config.t -> Pioasm.Program.t -> Report.t
