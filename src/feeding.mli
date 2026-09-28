(** What a host owes time-triggered firmware: one never waiting on or jumping on a fifo.
    For such programs [formal/late_host.sv] proves host timing moves no pin edge (a late
    word sets underflow instead), so each word has a deadline fixed by the program. *)

open! Core

(** Refuses fifo waits and fifo jumps, listing each by address. *)
val time_triggered : Asm.Program.t -> unit Or_error.t

(** Last push cycle for each of the first [words] words, counted from the core's first
    cycle; a push at [c] is in the fifo from [c + 1]. [inputs] are the pin levels on every
    cycle, low unless given. Runs the model with the fifo kept full and replies read at
    once; by the proof every host meeting the schedule sees this run. Refuses a program
    that is not time-triggered, faults, or takes fewer than [words] words in [max_cycles]. *)
val schedule
  :  ?inputs:int
  -> ?max_cycles:int
  -> config:Program_config.t
  -> Asm.Program.t
  -> words:int
  -> int list Or_error.t
