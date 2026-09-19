<!---
This file is used to generate your project datasheet.
-->

## How it works

A trial hookup of the IHP 512x16 SRAM macro. The host reads and writes one byte at
a time. `ui[4:0]` is the low part of the address and a bank register holds the top
four bits; load it by raising `bank_sel` with the value on `uio[3:0]`. `high_byte`
picks which half of the 16-bit word is written or read. `wen` writes the byte on
`uio[7:0]` using the macro's bit mask, leaving the other half of the word intact.

## How to test

Write: set the bank, then set the address, the byte on `uio` and `wen`, and clock
once. Read: set the bank and the address with `wen` low and clock twice; the byte
appears on `uo_out`.

## External hardware

None
