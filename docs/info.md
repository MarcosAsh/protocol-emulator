<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Two small programmable cores bit-bang the pins with cycle-exact timing, so UART, SPI
and I2C are programs, not fixed logic. Each core's firmware lives in its own 512-word IHP
SRAM macro and is loaded at runtime by the host over SPI. A second 512-word macro per
core holds data the host loads, a frame or a string of pixels, which autopull streams
out as fast as a word a cycle from wherever `seek` points it. In Manchester mode an
`out pins, 1` drives a bit as a pair of pins, complement first, and the pair flips when
the next instruction issues, which is what lets a four-cycle loop send 10BASE-T.

Instructions are 16-bit words with eight opcodes: `jmp`, `wait`, `in`, `out`, `mov`,
`set`, `alu` and `sys`. Each takes one cycle plus its delay field; a jump always takes
two. Timing comes from a 24-bit free-running counter `now` and a deadline register `t`:
`wait t` stalls until `now` reaches `t`, and `wait t+` also moves `t` on by the period
register `p`, so a loop makes edges at exact multiples of `p` however many instructions
run in between. A period that is not a whole number of cycles, 416 2/3 for 115200 baud
at 48 MHz, takes its fraction from the configuration and never drifts. An input capture
unit latches `now` on a chosen pin edge so a receiver can anchor its deadlines to the
incoming signal. Two 8-deep fifos carry data to and
from the host; they never stall the core, and a sticky fault register records an
underflow, an overflow, a missed deadline or a word that does not decode. Side-set
drives up to two pins on every instruction, which gives an SPI clock for free and, in
pin-direction mode, an open-drain I2C bus.

A UART transmitter at 115200 baud from the 50 MHz clock:

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

The pins form one flat index space for firmware: 0 to 4 are `IN0` to `IN4`, 5 to 11 are
`OUT0` to `OUT6`, and 12 to 19 are `IO0` to `IO7`, whose directions firmware sets. 20 to
27 are wires that stay inside the chip: firmware drives and reads them like pins, and
the two cores talk to each other over them. A pin or wire both cores drive carries the OR
of the two.

The host port is an SPI slave on `ui[0]` (SCK), `ui[1]` (MOSI), `ui[2]` (CS_N) and
`uo[0]` (MISO), SCK at most one eighth of the clock. A frame is a command byte, write
bit then a seven-bit register number, followed by 16-bit words high byte first; several
words in one frame repeat the access, which streams the fifos and the program window.

| Register | Name | Notes |
|---|---|---|
| 0 | control | bit 0 start, bit 1 clear irq, bit 2 stop, bit 3 flush both fifos, bit 4 resume from the pc, bit 5 single step; the program and the config are only written, and the fifos only flushed, while the core is halted |
| 1 | status | pc, halted, irq, fault bits, fifo levels |
| 2 | pc | |
| 3, 4 | now | low and high words of the counter |
| 5, 6 | capture | low and high words of the last captured time |
| 7 | tx fifo | write pushes a word for the core |
| 8 | rx fifo | read pops a word from the core |
| 9 | program address | |
| 10 | program word | write increments the address |
| 11 | select | 0 or 1, the core every register but the program and data addresses reaches; status bit 15 says the other core has its irq up |
| 12 | data address | |
| 13 | data word | write increments the address; only while the core is halted |
| 16 on | config | pin bases and counts, side-set, shift directions, autopush and autopull, CRC, stuffing, wrap, period fraction, breakpoint, autopull from data, Manchester |
| 64 to 71 | debug | read only: x, y, p, t low and high, isr, osr, and the isr count with the osr count shifted up 8 |

The design is written in Hardcaml. The same OCaml model of the core is the executable
specification, the reference the hardware runs against in lockstep, and the input to a
static timing analyser that bounds every pin edge of a program before it runs.

## How to test

`python/protocol_emulator.py` runs on CPython and MicroPython and needs only a function
that exchanges one SPI frame. `python/demo_board.py` does that on the Tiny Tapeout demo
board. To see the UART transmitter above: assemble it with
`dune exec -- bin/generate.exe assemble uart.asm`, then `configure`, `load`, `start`
and `push` two bytes; the frames appear on `uo[1]` (`OUT0`) at 115200 baud.

`test/test.py` is the same sequence under cocotb against the Verilog, and the OCaml
tests under `test/` run UART, SPI and I2C masters and slaves, a low speed USB keyboard
and mouse, WS2812, 1-Wire and PS/2 firmware against protocol models and against the
hardware.

## External hardware

None required. A USB serial adapter on `OUT0` shows the UART demo; an I2C sensor or an
SPI flash on the `IO` pins for the other firmware.
