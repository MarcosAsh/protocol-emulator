# SPDX-License-Identifier: Apache-2.0
"""Runs sigrok-cli with what generate.exe lab gives each decoder the lab allows, every
option set, on a short capture, the way demo/lab.py does. sigrok refuses an unknown
decoder, channel, option or annotation row, so a name in remote_lab.ml's Decode that the
installed sigrok lacks fails here. Needs sigrok-cli and demo/pinned_decoders.sh's."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "demo"))
import lab  # noqa: E402
import sigrok  # noqa: E402

# from generate.exe lab, a decode with every option for each decoder
ARGS = [
    ["-P", "uart:rx=D4:tx=D6:baudrate=115200:data_bits=8:parity=even:stop_bits=1.0"
     ":bit_order=lsb-first:format=hex:invert_rx=no:invert_tx=yes", "-A", "uart=rx-data:tx-data"],
    ["-P", "spi:clk=D6:mosi=D4:cs_polarity=active-low:cpol=0:cpha=1:bitorder=msb-first"
     ":wordsize=8", "-A", "spi=mosi-data"],
    ["-P", "i2c:scl=D6:sda=D4:address_format=unshifted", "-A", "i2c=addr-data"],
    ["-P", "rgb_led_ws281x:din=D4", "-A", "rgb_led_ws281x=rgb:reset"],
    ["-P", "ir_nec:ir=D4:polarity=active-high", "-A", "ir_nec=fields"],
    ["-P", "ir_rc5:ir=D4:polarity=active-low:protocol=extended", "-A", "ir_rc5=fields"],
    ["-P", "onewire_link:owr=D4:overdrive=no", "-A", "onewire_link=bits"],
    ["-P", "can:can_rx=D4:nominal_bitrate=500000:sample_point=75", "-A", "can=fields"],
    ["-P", "pwm:data=D4:polarity=active-high", "-A", "pwm=duty-cycle"],
    ["-P", "dcf77:data=D4", "-A", "dcf77=fields"],
    ["-P", "ps2:clk=D6:data=D4", "-A", "ps2=fields"],
    ["-P", "dali:dali=D4:polarity=active-low", "-A", "dali=fields"],
    ["-P", "caliper:clk=D6:data=D4:timeout_ms=10:unit=mm:changes=yes", "-A",
     "caliper=measurements"],
    ["-P", "lfast:data=D4", "-A", "lfast=fields"],
    ["-P", "snorble:sig=D4", "-A", "snorble=bytes"],
    ["-P", "plinkoo:stb=D6:dat=D4", "-A", "plinkoo=bytes"],
    ["-P", "i2c_timing:scl=D6:sda=D4:mode=fast", "-A", "i2c_timing=fails:unsures"],
]


class Decoders(unittest.TestCase):
    def test_every_allowed_decoder_runs(self):
        self.assertEqual({a[1].split(":")[0] for a in ARGS}, lab.DECODERS)
        with tempfile.TemporaryDirectory() as tmp:
            sr = Path(tmp, "lab_a.sr")
            # idle high, then a few toggles on D4 and D6
            sigrok.write(sr, 24_000_000, bytes([0x50]) * 1000 + bytes([0x00, 0x50] * 500))
            for args in ARGS:
                self.assertTrue(lab.decode_args(args), args)
                run = subprocess.run(["sigrok-cli", "-i", str(sr), *args], capture_output=True,
                                     text=True, timeout=60,
                                     env=os.environ | {"SIGROKDECODE_DIR": str(lab.DECODER_DIR)})
                self.assertEqual((run.returncode, run.stderr), (0, ""), args)


if __name__ == "__main__":
    unittest.main()
