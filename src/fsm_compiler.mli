(** Compiles a Hardcaml state machine into firmware for one engine.

    It folds the netlist per state, not the source. Anything outside this subset is
    refused with the state and assignment at fault:

    - One [Always.State_machine] (waveform state names) and plain regs with constant
      clears and no enables. Regs the pin and state never read, and states the clear never
      reaches once constants fold, are dropped.
    - A tick counting to a constant and back to zero, as [enable_rate] in
      hardcaml_hobby_boards' [Uart.Tx]: becomes [p].
    - One 1-bit output register, pin OUT0, taking constants or bit 0 of the shift
      register.
    - A shift register loaded from an input, shifted right by one: [osr].
    - A counter set, incremented and compared with constants: [x], via [jmp x--].
    - Each state runs wholly on the tick, or waits for one input bit (partnered with the
      tx fifo) restarting the tick; outside the wait it must be idempotent and leave the
      pin.

    A tick state becomes [wait t+] and its pin write; a waiting state becomes [wait tx],
    then [mov t, now] and the pin write. Edges land one cycle after the anchor. Each
    anchor to the next [wait t+] must fit in the tick, or the state is refused with the
    cycles it needs. *)

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
