(** What a host owes time-triggered firmware, meaning firmware that never waits on or
    jumps on a fifo. For such programs [formal/late_host.sv] proves host timing moves no
    pin edge (a late word sets underflow instead), so each word has a deadline fixed by
    the program. *)

open! Core

(** Refuses fifo waits and fifo jumps, listing each by address. *)
val time_triggered : Asm.Program.t -> unit Or_error.t

(** Last push cycle of each of the first [words] words from the core's first cycle (a push
    at [c] is in the fifo from [c + 1]), given [inputs] per cycle. Runs the model with the
    fifo full and replies read at once, which every host meeting the schedule matches.
    Refuses a program that isn't time-triggered, faults, or takes under [words] words. *)
val schedule
  :  ?inputs:int
  -> ?max_cycles:int
  -> config:Program_config.t
  -> Asm.Program.t
  -> words:int
  -> int list Or_error.t
