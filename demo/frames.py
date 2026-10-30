# SPDX-License-Identifier: Apache-2.0
# python/demo_ethernet_rx.py's log, judged again from what it says was sent: each frame's
# FCS against zlib's CRC-32, the receiver's verdict and counts against that, and the bytes
# the chip handed back against the bytes sent. The analyser cannot follow 10 Mb/s, so the
# log is the run's only record; its teeth edit it.

import re
import zlib

# the data memory's 512 words from where the demo lands frames, 16
ROOM = 2 * (512 - 16)
# the rate steps a pass needs, as the demo has them
CLAIMED = (-1, 0, 1)
FRAME = re.compile(
    r"^frame (\d+) step (-?\d+)(?: divider \d+/256)? len (\d+) fcs (good|bad): words (\d+) "
    r"finished (\d) fcs_ok (\d) half (\d) dropped (\d), (PASS|FAIL)$")


def parse(log):
    """Each frame's fields, with the bytes sent and handed back."""
    lines = log.splitlines()
    out = []
    for n, line in enumerate(lines):
        m = FRAME.match(line)
        if not m:
            continue
        sent = lines[n + 1].split()[1:] if n + 1 < len(lines) else []
        got = lines[n + 2].split()[1:] if n + 2 < len(lines) else []
        number, step, length, fcs, words, finished, fcs_ok, half, dropped, said = m.groups()
        out.append({
            "frame": int(number), "step": int(step), "length": int(length), "fcs": fcs,
            "words": int(words), "finished": int(finished), "fcs_ok": int(fcs_ok),
            "half": int(half), "dropped": int(dropped), "said": said,
            "sent": [int(b, 16) for b in sent], "got": [int(b, 16) for b in got]})
    return out


def wrong(f):
    """Why the frame was not received whole, from its bytes alone; None when it was."""
    sent, got = f["sent"], f["got"]
    if len(sent) != f["length"]:
        return "%d bytes listed as sent, not %d" % (len(sent), f["length"])
    good = zlib.crc32(bytes(sent[:-4])) == int.from_bytes(bytes(sent[-4:]), "little")
    if (f["fcs"] == "good") != good:
        return "labelled fcs %s, but its FCS is %s" % (f["fcs"], "good" if good else "bad")
    if not f["finished"]:
        return "never finished"
    if f["fcs_ok"] != good:
        return "the receiver judged an FCS %s that is %s" % (
            "good" if f["fcs_ok"] else "bad", "good" if good else "bad")
    if f["words"] != (len(sent) + 1) // 2 or f["half"] != len(sent) % 2:
        return "counted %d words, half %d" % (f["words"], f["half"])
    if f["dropped"] != (len(sent) > ROOM):
        return "dropped %d" % f["dropped"]
    if got != sent[:min(len(sent), ROOM)]:
        return "handed back other bytes than were sent"
    return None


def judge(log):
    """The frames' tally and what is wrong with the log."""
    frames = parse(log)
    problems = []
    for f in frames:
        why = wrong(f)
        if (why is None) != (f["said"] == "PASS"):
            problems.append("frame %d: the log says %s, but %s" % (
                f["frame"], f["said"], why or "it was received whole"))
        if why and f["step"] in CLAIMED:
            problems.append("frame %d at step %d: %s" % (f["frame"], f["step"], why))
    steps = sorted({f["step"] for f in frames})
    whole = [s for s in steps if all(wrong(f) is None for f in frames if f["step"] == s)]
    if not frames:
        problems.append("no frames in the log")
    if not set(CLAIMED) <= set(steps):
        problems.append("no frames at steps %s" % " ".join(map(str, CLAIMED)))
    said = re.findall(r"^rate steps received whole: (.*)$", log, re.M)
    if not said or [int(s) for s in said[-1].split()] != whole:
        problems.append("the log's steps received whole are not the frames'")
    verdicts = [line.strip() for line in log.splitlines() if line.strip() in ("PASS", "FAIL")]
    if (verdicts[-1:] == ["PASS"]) != (not problems):
        problems.append("the log ends %s" % (verdicts[-1] if verdicts else "with no verdict"))
    tally = {
        "frames": len(frames),
        "good_fcs": sum(f["fcs"] == "good" for f in frames),
        "bad_fcs": sum(f["fcs"] == "bad" for f in frames),
        "past_the_data_memory": sum(f["length"] > ROOM for f in frames),
        "received_whole": sum(wrong(f) is None for f in frames),
        "bytes": sum(f["length"] for f in frames),
        "steps_received_whole": whole,
    }
    return tally, problems


def teeth(log):
    """Each tooth's description and why the judge refused it, or None when it did not."""
    frames = parse(log)
    out = []
    first = next(f for f in frames if f["step"] == 0 and f["got"])
    lines = log.splitlines()
    at = next(n for n, line in enumerate(lines) if line.startswith("frame %d " % first["frame"]))
    got = lines[at + 2].split()
    got[1] = "%02x" % (int(got[1], 16) ^ 1)
    edited = lines[:at + 2] + [" ".join(got)] + lines[at + 3:]
    problems = judge("\n".join(edited))[1]
    out.append(("frame %d's first byte handed back with its low bit flipped" % first["frame"],
                problems[0] if problems else None))
    bad = next(f for f in frames if f["fcs"] == "bad" and f["step"] == 0)
    at = next(n for n, line in enumerate(lines) if line.startswith("frame %d " % bad["frame"]))
    edited = list(lines)
    edited[at] = edited[at].replace("fcs_ok 0", "fcs_ok 1")
    problems = judge("\n".join(edited))[1]
    out.append(("frame %d, its FCS bad, said to be judged good" % bad["frame"],
                problems[0] if problems else None))
    return out
