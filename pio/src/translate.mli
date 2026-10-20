(** RP2040 and RP2350 PIO programs translated to the core's ISA in PIO time. A PIO cycle
    is [k] cycles here, [per_cycle] [wait t+]s of [p] and [fraction] each, and a step's
    pin write, sample or side-set issues the cycle after its first, so each pin edge shows
    at [k] times its PIO cycle plus one latency. A wait or a stall re-anchors [t] at its
    release. What the core cannot keep is refused by name; what it keeps only under a host
    contract says so in [contract].

    {v
    PIO                           here
    delay [d]                     (1 + d) * per_cycle wait t+ in all
    side-set, opt                 side on every word, its value followed per path;
                                  by set where out shares the pins
    set, mov, in, out (<= 16)     the same word, 16-bit data
    out null, 32                  out null, 16
    autopull threshold over 16    the host splits each word, 24 bits as 12 and 12
    jmp !x, !y                    jmp x--, add x, 1 on both ways
    jmp !osre with autopull       jmp !osre, then jmp tx (an empty OSR refills at once)
    jmp pin with side-set         side first, jmp pin the cycle after
    wait pin, jmppin              wait pin, re-anchor
    pull, push, autopull (block)  jmp tx|rx|!osre past a stall copy: wait, op, re-anchor
    pull, push noblock            jmp !tx|!rx to mov osr, x | mov isr, null
    out exec (with a table)       the entry's index from the host, x saved in p
    irq, irq wait                 irq; irq wait halts too, and the host restarts it
    refused                       irq clear, wait irq, wait gpio, mov|out pc, mov status,
                                  mov exec, mov ~ into a register, mov ::, push iffull,
                                  shifts over 16 bits, side-set over 2 pins
    v} *)

open! Core
open Protocol_emulator

module Setup : sig
  (** An instruction [out exec] may run, and the side-set values, as PIO writes them, it
      may run from; empty for any. *)
  module Exec : sig
    type t =
      { instruction : string
      ; from_sides : int list
      }
    [@@deriving sexp_of]
  end

  type t =
    { period : int (** [p], 2 to 31. *)
    ; fraction : int (** 65536ths of a cycle added to [p]. *)
    ; per_cycle : int (** [wait t+]s a PIO cycle, so [k] is this times [p]. *)
    ; side_set_base : int (** Pins are the core's. *)
    ; set_base : int
    ; set_count : int
    ; out_base : int
    ; out_count : int
    ; in_base : int
    ; in_count : int
    ; jmp_pin : int
    ; out_shift_right : bool
    ; in_shift_right : bool
    ; autopull : bool
    ; pull_threshold : int (** The PIO's, 1 to 32. *)
    ; autopush : bool
    ; push_threshold : int
    ; side_init : int (** The side-set pins before the first step. *)
    ; dirs_inverted : bool
    (** The C code inverts the pins' output enables, as pio_i2c.c does, so a set direction
        bit releases the pin. *)
    ; exec : Exec.t list (** What [out exec] may run, by index. *)
    ; init : string list (** What the C code execs before the start. *)
    ; entry : string option
    }
  [@@deriving sexp_of]

  (** pico-sdk's defaults (shift right, thresholds 32, no autopull or autopush, entry 0)
      and each pin group on pins of its own: outputs written by level on OUT pins, by
      direction on IO pins, inputs on IN pins. *)
  val default : Pioasm.Program.t -> period:int -> t
end

module Refusal : sig
  type t =
    { pc : int option (** [None] for the program as a whole, the exec table or init. *)
    ; feature : string
    }
  [@@deriving sexp_of, compare]
end

type t =
  { source : string (** Assembly, a comment with the PIO line on each step's marker. *)
  ; words : Isa.t list
  ; config : Program_config.t
  ; relation : Relation.t
  ; exec : Pioasm.Instruction.t array
  ; contract : string list (** What the host keeps to, beyond pico-sdk's own use. *)
  }

val translate : Setup.t -> Pioasm.Program.t -> (t, Refusal.t list) Result.t

(** [Relation.check] on a translation. *)
val check_relation : Setup.t -> Pioasm.Program.t -> t -> unit Or_error.t

(** The words the core takes in place of one PIO tx word, as [contract] says. *)
val tx_words : Setup.t -> t -> int -> int list
