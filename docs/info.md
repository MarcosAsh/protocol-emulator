## How it works

A programmable core whose firmware bit-bangs the pins with cycle-exact timing.
The host loads programs over SPI on `ui[2:0]` and `uo[0]`.

## How to test

See `test/test.py`: it loads a UART transmitter over SPI and decodes `uo[1]`.

## External hardware

None required.
