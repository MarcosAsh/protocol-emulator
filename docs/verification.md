# Verification

What is proved, what is assumed or only tested, and how we tried to break it. Each claim's
last green run in CI is on the [results page](https://marcosash.github.io/protocol-emulator/results/).

## What is proved

- One theorem covers every program: if the kernel accepts it, it never misses a deadline.
  The checker is `src/kernel_types.ml`, `kernel_step.ml`, `kernel_accepts.ml` and
  `kernel_table.ml`, 1,837 lines. `formal/phase_step.sv` with a
  SAT query in `test/test_kernel.ml` proves the theorem, and so does
  `formal/phase_table.sby`, with `formal/phase_table_affine.sby` for Ethernet.
- The 74 firmwares `test/certify/write_certificate.exe -names` lists, the library's 68 among
  them, each have their own certificate proved an inductive invariant on one engine with the
  firmware's configuration, line code included. So do a stamped transmitter and 5 firmwares with
  claims on their data (the `inductive_certificate` job, one run a firmware).
- The hardened netlist equals the RTL for all time from all flops 0, and from any state
  once reset (`netlist_equiv` job).
- When and how the host talks reaches the pins only through the program's own fifo waits
  and tests, or a fault. Like the other lemmas in `formal/`, it has weakened copies that
  must fail (`make -C formal teeth` and the other `*_teeth` targets, all run in CI).
- The chip refuses firmware it cannot certify. A start reaches an engine only while it is
  certified, and it is certified only by a walk that began after the last program,
  configuration or line table write, saw no data write land in its engine's data turn or at
  a word it had read, and accepted (`formal/gate.sby`).
  An accepted walk checked every pc against the rows at its successor and its target
  (`formal/certify.sby`). The walk always ends, with the verdict, reject pc and reason of
  the model in `src/load_check.ml` (`formal/complete.sby`). Their covers and weakened
  copies use a short walk and a 32 cycle turn, as a full turn is 65,536 cycles. A walk
  takes 8,192 to 30,545 cycles.
- Engine 0's pins and host reads are the same whatever engine 1 is given, from the clear
  (`formal/isolation.sby`), as long as:
  - no word is routed between them and no start starts both
  - engine 1 drives no pad direction or wire level on a pin engine 0 reads
  - engine 0's data pointer and certificate stay in its data region, engine 1's host writes
    nothing there and engine 1's frames land above it
  - the host writes engine 0's data only while engine 1 is halted and not being walked, and
    no data write lands in the cycle engine 0 starts or the next
  - engine 1 loads nothing while engine 0 has a frame word waiting
  - engine 0's configuration changes only while it is halted
- A fault is fail-safe: from the edge it shows, a faulted engine drives no pin, halts within
  two edges and stays halted until the next clear, whatever the host does with its fifos,
  pads and clear. The proof holds each engine's configuration fixed (`formal/fail_safe.sby`).
- The USB receiver writes any one packet to the data memory as it was sent, at any sampling
  phase: data up to 8 bytes with its CRC-16, a token with its CRC-5, or a handshake. Seven
  1s in a row flag a stuffing error (`formal/usb_roundtrip.sby`). It assumes exactly 8
  samples a bit. `make -C formal usb_roundtrip_64` proves packets up to 64 bytes, and CI
  does not run it.
- The 10BASE-T receiver writes a frame of any length to the data memory as it was sent,
  with the right count and FCS verdict, at 40 and 50 MHz with jitter and drift
  (`formal/frame_roundtrip.sby`).
- The flop program memory the proofs use matches IHP's SRAM model step for step from any
  equal state (`make -C formal sram_equiv`).
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

- Trusted: Yosys, SymbiYosys, boolector, yices, z3, ABC, cake_lpr, Certifaiger and the aiger
  tools for the witnesses, hardcaml_verify's translation of gates into clauses, `Bits`
  agreeing with `Comb_gates`, facts of arithmetic modulo 2^24 (z3 checks them,
  `make -C formal offset_axioms`), IHP's behavioural SRAM model, the self-check's contract
  (`test/self_check_contract.ml`), the PDK's models and the flow's timing analysis, the
  flow from the netlist `netlist_equiv` reads to the GDS, and nextpnr and ecppack after the
  netlist `icepi_equiv` reads. The proofs use engine copies that `formal/Makefile` generates
  apart from the chip's Verilog, from the same OCaml.
- The theorem assumes that:
  - every write to `p` other than a `set` leaves the checked period
  - a receiver's capture pin is at the other level at `capture_arm` and, once at the
    captured level, stays there until the wait releases
  - the core runs the words and configuration the kernel checked, with zeros past the
    program
  - the configuration is fixed from power-on, the only reset
  - the configuration has `line_code` and `route` off
  - side-set count is at most 2
- The chip's certificate rows carry no spacing and no slope, so it refuses firmware that
  needs either, even where the host's kernel would accept it.
- The theorem says nothing of the underflow and overflow a slow host can cause.
- Tested, not proved:
  - the core against its model beyond the decoder, deadline compare, pin rotation and data
    path values, on every library firmware and on random programs
  - which host words the pins carry, for all but five transmitters
  - the protocols, against models we wrote, and at the RTL's pins against sigrok's decoders
    for UART, SPI, I2C, CAN data frames, CEC, 1-Wire, PS/2, JTAG, low speed USB and WS2812
    (`demo/decode.py`, the `decode` job)
  - USB enumeration, which the board does in `python/usb_board.py`
  - the gate-level netlist with the router's delays at the slow, typical and fast corners
    (the `gl_sdf` job, 48 runs, all green in gds run 42268510223)
  - that no one-field variant of the library the kernel accepts misses a deadline in a run:
    41,727 accepted and none late (`test/split/split.ml`, the `split` job, run
    40663800189, 2026-10-28)
  - the edge stamps, and the line code tables but for USB's bit stuffing of streams up to 96
    bits (`formal/line_stuff.sby`, bounded). No sigrok decoder reads USB full speed, so the
    USB receiver's traces are checked against our model only
- Nothing has run on silicon yet. On an Icepi Zero FPGA (ECP5, 48 MHz) running the 6 x 4
  chip's RTL, `python/demo_self_timing.py` passed on 2026-10-09: engine 1 stamped all 52
  edges of engine 0's `Jane St!` at 9600 baud on the predicted cycles, quiet and with the
  host flooding SPI with reads. The USB keyboard (`python/demo_usb.py`) passed there on
  2026-10-15 (release evidence-2026-10-15). The 8 x 4 chip's RTL has since run on the same
  board, bitstream sha256 012dc5e1b0769f12, and `test/board/` holds 42 witnesses, each with
  its bitstream hash:
  - the 21 bench demos, self-timing and keyboard included, recorded 2026-11-03 (release
    evidence-2026-11-03). eth_rx ran on a 40 MHz build, sha256 c426327526b6b574
  - the 8 held-out protocols, recorded 2026-11-07 (see [Flexibility](flexibility.md))
  - `kernel_vs_board`, 2026-11-07: 3,735 delay variants of 8 firmwares, 3,711 accepted by
    the chip and on time, 24 refused by the chip and the kernel alike
  - `fault_release`, 2026-11-11: engine 0 holds SWDIO low against its pull-up, and the
    line rises when the engine faults
  - `spdif_ac3` (2026-11-10) and `spdif_codecs` (2026-11-11): FFmpeg reads AC-3, MP3, AAC
    and DTS frames back from a capture of the S/PDIF line
  - `start_hold_pio` and `start_hold_hw`, 2026-11-11: pico-examples' pio_i2c holds every
    START 3.1 us where I2C needs 4.0, and the RP2040's I2C block holds 4.4
  - `usb_fs_device`, 2026-11-11: a Linux host enumerates the chip as a full speed USB
    device, on the FS=1 build, sha256 25d1deeeb29b3c58
  - 6 protocol-learning runs (`learn_*`), committed 2026-11-03

## Trying to break it

A checker is only worth something if it fails when it should, so most checks here come with
a way to make them fail.

| Check | What we did | Result |
|---|---|---|
| Planted delays, run | at every deadline wait of the 8 swept firmwares, 1 to 3 cycles of `nop`, half the slack, and every count from one short of the slack to three past, each run on the model (`test/test_delay_variants.ml`) | 319 planted. The kernel certified 205 and none ran late. It refused 114, and 103 of those did run late. The other 11 are late only on paths the test's input never takes |
| One cycle late, everywhere | every deadline wait in the library given one cycle more than its slack (`test/test_late_mutants.ml`) | 791 of 845 refused by the kernel. The other 54, all of ir_rc6, nec_tx and dali and one each in ethernet and nec_rx, can't be planted: the extra cycles push the program past its 512 words, so the assembler refuses it first |
| Mutants | the tests against mutants of the engine, decoder, pins and host port | the tests kill 127 of 128 valid mutants (mutation run 42283817727, 2026-11-06). The other one is equivalent, see `test/mutation_allow.txt` |
| Weakened proofs | each lemma in `formal/` has copies with a premise dropped (`make -C formal teeth` and the other `*_teeth` targets) | every copy fails, as it must |
| Loose limits | which firmware its datasheet limits don't hold within a factor of two, faster or slower (`test/test_datasheet.ml`) | lfast and swd could run twice as fast. 20 bench firmwares, DALI, CAN, XY2-100, caliper and the I2C and SPI flash ones among them, have no upper limit. ir_rc6 and nec_tx have no limits, each listed with why |

Counted on 2026-09-30, of 13 bugs fixed in commits of their own, model tests found 3, the
analyser's soundness check 3, AI review 3, proofs 2, the analyser 1 and a mutant 1. Among
them were a showahead `Fifo` holding one word over its capacity (mutant, a67aa23), a stale
power-up word at an empty rx fifo's head (proof, ae5e91d) and an `add t, x` after a spent
`jmp x--` certified 65536 cycles wrong (soundness check, 99d55ee).
