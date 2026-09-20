<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

A small programmable core bit-bangs the pins with cycle-exact timing, so UART, SPI and
I2C are programs, not fixed logic. Firmware lives in a 512-word IHP SRAM macro and is
loaded at runtime by the host over SPI.

Instructions are 16-bit words with eight opcodes: `jmp`, `wait`, `in`, `out`, `mov`,
`set`, `alu` and `sys`. Each takes one cycle plus its delay field; a jump always takes
two. Timing comes from a 24-bit free-running counter `now` and a deadline register `t`:
`wait t` stalls until `now` reaches `t`, and `wait t+` also moves `t` on by the period
register `p`, so a loop makes edges at exact multiples of `p` however many instructions
run in between. An input capture unit latches `now` on a chosen pin edge so a receiver
can anchor its deadlines to the incoming signal. Two 4-deep fifos carry data to and
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
`OUT0` to `OUT6`, and 12 to 19 are `IO0` to `IO7`, whose directions firmware sets.

The host port is an SPI slave on `ui[0]` (SCK), `ui[1]` (MOSI), `ui[2]` (CS_N) and
`uo[0]` (MISO), SCK at most one eighth of the clock. A frame is a command byte, write
bit then a seven-bit register number, followed by 16-bit words high byte first; several
words in one frame repeat the access, which streams the fifos and the program window.

| Register | Name | Notes |
|---|---|---|
| 0 | control | bit 0 start, bit 1 clear irq |
| 1 | status | pc, halted, irq, fault bits, fifo levels |
| 2 | pc | |
| 3, 4 | now | low and high words of the counter |
| 5, 6 | capture | low and high words of the last captured time |
| 7 | tx fifo | write pushes a word for the core |
| 8 | rx fifo | read pops a word from the core |
| 9 | program address | |
| 10 | program word | write increments the address |
| 16 on | config | pin bases and counts, side-set, shift directions, autopush and autopull |

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
tests under `test/` run UART, SPI master and slave, and I2C master and slave firmware
against protocol models and against the hardware.

## External hardware

None required. A USB serial adapter on `OUT0` shows the UART demo; an I2C sensor or an
SPI flash on the `IO` pins for the other firmware.
