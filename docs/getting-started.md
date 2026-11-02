# Getting started

## Try it

No install: the [playground](https://marcosash.github.io/protocol-emulator/playground/) runs
the kernel in your browser. Paste firmware and it accepts or refuses it, and says why.

With the OxCaml switch, `5.2.0+ox`, here is the same thing on the command line.
`test/uart_tx.asm` is a UART transmitter at 16 cycles a bit. Give its `out` 13 cycles of
delay and the bit loop no longer fits in a period, so the assembler says where and exits 1.
With 12 it passes, at slack 0.

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

On the Tiny Tapeout demo board that sends 0x55 and 0xA3 as two frames on `uo[1]`. No Tiny
Tapeout board has run it yet. `make -C test COCOTB_TEST_FILTER=test_uart_over_spi` runs it
under cocotb.

## Build

Needs the OxCaml switch, and OSS CAD Suite and cocotb for `formal/` and `test/`. Without
OCaml, the [latest release](https://github.com/MarcosAsh/protocol-emulator/releases/latest)
has `generate-linux-x86_64` (Ubuntu 24.04 or newer).

```
opam install . --deps-only --with-test --locked
make -C formal sat_tools   # cadical and cake_lpr; put formal/sat_tools/bin on PATH
dune build @runtest
dune exec -- bin/generate.exe top -sram -engines 2 > src/protocol_emulator.v
make -C formal             # hours; CI runs the long proofs in jobs of their own
```

`make -C test COCOTB_TEST_MODULES=test_demo` runs the self-timing and keyboard demos with no
board in about 17 minutes. Each claim's last green run in CI is on the
[results page](https://marcosash.github.io/protocol-emulator/results/).

To harden the chip, see [Hardware](hardware.md#harden).
