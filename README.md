# protocol-emulator

An entry for Jane Street's protocol emulator ASIC competition, on IHP CMOS5L through
Tiny Tapeout. Written in Hardcaml.

One small core runs firmware that bit-bangs the pins. Instructions are 16-bit words with
eight opcodes (jmp, wait, in, out, mov, set, alu, sys). A 24-bit cycle counter, a deadline
register `t` and a period `p` make the timing explicit: `wait t+` releases on the exact
cycle and then moves the deadline on by one period, so a frame never drifts. Programs
read like PIO:

```
    set p, 434
    set pins, 1
idle:
    wait tx
    pull
    set x, 7
    mov t, now
    set pins, 0
    add t, p
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1
    wait t
    jmp idle
```

The host talks SPI on `ui[2:0]` and `uo[0]`: a register map for control, configuration and
program load, and two fifos for data. The program lives in an IHP SRAM macro.

## Layout

- `src/` the ISA, a cycle-accurate model that serves as the spec, the assembler, the
  decoder, the engine, the host port and the top level. `analyser.ml` bounds firmware
  timing by abstract interpretation so a program can be checked before it runs.
- `test/` expect tests. `firmware.ml` holds UART tx and rx, SPI master and slave and
  I2C master and slave; each runs against a protocol model and in lockstep with the
  hardware. `test.py` drives the generated Verilog with cocotb through the Python host
  library.
- `formal/` a SymbiYosys proof of the issue timing.
- `python/` the host library and a demo script for the dev board.

## Build

```
opam install . --deps-only --with-test --locked
dune build @runtest
dune exec -- bin/generate.exe top -sram > src/protocol_emulator.v
make -C formal
```

Hardening uses the Tiny Tapeout flow: `tt/tt_tool.py --create-user-config --ihp` then
`--harden --ihp`, with a LibreLane plugin that runs the power stripes over the SRAM pins.
