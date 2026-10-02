# SPDX-License-Identifier: Apache-2.0
# Reads and writes sigrok session files (.sr): a zip of an INI metadata file and the raw
# samples, one byte a sample for up to eight channels, in numbered chunks.

import configparser
import io
import zipfile

CHUNK = 4 << 20


def _rate(text):
    number, _, unit = text.partition(" ")
    return float(number) * {"Hz": 1, "kHz": 1e3, "MHz": 1e6, "GHz": 1e9}[unit or "Hz"]


def read(path):
    """The sample rate in Hz, the channel names by bit, and the samples as bytes."""
    with zipfile.ZipFile(path) as z:
        meta = configparser.ConfigParser()
        meta.read_string(z.read("metadata").decode())
        device = meta["device 1"]
        if device.getint("unitsize") != 1:
            raise ValueError("%s: only captures of up to 8 channels are read" % path)
        channels = {
            int(key[len("probe") :]) - 1: name
            for key, name in device.items()
            if key.startswith("probe")
        }
        prefix = device["capturefile"] + "-"
        chunks = sorted(
            (n for n in z.namelist() if n.startswith(prefix)),
            key=lambda n: int(n[len(prefix) :]),
        )
        samples = b"".join(z.read(n) for n in chunks)
    return _rate(device["samplerate"]), channels, samples


def write(path, rate_hz, samples, channels=8, names=None):
    """names: one a channel, D0 and up by default."""
    names = names or ["D%d" % i for i in range(channels)]
    meta = io.StringIO()
    meta.write("[global]\nsigrok version=0.5.2\n\n[device 1]\ncapturefile=logic-1\n")
    meta.write(
        "total probes=%d\nsamplerate=%g MHz\ntotal analog=0\n" % (len(names), rate_hz / 1e6)
    )
    for i, name in enumerate(names):
        meta.write("probe%d=%s\n" % (i + 1, name))
    meta.write("unitsize=1\n")
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("version", "2")
        z.writestr("metadata", meta.getvalue())
        for i in range(0, max(len(samples), 1), CHUNK):
            z.writestr("logic-1-%d" % (i // CHUNK + 1), bytes(samples[i : i + CHUNK]))


def edges(samples, bit):
    """The sample index of every change on one channel, and the level it changes to."""
    import numpy as np

    levels = (np.frombuffer(samples, dtype=np.uint8) >> bit) & 1
    at = np.flatnonzero(np.diff(levels)) + 1
    return at, levels[at]
