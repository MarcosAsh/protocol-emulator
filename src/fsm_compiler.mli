(** Compiles a Hardcaml state machine into firmware for one engine.

    It folds the netlist per state, not the source. Anything outside this subset is
    refused with the state and assignment at fault:

    - One [Always.State_machine] (waveform state names) and plain regs with constant
      clears and no enables. Regs the pin and state never read, and states the clear never
      reaches once constants fold, are dropped.
    - A tick counting to a constant and back to zero, like [enable_rate] in
      hardcaml_hobby_boards' [Uart.Tx]; it becomes [p].
    - One 1-bit output register, pin OUT0, taking constants or bit 0 of the shift
      register.
    - A shift register loaded from an input and shifted right by one; it becomes [osr].
    - A counter that is set, incremented and compared with constants; it becomes [x], via
      [jmp x--].
    - Each state either runs wholly on the tick, or waits for one input bit (partnered
      with the tx fifo) and restarts the tick. Outside the wait it must be idempotent and
      leave the pin alone.

    A tick state becomes [wait t+] and its pin write. A waiting state becomes [wait tx],
    then [mov t, now] and the pin write. Edges land one cycle after the anchor. Each
    anchor-to-next-[wait t+] stretch must fit in the tick, or the state is refused with
    the cycles it needs. *)

open! Core
open! Hardcaml

module Firmware : sig
  type t =
    { source : string
    ; program : Asm.Program.t
    ; config : Program_config.t
    ; period : int
    ; period_from_host : bool
    (** A period too long for [set p] is the host's first word, before any data. *)
    }
end

val compile : Circuit.t -> Firmware.t Or_error.t
