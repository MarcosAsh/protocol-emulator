# protocol-emulator

An entry for Jane Street's protocol emulator ASIC competition, written in Hardcaml and
built on IHP CMOS5L through Tiny Tapeout, in 6 x 4 tiles at 50 MHz.

![from firmware to silicon](docs/chain.svg)

Two small cores bit-bang the pins from firmware. The timing is explicit: there is a 24-bit
clock, a deadline register `t` and a period `p`. `wait t+` releases on the exact cycle and
moves the deadline on by one period, so a frame never drifts. An analyser refuses any
program that could miss a deadline, and a small kernel, proved sound against the RTL,
checks what it certifies. So if a firmware assembles with the timing check on, the RTL is
proven never to miss one of its deadlines, under the assumptions below.

## From source to pins

`test/uart_tx.asm` is a UART transmitter at 16 cycles a bit. Give its `out` 13 cycles of
delay and the bit loop no longer fits in a period: the assembler says where and exits 1.
With 12 it passes, at slack 0. The commands need the OxCaml switch, `5.2.0+ox`.

```
$ dune exec -- bin/generate.exe assemble -listing test/uart_tx.asm
...
15 words, 3 deadline waits, worst slack 12
kernel: accepted, so no deadline is missed by the step lemma
$ sed 's/out pins, 1/out pins, 1 [13]/' test/uart_tx.asm > late.asm
$ dune exec -- bin/generate.exe assemble late.asm
late.asm: 3 of 3 deadline waits may be missed
  8  wait t+                      phase -13..?  slack ?..13  MAY MISS
...
```

The host loads the words, `test/uart_tx.hex`, over SPI with `python/protocol_emulator.py`:

```python
host = demo_board.host()
host.configure(DEFAULT_CONFIG)  # set and out base at pin 5, which is uo[1]
host.load(hex_words(open("uart_tx.hex").read()))
host.push([0x55, 0xA3])
host.start()
```

On the Tiny Tapeout demo board that sends 0x55 and 0xA3 as two frames on `uo[1]`. No
board has run it yet; `make -C test TESTCASE=test_uart_over_spi` runs it under cocotb.

## What is proved

- One theorem covers every program: if the kernel accepts it, it never misses a deadline.
  `src/kernel.ml` is a checker you can read in one sitting; `formal/phase_step.sv` with a
  SAT query in `test/test_kernel.ml` proves it, and so does `formal/phase_table.sby`.
- The hardened netlist equals the RTL for all time from all flops 0 (`netlist_equiv` job).
- When the host talks reaches the pins only through the program's own fifo waits and
  tests, or a fault. Like the other lemmas in `formal/`, it has weakened copies that must
  fail (`make -C formal teeth`).
- The kernel accepts all 19 library firmwares (UART, SPI, I2C, USB, WS2812, 1-Wire, PS/2,
  JTAG, CAN, 10BASE-T); `test/test_certified.ml` lists each with its slack and assumptions.
- hardcaml_hobby_boards' `Uart.Tx`, compiled to firmware, drives the core's pin as the
  circuit drives its line, 4 cycles later, at 4 clocks a bit, for bytes at least 4 cycles
  after ready (`make -C formal fsm_miter`).
- Each UNSAT in the SAT proofs is checked by cake_lpr, an LRAT checker verified in HOL4.

## What is not proved

- Trusted: Yosys, SymbiYosys, boolector, ABC, cake_lpr, hardcaml_verify's translation of
  gates into clauses, `Bits` agreeing with `Comb_gates`, stated facts of arithmetic modulo
  2^24, IHP's behavioural SRAM model, and the PDK's models and the flow's timing analysis.
- The theorem assumes every write to `p` other than a `set` leaves the checked period; a
  receiver's capture pin is at the other level at `capture_arm` and, once at the captured
  level, stays there until the wait releases; the core runs the words and configuration
  the kernel checked, with zeros past the program; the host loads and starts a core only
  while halted; the configuration is fixed from power-on, the only reset; and side-set
  count is at most 2. It says nothing of the underflow and overflow a slow host can cause.
- Tested, not proved: the core against its model beyond the decoder, deadline compare, pin
  rotation and data path values, on every library firmware and on random programs; which
  host words the pins carry, for all but five transmitters; the protocols, against models
  we wrote; USB enumeration, which the board does in `python/usb_board.py`.
- Nothing has run on a board or on silicon yet.

## Build

Needs the OxCaml switch, and OSS CAD Suite and cocotb for `formal/` and `test/`.

```
opam install . --deps-only --with-test --locked
make -C formal sat_tools   # cadical and cake_lpr; put formal/sat_tools/bin on PATH
dune build @runtest
dune exec -- bin/generate.exe top -sram -engines 2 > src/protocol_emulator.v
make -C formal             # hours; CI runs the long proofs in jobs of their own
```

To harden, clone TinyTapeout/tt-support-tools, branch `ihp-sg13cmos5l`, into `tt/`, then
`tt/tt_tool.py --create-user-config --ihp` and `--harden --ihp`. Gds run 36615334436, on
this Verilog, signs off with setup slack +3.641 ns at the slow corner, at 49.6%
utilisation.

![the hardened design](docs/die.png)
