# Verification

What is proved, what is assumed or only tested, and how we tried to break it. Each claim's
last green run in CI is on the [results page](https://marcosash.github.io/protocol-emulator/results/).

## What is proved

- One theorem covers every program: if the kernel accepts it, it never misses a deadline.
  `src/kernel.ml` is a checker you can read in one sitting. `formal/phase_step.sv` with a
  SAT query in `test/test_kernel.ml` proves the theorem, and so does
  `formal/phase_table.sby`, with `formal/phase_table_affine.sby` for Ethernet.
- The hardened netlist equals the RTL for all time from all flops 0 (`netlist_equiv` job).
- When and how the host talks reaches the pins only through the program's own fifo waits
  and tests, or a fault. Like the other lemmas in `formal/`, it has weakened copies that
  must fail (`make -C formal teeth` and the other `*_teeth` targets, all run in CI).
- A fault is fail-safe: from the edge it shows, a faulted engine drives no pin, and it halts
  until the next clear, whatever the host does with its fifos, pads and clear. The proof
  holds each engine's configuration fixed (`formal/fail_safe.sv`).
- Two engines composed: uart_tx on engine 0 to uart_rx on engine 1 over an on-chip wire,
  10 cycles a bit, is proved for all time, as long as engine 1's rx fifo never overflows.
  Engine 1 pushes the low byte of each word engine 0 pulled, once a frame
  (`formal/link.sby`, the `link` job).
- hardcaml_hobby_boards' `Uart.Tx`, compiled to firmware, drives the core's pin as the
  circuit drives its line, 4 cycles later, at 4 clocks a bit, for bytes at least 4 cycles
  after ready (`make -C formal fsm_miter`).
- `Self_check.checker` is firmware that checks a pin's edges against rows from the kernel.
  For one set of edges on pin 0, rows at 0, on one engine with a private data memory (not
  the chip's shared one), its program and rows as ROMs and the host idle, it raises no irq,
  never halts and misses none of its own deadlines until the line leaves its rows, for all
  time (`formal/self_check_clean.sby`, witness checked by cake_lpr in the `witness` job).
  Its irq by the contract's deadline after a break is proved only for 116 cycles from the
  clear, which reach the first frame's deadline only if the first fall comes by about cycle
  22 (`formal/self_check.sby`).
- Power-up is deterministic. Two copies of the chip from any two states of their flops and
  fifos, with the same words in their SRAMs, reset at the first edge and given the same
  pins, drive the same pins (`formal/powerup.sby`).
- Each UNSAT in the SAT proofs is checked by cake_lpr, an LRAT checker verified in HOL4.
  Each SAT answer counts only once its model satisfies every clause the solver was given.

## What is not proved

- Trusted: Yosys, SymbiYosys, boolector, ABC, cake_lpr, Certifaiger and the aiger tools for
  the witnesses, hardcaml_verify's translation of gates into clauses, `Bits` agreeing with
  `Comb_gates`, stated facts of arithmetic modulo 2^24, IHP's behavioural SRAM model, the
  self-check's contract (`test/self_check_contract.ml`), and the PDK's models and the flow's
  timing analysis.
- The theorem assumes that:
  - every write to `p` other than a `set` leaves the checked period
  - a receiver's capture pin is at the other level at `capture_arm` and, once at the
    captured level, stays there until the wait releases
  - the core runs the words and configuration the kernel checked, with zeros past the
    program
  - the configuration is fixed from power-on, the only reset
  - side-set count is at most 2
- The kernel runs on the host before loading, not on the chip. Firmware that skips it gets
  the fail-safe, not the theorem.
- The theorem says nothing of the underflow and overflow a slow host can cause.
- Tested, not proved:
  - the core against its model beyond the decoder, deadline compare, pin rotation and data
    path values, on every library firmware and on random programs
  - which host words the pins carry, for all but five transmitters
  - the protocols, against models we wrote, and at the RTL's pins against sigrok's decoders
    for UART, SPI, I2C, CAN data frames, CEC, 1-Wire, PS/2, JTAG, low speed USB and WS2812
    (`demo/decode.py`, the `decode` job)
  - USB enumeration, which the board does in `python/usb_board.py`
- Nothing has run on silicon yet. On an Icepi Zero FPGA (ECP5, 48 MHz) running the chip's
  RTL, `python/demo_self_timing.py` passed on 2026-10-09: engine 1 stamped all 52 edges of
  engine 0's `Jane St!` at 9600 baud on the predicted cycles, quiet and with the host
  flooding SPI with reads. The USB keyboard (`python/demo_usb.py`) passed there on
  2026-10-02 (release v0.2.0).

## Trying to break it

A checker is only worth something if it fails when it should, so most checks here come with
a way to make them fail.

| Check | What we did | Result |
|---|---|---|
| Planted delays, run | at every deadline wait of the 7 swept firmwares, 1 to 3 cycles of `nop`, half the slack, and every count from one short of the slack to three past, each run on the model (`test/test_delay_variants.ml`) | 283 planted. The kernel certified 181 and none ran late. It refused 102, and 92 of those did run late. The other 10 are late only on paths the test's input never takes |
| One cycle late, everywhere | every deadline wait in the library given one cycle more than its slack (`test/test_late_mutants.ml`) | 521 refused by the kernel. The other 46, all of ir_rc6 and nec_tx and one each in ethernet and nec_rx, can't be planted: the extra cycles push the program past its 512 words, so the assembler refuses it first |
| Mutants | the tests against mutants of the engine, decoder, pins and host port | the tests kill 112 of 114 valid mutants (mutation run 39462087759, 2026-10-20). The other 2 are equivalent, see `test/mutation_allow.txt` |
| Weakened proofs | each lemma in `formal/` has copies with a premise dropped (`make -C formal teeth` and the other `*_teeth` targets) | every copy fails, as it must |
| Loose limits | which firmware its datasheet limits don't hold within a factor of two (`test/test_datasheet.ml`) | lfast and swd are loose, ir_rc6 and nec_tx have no limits, each listed with why |

Counted on 2026-09-30, of 13 bugs fixed in commits of their own, model tests found 3, the
analyser's soundness check 3, AI review 3, proofs 2, the analyser 1 and a mutant 1. Among
them were a showahead `Fifo` holding one word over its capacity (mutant, a67aa23), a stale
power-up word at an empty rx fifo's head (proof, ae5e91d) and an `add t, x` after a spent
`jmp x--` certified 65536 cycles wrong (soundness check, 99d55ee).
