## How it works

A small programmable core that bit-bangs pins with cycle-exact timing, so
protocols like UART, SPI and I2C are firmware rather than fixed logic. The host
loads a program over SPI and talks to it through a pair of FIFOs.

Work in progress. The design is written in Hardcaml; the Verilog in `src` is generated.

## How to test

Load a program over the SPI port from the demo board's RP2040, then watch the
protocol pins with a logic analyzer or connect a peripheral.

## External hardware

Anything that speaks UART, SPI or I2C. A USB to UART adapter is the easiest start.
