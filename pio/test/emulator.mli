(** A cycle-level model of one RP2040 PIO state machine at an integer divider. It is
    written from the datasheet, independently of [Timing], to check [Timing]'s bounds
    against real runs. The surroundings are random: FIFO traffic, irq flags, inputs, and
    other drivers that keep a released open-drain pin low once it is low (unless
    [no_stretch]). *)

open! Core
open Pio

module Edge : sig
  type t =
    { pin : string
    ; rising : bool
    ; time : int
    ; own : bool
    (** The machine changed its drive, as opposed to another driver letting go. *)
    }
end

module Setup : sig
  type t =
    { pull_threshold : int
    ; push_threshold : int
    ; shift_left : bool
    ; exec : (int * Pioasm.Instruction.t) list (** What [out exec] runs, by word. *)
    ; tx : int Sequence.t option (** The TX words in order, or random ones when [None]. *)
    ; divider : int
    (** System clocks per machine cycle. Edge times are in system clocks. *)
    ; tx_chance : float
    (** Chance of a TX word arriving each system clock, unless [fifo_ready]. *)
    }

  val default : t
end

(** The edges on [config]'s output pins over [cycles] system clocks. Stops at an
    [irq wait] when [irq_wait_halts]. *)
val run
  :  ?setup:Setup.t
  -> Timing.Config.t
  -> Pioasm.Program.t
  -> seed:int
  -> cycles:int
  -> Edge.t list
