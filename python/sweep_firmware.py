# Written by test/python/write_sweep_firmware.ml; `dune promote` after a change.
# Act 2's sweep: each firmware of test/library.ml that engine 1 can stamp on wire
# 20, as a config's changes from DEFAULTS, words, the words that park its pins low
# first, and a stimulus. Each edge is its cycles from its frame's first: an int
# where the kernel's rows along the model's path allow that cycle alone, else (the
# model's, the least and the most they allow), None where unbounded.

# cycles the host may take between polls, 150 us at 48 MHz
POLL = 7200

DEFAULTS = {
    "side_set_count": 0, "side_set_base": 5, "side_set_pindirs": 0, "in_base": 0,
    "in_count": 16, "out_base": 5, "out_count": 1, "set_base": 5, "set_count": 1,
    "jmp_pin": 0, "capture_pin": 0, "capture_rising": 1, "in_shift_right": 1,
    "out_shift_right": 1, "autopush": 0, "push_threshold": 16, "autopull": 0,
    "pull_threshold": 16, "crc_width": 16, "crc_poly": 40961, "crc_init": 65535,
    "crc_reflect": 1, "stuff_threshold": 0, "stuff_level": 1, "wrap_bottom": 0,
    "wrap_top": 511, "period_fraction": 0, "autopull_data": 0, "manchester": 0,
}

LOGGER = {
    "config": {"jmp_pin": 20, "autopush": 1},
    "words": [
        0x080B, 0xA000, 0x2094, 0x8026, 0xA001, 0x4030, 0x2014, 0x8026, 0xA000, 0x4030,
        0x0002, 0xA001, 0x0006,
    ],
}

SWEPT = [
    {
        "name": "uart_tx",
        "watch": "line",
        "config": {"out_base": 20, "set_base": 20},
        "words": [
            0xA088, 0xA001, 0x20E0, 0xE004, 0xA027, 0x80E6, 0xA000, 0xC0CA, 0x20C0,
            0x6001, 0x0208, 0x20C0, 0xA001, 0x2040, 0x0002,
        ],
        "park": [0x8003, 0xE001],
        "preamble": [],
        "setup": {"edges": 1, "cycles": 2},
        "bursts": [
            {"words": [0x004A], "cycles": 77, "frames": [
                [
                    0, 16, 24, 32, 40, 56, 64, 72,
                ],
            ]},
            {"words": [0x0061], "cycles": 77, "frames": [
                [
                    0, 8, 16, 48, 64, 72,
                ],
            ]},
            {"words": [0x006E], "cycles": 77, "frames": [
                [
                    0, 16, 40, 48, 64, 72,
                ],
            ]},
            {"words": [0x0065], "cycles": 77, "frames": [
                [
                    0, 8, 16, 24, 32, 48, 64, 72,
                ],
            ]},
        ],
    },
    {
        "name": "uart_tx16",
        "watch": "line",
        "config": {"out_base": 20, "set_base": 20},
        "words": [
            0xA090, 0xA001, 0x20E0, 0xE004, 0xA027, 0x80E6, 0xA000, 0xC0CA, 0x20C0,
            0x6001, 0x0208, 0x20C0, 0xA001, 0x2040, 0x0002,
        ],
        "park": [0x8003, 0xE001],
        "preamble": [],
        "setup": {"edges": 1, "cycles": 2},
        "bursts": [
            {"words": [0x004A], "cycles": 149, "frames": [
                [
                    0, 32, 48, 64, 80, 112, 128, 144,
                ],
            ]},
            {"words": [0x0061], "cycles": 149, "frames": [
                [
                    0, 16, 32, 96, 128, 144,
                ],
            ]},
            {"words": [0x006E], "cycles": 149, "frames": [
                [
                    0, 32, 80, 96, 128, 144,
                ],
            ]},
            {"words": [0x0065], "cycles": 149, "frames": [
                [
                    0, 16, 32, 48, 64, 96, 128, 144,
                ],
            ]},
        ],
    },
    {
        "name": "uart_tx_host_rate",
        "watch": "line",
        "config": {"out_base": 20, "set_base": 20},
        "words": [
            0x20E0, 0xE004, 0x80C5, 0xA001, 0x20E0, 0xE004, 0xA027, 0x80E6, 0xA000,
            0xC0CA, 0x20C0, 0x6001, 0x020A, 0x20C0, 0xA001, 0x2040, 0x0004,
        ],
        "park": [0x8003, 0xE001],
        "preamble": [434],
        "setup": {"edges": 1, "cycles": 4},
        "bursts": [
            {"words": [0x0053], "cycles": 3911, "frames": [
                [
                    0, 434, 1302, 2170, 2604, 3038, 3472, 3906,
                ],
            ]},
            {"words": [0x0074], "cycles": 3911, "frames": [
                [
                    0, 1302, 1736, 2170, 3472, 3906,
                ],
            ]},
        ],
    },
    {
        "name": "spi_master",
        "watch": "mosi",
        "config": {
            "side_set_count": 1, "side_set_base": 21, "out_base": 20,
            "in_shift_right": 0, "out_shift_right": 0,
        },
        "words": [
            0xA088, 0x20E0, 0xE004, 0x6068, 0xA027, 0x80E6, 0xC0CA, 0x20C0, 0x6001,
            0x20C0, 0x5001, 0x30C0, 0x6001, 0x0209, 0xE003, 0x0001,
        ],
        "park": [0x8003, 0xE001],
        "preamble": [],
        "setup": {"edges": 0, "cycles": 0},
        "bursts": [
            {"words": [0x004A], "cycles": 126, "frames": [
                [
                    0, 16, 48, 64, 80, 96,
                ],
            ]},
            {"words": [0x0061], "cycles": 142, "frames": [
                [
                    0, 32, 96, 112,
                ],
            ]},
            {"words": [0x006E], "cycles": 126, "frames": [
                [
                    0, 32, 48, 96,
                ],
            ]},
            {"words": [0x0065], "cycles": 142, "frames": [
                [
                    0, 32, 64, 80, 96, 112,
                ],
            ]},
        ],
    },
    {
        "name": "jtag",
        "watch": "tdi",
        "config": {"side_set_count": 1, "side_set_base": 22, "out_base": 20},
        "words": [
            0xA084, 0x20E0, 0xE004, 0xA027, 0x80E6, 0xC0CA, 0x20C0, 0x6002, 0x20C0,
            0x5001, 0x30C0, 0x6002, 0x0208, 0xE003, 0x0001,
        ],
        "park": [0x8003, 0xE001],
        "preamble": [],
        "setup": {"edges": 0, "cycles": 0},
        "bursts": [
            {"words": [0x22AA], "cycles": 0, "frames": [
            ]},
            {"words": [0x4110], "cycles": 73, "frames": [
                [
                    0, 8, 16, 24, 40, 48,
                ],
            ]},
            {"words": [0x5150], "cycles": 73, "frames": [
                [
                    0, 24, 32, 48,
                ],
            ]},
            {"words": [0x000A], "cycles": 0, "frames": [
            ]},
        ],
    },
    {
        "name": "can",
        "watch": "tx",
        "config": {
            "in_base": 20, "in_count": 1, "out_base": 20, "set_base": 20, "jmp_pin": 20,
            "out_shift_right": 0, "autopull": 1, "crc_width": 15, "crc_poly": 17817,
            "crc_init": 0, "crc_reflect": 0,
        },
        "words": [
            0x20E0, 0xE004, 0x80C5, 0x80E6, 0xC0CA, 0x20C0, 0xA001, 0x20E0, 0xE004,
            0x8025, 0x6070, 0xE005, 0x80E6, 0xC0CA, 0x20C0, 0xA000, 0xA043, 0x0816,
            0x20C0, 0x6001, 0x0819, 0x001B, 0x20C0, 0x6001, 0x081B, 0xA043, 0x001F,
            0x041F, 0x20C0, 0x8008, 0xA043, 0x0211, 0x40CF, 0x80A4, 0xA02E, 0x0828,
            0x20C0, 0x6001, 0x082B, 0x002D, 0x20C0, 0x6001, 0x082D, 0xA043, 0x0031,
            0x0431, 0x20C0, 0x8008, 0xA043, 0x0223, 0x20C0, 0xA001, 0xA02B, 0x20C0,
            0x0235, 0x0007,
        ],
        "park": [0x8003, 0xE001],
        "preamble": [1800],
        "setup": {"edges": 1, "cycles": 1805},
        "bursts": [
            {"words": [0x0019, 0x0940, 0x5840], "cycles": 81007, "frames": [
                [
                    0, 9000, 12600, 16200, 18000, 19800, 21600, 30600, 32400, 36000,
                    37800, 39600, 43200, 50400, 52200, 55800, 57600, 63000, 72000,
                    73800, 77400, 79200,
                ],
            ]},
        ],
    },
    {
        "name": "sent",
        "watch": "line",
        "config": {
            "out_base": 20, "set_base": 20, "out_shift_right": 0, "crc_width": 4,
            "crc_poly": 13, "crc_init": 3, "crc_reflect": 0,
        },
        "words": [
            0x20E0, 0xE004, 0x80C5, 0x80E6, 0xA001, 0x20E0, 0x80E6, 0xC0CA, 0xE004,
            0x2040, 0xA000, 0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0x2040, 0xA001,
            0xA030, 0xC0CA, 0xC0CA, 0x20C0, 0x0213, 0x6024, 0xE005, 0xA047, 0x2040,
            0xA000, 0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0x2040, 0xA001, 0xC0CA,
            0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0x20C0, 0x0229, 0x0442, 0x2040,
            0xA000, 0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0x2040, 0xA001, 0xC0CA,
            0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0xC0CA, 0x1008, 0x2040, 0x20E0,
            0x80E6, 0xC0CA, 0x0008, 0xA020, 0x0648, 0x40C4, 0x80A4, 0x6024, 0x001A,
            0xA023, 0x064B, 0xE004, 0x8085, 0x6024, 0x80A4, 0x6061, 0x6061, 0x6061,
            0x6061, 0x001A,
        ],
        "park": [0x8003, 0xE001],
        "preamble": [300],
        "setup": {"edges": 1, "cycles": 5},
        "bursts": [
            {"words": [0x0123, 0x4560], "cycles": 54303, "frames": [
                [
                    0, 1500, 16800, 18300, 20400, 21900, 24300, 25800, 28500, 30000,
                    33000, 34500, 37800, 39300, 42900, 44400, 48300, 49800, 52500,
                    54000,
                ],
            ]},
        ],
    },
]

NOT_SWEPT = [
    ("uart_rx", "a receiver: it samples, and nothing on the chip sends to it"),
    ("uart_rx_host_rate", "a receiver: both_roles.ml sends to it on a wire"),
    ("spi_slave", "a slave: the master's clock moves it"),
    ("i2c_master", "open drain, which a wire does not show, and a slave has to acknowledge"),
    ("i2c_slave", "a slave: the master's clock moves it"),
    ("i2c_logger", "an I2C master: open drain, and a slave has to answer"),
    ("i2c_master_standard", "open drain, which a wire does not show, and a slave has to acknowledge"),
    ("i2c_master_fast", "open drain, which a wire does not show, and a slave has to acknowledge"),
    ("i2c_controller_wire", "on two wires already, and both_roles.ml's target acknowledges"),
    ("i2c_target_wire", "a target: the controller's clock moves it"),
    ("usb_tx", "certified at 32 cycles a bit only, where 9 edges come in 256: the fifo holds 8"),
    ("usb_rx", "a receiver: nothing on the chip sends to it"),
    ("usb_device", "a device: a USB host has to talk first"),
    ("edge_meter", "toggles every 16 cycles for ever, so 9 edges come in 128: the fifo holds 8"),
    ("ws2812", "48 edges a pixel in 600 cycles: the fifo holds 8"),
    ("ws2812_standard", "48 edges a pixel in 1488 cycles: the fifo holds 8"),
    ("ethernet", "half bits of 2 cycles: the logger needs up to 6 between edges"),
    ("one_wire", "open drain, which a wire does not show, and a slave has to answer"),
    ("ps2", "open drain, which a wire does not show, and the host holds the clock"),
    ("dshot600", "32 edges a frame in 1328 cycles: the fifo holds 8"),
    ("cec", "open drain, which a wire does not show"),
    ("spi_cs_mode0", "the bench's SPI demo, certified as it loads; the sweep has not stamped it on the board"),
    ("spi_cs_mode1", "the bench's SPI demo, certified as it loads; the sweep has not stamped it on the board"),
    ("spi_cs_mode2", "the bench's SPI demo, certified as it loads; the sweep has not stamped it on the board"),
    ("spi_cs_mode3", "the bench's SPI demo, certified as it loads; the sweep has not stamped it on the board"),
    ("spi_cs_mode0_default_pins", "not stamped: its decoded runs judge each mode, and both_roles.ml runs it against Spi_target"),
    ("spi_cs_mode1_default_pins", "not stamped: its decoded runs judge each mode, and both_roles.ml runs it against Spi_target"),
    ("spi_cs_mode2_default_pins", "not stamped: its decoded runs judge each mode, and both_roles.ml runs it against Spi_target"),
    ("spi_cs_mode3_default_pins", "not stamped: its decoded runs judge each mode, and both_roles.ml runs it against Spi_target"),
    ("spi_target_mode0", "a target: the controller's clock moves it"),
    ("spi_target_mode1", "a target: the controller's clock moves it"),
    ("spi_target_mode2", "a target: the controller's clock moves it"),
    ("spi_target_mode3", "a target: the controller's clock moves it"),
    ("swd", "SWDIO turns round for the target's ACK, which a wire does not show, and a target has to answer"),
    ("uart_tx_stream", "time-triggered: it underflows, a sticky fault, once the host stops"),
    ("spi_master_stream", "time-triggered: it underflows, a sticky fault, once the host stops"),
    ("uart_tx_stamped", "26 bits 8 cycles apart, and the chip's clock in them, which the model cannot know"),
]
