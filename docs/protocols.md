# Protocols

The library is `test/library.ml`, a protocol to a module, in the order of the certificates.
These are the 68 library firmwares the kernel accepts in `test/test_kernel.ml`.

| Protocol | Firmware the kernel accepts |
|---|---|
| UART | uart_tx, uart_tx16, uart_tx_host_rate, uart_rx, uart_rx_host_rate |
| SPI | spi_master, spi_slave |
| I2C | i2c_master, i2c_slave, i2c_logger, i2c_master_standard, i2c_master_fast, i2c_master_standard_asym, i2c_master_fast_asym, i2c_controller_wire, i2c_target_wire |
| USB, low speed | usb_tx, usb_rx, usb_device |
| USB, full speed | usb_fs_device |
| Edge meter | edge_meter, which stamps every rising edge of OUT0 wired back to IN0 |
| WS2812 | ws2812, ws2812_standard |
| 10BASE-T Ethernet | ethernet |
| 1-Wire | one_wire |
| PS/2 | ps2 |
| JTAG | jtag |
| CAN | can |
| DShot600 | dshot600 |
| SENT | sent |
| CEC | cec |
| SPI with chip select | spi_cs_mode0 to spi_cs_mode3, each also with default pins |
| SPI target | spi_target_mode0 to spi_target_mode3, spi_target_fast_mode0 to spi_target_fast_mode3 |
| SWD | swd |
| Tables | table, table_open_drain |
| NEC infrared | nec_tx, nec_rx |
| SNB-1 Snorble Sensor Beacon, Rev. C, invented for the 2026-10-18 blind rehearsal | snorble |
| PLK-2 Plinkoo Two-Wire Packet Bus, revision 1.3, invented for the 2026-10-18 blind rehearsal | plinkoo, whose 16-cycle tB fails the sheet's maximum with the one-cycle margin (`test/test_plinkoo.ml`) |
| FGL-0 Frumbleglide Clockless Telemetry Link, revision 0.9, invented for the 2026-10-18 blind rehearsal | none: no whole number of cycles meets its cell limits at 48 MHz, and the limits refuse the nearest firmware |
| Microwire | microwire |
| RC-6 | ir_rc6 |
| Caliper | caliper |
| XY2-100 | xy2_100 |
| LFAST | lfast |
| TDM audio | tdm_audio |
| DALI | dali |
| LIN 2.x | lin |
| S/PDIF | spdif |
| USB Power Delivery | usb_power_delivery |
| DMX512 | dmx512 |
| Wiegand | wiegand |
| SWD, written blind | swd_blind |
| NEC infrared, written blind | ir_nec |

Microwire, XY2-100, Caliper, LFAST, RC-6 and TDM audio came from the [random draw](flexibility.md).
DALI to NEC infrared, written blind, are the [held-out list](flexibility.md#the-held-out-list).
`test/test_datasheet.ml` checks the bench's firmware against its datasheet's timing limits,
where the datasheet gives any.
spi_slave, i2c_slave, i2c_target_wire, the eight spi_target firmwares and tdm_audio have no
deadline wait, so there is no deadline to certify.

The decoders that check the protocols at the RTL's pins, and what is only tested, are on
[Verification](verification.md#what-is-not-proved).
