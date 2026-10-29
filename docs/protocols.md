# Protocols

The library is `test/library.ml`, a protocol to a module, in the order of the certificates.
These are the 52 library firmwares the kernel accepts in `test/test_kernel.ml`.

| Protocol | Firmware the kernel accepts |
|---|---|
| UART | uart_tx, uart_tx16, uart_tx_host_rate, uart_rx, uart_rx_host_rate |
| SPI | spi_master, spi_slave |
| I2C | i2c_master, i2c_slave, i2c_logger, i2c_master_standard, i2c_master_fast, i2c_controller_wire, i2c_target_wire |
| USB, low speed | usb_tx, usb_rx, usb_device |
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
| SPI target | spi_target_mode0 to spi_target_mode3 |
| SWD | swd |
| Tables | table, table_open_drain |
| NEC infrared | nec_tx, nec_rx |
| SNB-1 Snorble Sensor Beacon, Rev. C | snorble |
| PLK-2 Plinkoo Two-Wire Packet Bus, revision 1.3 | plinkoo |
| FGL-0 Frumbleglide Clockless Telemetry Link, revision 0.9 | none: no whole number of cycles meets its cell limits at 48 MHz, and the limits refuse the nearest firmware |
| Microwire | microwire |
| RC-6 | ir_rc6 |
| Caliper | caliper |
| XY2-100 | xy2_100 |
| LFAST | lfast |

Microwire, XY2-100, Caliper, LFAST and RC-6 came from the [random draw](flexibility.md).
`test/test_datasheet.ml` checks firmware against its datasheet's timing limits, where the
datasheet gives any.

The decoders that check the protocols at the RTL's pins, and what is only tested, are on
[Verification](verification.md#what-is-not-proved).
