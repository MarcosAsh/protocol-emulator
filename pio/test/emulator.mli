(** A cycle-level model of one RP2040 PIO state machine at a divider of 1, written from
    the datasheet apart from [Timing], to test its bounds against runs. Its surroundings
    are random: FIFO traffic, irq flags, inputs, and other drivers holding low a released
    open-drain pin that is low, unless [no_stretch]. *)

open! Core
open Pio

module Edge : sig
  type t =
    { pin : string
    ; rising : bool
    ; time : int
    ; own : bool (** The machine changed its drive, not another driver letting go. *)
    }
end

module Setup : sig
  type t =
    { pull_threshold : int
    ; push_threshold : int
    ; shift_left : bool
    ; exec : (int * Pioasm.Instruction.t) list (** What [out exec] runs, by word. *)
    ; tx : int Sequence.t option (** The TX words, in order; random when [None]. *)
    }

  val default : t
end

(** The edges on [config]'s output pins over [cycles] cycles, until an [irq wait] when
    [irq_wait_halts]. *)
val run
  :  ?setup:Setup.t
  -> Timing.Config.t
  -> Pioasm.Program.t
  -> seed:int
  -> cycles:int
  -> Edge.t list
