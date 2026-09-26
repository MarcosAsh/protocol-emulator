(** What a host owes time-triggered firmware.

    A program is time-triggered when it never waits on a fifo and never jumps on a fifo
    test: those are the only instructions whose timing the host can reach. For such a
    program, [formal/late_host.sv] proves that when the host's words arrive moves no pin
    edge: a word that is late sets the underflow fault instead. So the host has a deadline
    for every word, the last cycle it can write it, and that schedule is fixed by the
    program alone. *)

open! Core

(** Refuses a program with a wait on a fifo or a jump on a fifo test, listing each one by
    address. *)
val time_triggered : Asm.Program.t -> unit Or_error.t

(** For each of the first [words] words the host sends, the last cycle in which it can
    push it into the tx fifo: the cycle before the one the core takes it in. Cycles count
    from the first one the core runs, with the push of cycle [c] in the fifo from [c + 1]
    on, as the hardware has it. [inputs] are the pin levels on every cycle, low unless
    given.

    Runs the model with the fifo kept as full as the host can keep it, which is a run with
    no fault; by the proof it is the run every host that meets the schedule sees. Refuses
    a program that is not time-triggered, that faults, or that has not taken [words] words
    within [max_cycles]. *)
val schedule
  :  ?inputs:int
  -> ?max_cycles:int
  -> config:Program_config.t
  -> Asm.Program.t
  -> words:int
  -> int list Or_error.t
