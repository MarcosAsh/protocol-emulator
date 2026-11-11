<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Two small programmable cores bit-bang the pins with cycle-exact timing, so UART, SPI
and I2C are programs, not fixed logic. Each core's firmware lives in its own 512-word IHP
SRAM macro and is loaded at runtime by the host over SPI. A third 512-word macro, shared
by the two cores, holds data the host loads, a frame or a string of pixels, which
autopull streams out as fast as a word every other cycle from wherever `seek` points it.
The cores take turns at it a cycle each, so a pull sooner than that is refused, and the
assembler refuses firmware that can make one. In Manchester mode an
`out pins, 1` drives a bit as a pair of pins, complement first, and the pair flips when
the next instruction issues, which is what lets a four-cycle loop send 10BASE-T.

Instructions are 16-bit words with eight opcodes: `jmp`, `wait`, `in`, `out`, `mov`,
`set`, `alu` and `sys`. Each takes one cycle plus its delay field, and a jump always takes
two. Timing comes from a 24-bit free-running counter `now` and a deadline register `t`:
`wait t` stalls until `now` reaches `t`, and `wait t+` also moves `t` on by the period
register `p`, so a loop makes edges at exact multiples of `p` however many instructions
run in between. A period that is not a whole number of cycles, 416 2/3 for 115200 baud
at 48 MHz, takes its fraction from the configuration and never drifts. An input capture
unit latches `now` on a chosen pin edge so a receiver can anchor its deadlines to the
incoming signal. Two 15-deep fifos carry data to and
from the host. They never stall the core, and a sticky fault register records an
underflow, an overflow, a missed deadline or a word that does not decode. Side-set
drives up to two pins on every instruction, which gives an SPI clock for free and, in
pin-direction mode, an open-drain I2C bus.

A UART transmitter at 115200 baud from the 48 MHz clock. The host sends the bit period,
417 cycles, as its first word:

```
    wait tx
    pull
    mov p, osr
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
bit then a seven-bit register number, followed by 16-bit words high byte first. Several
words in one frame repeat the access, which streams the fifos and the program window.

| Register | Name | Notes |
|---|---|---|
| 0 | control | bit 0 start, bit 1 clear irq, bit 2 stop, bit 3 flush both fifos, bit 4 check the program against its certificate, bit 5 start both cores on one cycle; the program and the config are only written, and the fifos only flushed, while the core is halted; a start reaches only a halted core whose program the check accepted, and a stopped core runs again only from a start, at address 0 |
| 1 | status | bit 0 halted, 1 irq, 2-5 underflow, overflow, missed deadline and decode faults, 6-9 tx level, 10-13 rx level, 14 broken assumption fault, 15 the other core's irq |
| 2 | pc | the core's program counter |
| 3, 4 | now | low and high words of the counter |
| 5, 6 | capture | low and high words of the last captured time |
| 7 | tx fifo | write pushes a word for the core |
| 8 | rx fifo | read pops a word from the core |
| 9 | program address | |
| 10 | program word | write increments the address |
| 11 | select | 0 or 1, the core every register but the program and data addresses, 64 to 66, 70 and 72 to 81 reaches; status bit 15 says the other core has its irq up |
| 12 | data address | |
| 13 | data word | write increments the address; only while both cores are halted |
| 16 on | config | pin bases and counts, side-set, shift directions, autopush and autopull, CRC, stuffing, wrap, period fraction, autopull from data (45), Manchester (46) |
| 43, 44 | reserved | read as zero and take no write |
| 64 | check base | where the certificate starts in the data memory |
| 65 | check loaded | the period every run-time load of `p` carries, or with flag bit 2 the least |
| 66 | check flags | bit 0 a loaded period is set, 1 single capture edge, 2 the loaded period is a floor |
| 67 | check status | bit 0 busy, 1 the last check accepted, 2 certified, 3 a start was refused; a program, config or line table write ends the certification |
| 68, 69 | reject pc, reason | where the last check refused, and why, as `REASONS` in `python/protocol_emulator.py` names it |
| 70 | line address | |
| 71 | line word | the line code table; write increments the address; only while the core is halted |
| 72 | frame control | bit 0 arm, bit 1 sample for 50 MHz (else 40 MHz), or for USB rearm after each packet, bits 2-6 the pin (USB D+), bit 7 USB full speed, bit 8 the core whose data turns take the words |
| 73 | frame base | where the 10BASE-T frame or USB packet lands in the data memory |
| 74 | frame status | bit 15 armed, 14 receiving, 13 dropped, 12 half, 11 FCS (USB CRC-16) good, 10 finished, 9-0 words |
| 75 | USB status | bit 0 CRC-5 good, 1 CRC-16 good, 2 stuff error, 3 aligned |
| 76, 77 | stamp mask, control | pins 0-15, then 16-19 in bits 0-3 and in bit 4 the core whose `now` times them; a write empties the queue |
| 78, 79 | stamp time | the oldest edge's time, low then high: bits 0-7 the top of the time, 8-10 the queue level, 15 an edge lost to a full queue |
| 80, 81 | stamp pins | every pad's level at that edge; reading 81 pops it |

The design is written in Hardcaml. The same OCaml model of the core is the executable
specification, the reference the hardware runs against in lockstep, and the input to a
static timing analyser that bounds every pin edge of a program before it runs.

## How to test

`python/protocol_emulator.py` runs on CPython and MicroPython and needs only a function
that exchanges one SPI frame. `python/demo_board.py` does that on the Tiny Tapeout demo
board. To see the UART transmitter above: assemble it with
`dune exec -- bin/generate.exe assemble -period 417 uart.asm`, and its certificate with
`-certificate` added, then `configure`, `load`, `certify` with `loaded=417`, `start`,
`push` 417 and then two bytes. The frames appear on `uo[1]` (`OUT0`) at 115200 baud.
Without the certify step the chip refuses the start and the core stays halted.

`test/test.py` is the same sequence under cocotb against the Verilog, and the OCaml
tests under `test/` run UART, SPI and I2C masters and slaves, a low speed USB keyboard
and mouse, WS2812, 1-Wire, PS/2 and 10BASE-T transmit firmware against protocol models
and against the hardware.

## External hardware

None required. A USB serial adapter on `OUT0` shows the UART demo, and an I2C sensor or an
SPI flash on the `IO` pins serves the other firmware.
