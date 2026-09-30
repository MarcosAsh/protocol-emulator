(** Static timing of a PIO program over every path, in state machine cycles. Each edge
    gets a lower bound on the pulse it ends and each rule its worst case; [phase] counts
    from the last [wait] on a pin, where a receiver locks. Times are at the pin driver,
    not at the bus's 30% and 70% levels: rise and fall times are the caller's to subtract.
    Other drivers may hold a released open-drain pin low, unless [no_stretch]. *)

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
  (** How a write shows on the pin: as its level, as its direction bit where the pin is
      high when the bit is set ([Dir], open drain with the output enable inverted), or low
      when it is set ([Dir_low], open drain driving a 0). *)
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
    ; initial : bool option (** Output level on entry; unknown when [None]. *)
    }
  [@@deriving sexp_of]

  (** ["sda=set0:dir,out0:dir,in0,jmp"]: a name, then each binding as [side|set|out]N with
      an optional [:dir] or [:!dir], or [inN], [gpioN], [jmp]. *)
  val of_string : string -> t Or_error.t
end

module Edge : sig
  type t =
    { pin : string
    ; rising : bool option (** Either edge when [None]. *)
    }
  [@@deriving sexp_of]
end

module Time : sig
  type t =
    | Cycles of int
    | Ns of float
  [@@deriving sexp_of]
end

(** Every [target] edge comes at least [at_least] after the last [source] edge. Sound for
    minimum pulse widths and setup and hold times between pins. *)
module Rule : sig
  type t =
    { name : string
    ; source : Edge.t
    ; target : Edge.t
    ; at_least : Time.t
    }
  [@@deriving sexp_of]

  (** ["t_hd_sta: sda- -> scl- >= 4us"]; edges end in [+], [-] or nothing for either;
      times in [ns], [us] or cycles ([cy]). *)
  val of_string : string -> t Or_error.t
end

module Clock : sig
  type t =
    { sys_hz : float
    ; clkdiv : float
    }
  [@@deriving sexp_of]

  (** The divider the hardware runs when [clkdiv] is the float given to
      [sm_config_set_clkdiv]: 16 integer and 8 fraction bits, rounded to the nearest 1/256
      as pico-sdk does by default. *)
  val effective_div : t -> float
end

module Exec_sequence : sig
  type t =
    { guard : (string * int) list
    (** Output levels, and [x] or [y], the sequence may start from; the registers are
        assumed to hold the value when it does. *)
    ; instructions : Pioasm.Instruction.t list
    }
  [@@deriving sexp_of]

  (** ["x=1,scl=1: set pindirs, 0 side 1 [7] | set pindirs, 0 side 0 [7]"]; the guard is
      optional. *)
  val of_string : Pioasm.Program.t -> string -> t Or_error.t
end

module Config : sig
  type t =
    { pins : Pin.t list (** Empty: [side0], [set0], [out0] and the inputs by position. *)
    ; autopull : bool
    ; autopush : bool
    ; fifo_ready : bool
    (** FIFO accesses never stall: the CPU or DMA keeps up. Waits still stall. *)
    ; irq_wait_halts : bool
    (** An [irq wait] never releases into the next instruction: the CPU restarts the
        machine elsewhere, as SDK error handlers do. *)
    ; set_count : int
    ; out_count : int
    ; exec : Exec_sequence.t list
    (** The sequences [out exec] and [mov exec] run, each whole and in order, any one
        whose guard the pins may meet after any other. An exec where no guard may hold,
        and a guard on anything but [x], [y] or an output, are errors. *)
    ; clock : Clock.t option
    ; rules : Rule.t list
    ; cell : int option
    (** Cycles per bit cell of an input locked at each [wait]; gives the sender clock
        error every sample tolerates, in system clocks when [clock] is known. *)
    ; entry : string option (** The label the state machine starts at; else address 0. *)
    ; no_stretch : string list
    (** Open-drain outputs no other driver holds low, so a release rises at once. Any
        other release rises at an unknown later time, until a [wait] sees it high. *)
    }
  [@@deriving sexp_of]

  val default : t
end

module Report : sig
  type t [@@deriving sexp_of]

  (** Every rule was checked on some path and none is broken, every path was modelled, and
      with a [cell] every sample lands in its cell with a sender at the rate asked for. *)
  val passed : t -> bool

  (** A row per instruction (and per [exec]'d instruction): address, text, cycles ([+]
      where it may stall), phase at issue, then edges ([pin+ width], [pin- width]),
      samples and [anchor] where a wait releases. Then each rule's worst case. *)
  val to_string : t -> string
end

val analyse : Config.t -> Pioasm.Program.t -> Report.t
