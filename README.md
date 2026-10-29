# protocol-emulator

A small chip that bit-bangs protocols from firmware, and a checker that proves the firmware's
timing before it ever runs. Written in Hardcaml for Jane Street's protocol emulator ASIC
competition, built on IHP CMOS5L through Tiny Tapeout, in 6 x 4 tiles at 48 MHz.

Before a program is loaded, a small kernel checks a certificate of its timing, and if it
accepts the program, that program never misses a deadline on the chip, under the assumptions
listed in the docs.

Documentation: https://marcosash.github.io/protocol-emulator/

| | | Source |
|---|---|---|
| Process | IHP SG13CMOS5L through Tiny Tapeout, 6 x 4 tiles | `info.yaml`, `.github/workflows/gds.yaml` |
| Clock | 48 MHz | `info.yaml` |
| Cores | 2 cores, 3 IHP 512 x 16 SRAM macros: a program memory each and a data memory they share | `src/protocol_emulator.v` |
| Pins | 4 for the host's SPI, 5 in, 7 out, 8 bidirectional, and 8 wires between the cores | `info.yaml`, `src/isa.ml` |
| Hardened | 23,517 standard cells at 49.6% utilisation, setup slack +3.487 ns at the slow corner, precheck clean | gds run [39277515192](https://github.com/MarcosAsh/protocol-emulator/actions/runs/39277515192) |
| Firmware | 54 library firmwares the kernel accepts | `test/test_kernel.ml` |
| Proved | a program the kernel accepts never misses a deadline on each core's RTL, under the assumptions below | `formal/phase_table.sby`, `formal/phase_table_affine.sby` |
| Board | the RTL on an Icepi Zero (ECP5 FPGA) passed the self-timing demo on 2026-10-09, no silicon yet | `python/demo_self_timing.py` |

`test/uart_tx.asm` is a UART transmitter at 16 cycles a bit. Give its `out` 13 cycles of
delay and the bit loop no longer fits in a period, so the assembler says where and exits 1.

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

The [playground](https://marcosash.github.io/protocol-emulator/playground/) runs the same
kernel in your browser. Each claim's last green run in CI is on the
[results page](https://marcosash.github.io/protocol-emulator/results/).

What is not proved, every assumption and what is only tested: [docs/verification.md](docs/verification.md#what-is-not-proved).
How AI was used, each use with its gate and what went against it: [docs/ai-use.md](docs/ai-use.md).

## Building it

Needs the OxCaml switch, `5.2.0+ox`, and OSS CAD Suite and cocotb for `formal/` and `test/`.

```
opam install . --deps-only --with-test --locked
make -C formal sat_tools   # cadical and cake_lpr; put formal/sat_tools/bin on PATH
dune build @runtest
```

The proofs, the cocotb demos and the harden are in [docs/getting-started.md](docs/getting-started.md).

License: Apache-2.0. The bench PCB is CERN-OHL-P v2.
