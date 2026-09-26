(** Compiles a Hardcaml state machine into firmware for one engine.

    It reads the circuit, not the source: for every state it fixes the state register and
    folds the netlist into what each register becomes, then maps that onto instructions.
    The subset it takes, and it refuses anything else with the state and the assignment at
    fault:

    - One [Always.State_machine] with its state names in the waveform format, which is the
      default, and plain [Always.Variable.reg]s with constant clears and no enables.
    - The tick: a register that counts up to a constant and back to zero, as [enable_rate]
      does in [Uart.Tx] of hardcaml_hobby_boards. Its constant is [p].
    - One output, a one bit register: the pin OUT0. It takes constants, or bit 0 of the
      shift register.
    - A shift register loaded from an input and shifted right by one: [osr].
    - A counter set to a constant, incremented, and compared with a constant to leave a
      state: [x], counted down by [jmp x--].
    - Every state either runs on the tick, all of it, or waits for one input bit while it
      restarts the tick; the input's partner, if one is loaded, is the tx fifo. What such
      a state does outside its wait must be the same done once or every cycle, and must
      not touch the pin.

    A state on the tick becomes [wait t+] and its pin write, so the edge is one cycle
    after the release; a state that waits becomes [wait tx], and on the take [mov t, now]
    and the pin write, so the edge is one cycle after the anchor. From either anchor to
    the next [wait t+] must fit in the tick, or the state is refused with the cycles it
    needs. *)

open! Core
open! Hardcaml

module Firmware : sig
  type t =
    { source : string
    ; program : Asm.Program.t
    ; config : Program_config.t
    ; period : int
    ; period_from_host : bool
    (** A period too long for [set p] is the first word the host writes, before any data. *)
    }
end

val compile : Circuit.t -> Firmware.t Or_error.t
