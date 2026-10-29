# SPDX-License-Identifier: Apache-2.0
# The public draw of the corpus: a drand round fixed in advance picks N protocols from a pinned
# snapshot of sigrok's decoder list. This file is the rule, committed before the round. Eligible
# decoders rank by sha256(randomness || id) and the first N not on the owner's salted exclusion
# list are drawn. Only the owner makes that list (seal) and commits its sha256 beforehand.
# Usage: python3 demo/corpus_draw.py pool                   the eligible pool and why each other is out
#        python3 demo/corpus_draw.py seal < IDS > EXCLUDE    the owner, on their own list, one id a line
#        python3 demo/corpus_draw.py draw --exclude EXCLUDE [--round R] [--beacon JSON] [--record FILE]
#        python3 demo/corpus_draw.py snapshot DECODERS_DIR COMMIT > demo/corpus_decoders.tsv
import argparse
import ast
import datetime
import hashlib
import json
import os
import secrets
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SNAPSHOT = os.path.join(HERE, "corpus_decoders.tsv")
# git://sigrok.org/libsigrokdecode HEAD on 2026-10-18 (the GitHub mirror agrees), 2024-10-01
COMMIT = "71f451443029322d57376214c330b518efd84f88"
SNAPSHOT_SHA256 = "c42cfd685deacc0726a6a1800c8c3eaf6d76745b567b01ab1b8dcc2a678b02c4"
# drand's quicknet: 3 s rounds from its genesis, unchained BLS on G1
CHAIN = "52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971"
GENESIS = 1692803367
PERIOD = 3
# the first round at or after 2026-10-24 12:00:00 UTC (it lands on it exactly)
ROUND = 33346612
N = 6
RELAYS = ["https://api.drand.sh", "https://api2.drand.sh", "https://api3.drand.sh",
          "https://drand.cloudflare.com"]
# a protocol may need each line in either direction, so it must fit the 8 bidirectional pins
MAX_CHANNELS = 8
# the decoders the library's traces already name (test/traces/*.trace "# sigrok decoder"),
# frozen with the rule
IN_LIBRARY = ["can", "cec", "i2c", "jtag", "onewire_link", "ps2", "rgb_led_ws281x", "spi", "swd",
              "uart", "usb_signalling"]
PAD = 64
# the sha256 of the owner's exclusion file, committed before the round, so the draw refuses
# any other file
EXCLUSION_SHA256 = "5a042b2987ffe96743e69b2ba5b7ff78ca6a22174e90db1fd04af08033b3afd1"


def snapshot(decoders_dir, commit):
    """Each decoder's metadata from its pd.py, read as syntax and never run; "?" for a channel
    list that is not a literal."""
    lines = ["# libsigrokdecode %s decoders/*/pd.py" % commit,
             "\t".join(["id", "inputs", "tags", "channels", "optional_channels", "longname"])]
    for name in sorted(os.listdir(decoders_dir)):
        path = os.path.join(decoders_dir, name, "pd.py")
        if not os.path.isfile(path):
            continue
        tree = ast.parse(open(path, encoding="utf-8").read())
        decoder = next(node for node in tree.body
                       if isinstance(node, ast.ClassDef) and node.name == "Decoder")
        fields = {}
        for statement in decoder.body:
            if isinstance(statement, ast.Assign) and isinstance(statement.targets[0], ast.Name):
                try:
                    fields[statement.targets[0].id] = ast.literal_eval(statement.value)
                except ValueError:
                    fields[statement.targets[0].id] = None

        def channels(key):
            value = fields.get(key, ())
            return "?" if value is None else ",".join(c["id"] for c in value)

        lines.append("\t".join([fields["id"], ",".join(fields["inputs"]),
                                ",".join(fields.get("tags", [])), channels("channels"),
                                channels("optional_channels"), fields["longname"]]))
    return "\n".join(lines) + "\n"


def decoders(path=SNAPSHOT):
    text = open(path, "rb").read()
    if hashlib.sha256(text).hexdigest() != SNAPSHOT_SHA256:
        raise SystemExit("%s is not the pinned snapshot" % path)
    rows = [line.split("\t") for line in text.decode().splitlines() if not line.startswith("#")]
    head = rows[0]
    return [dict(zip(head, row)) for row in rows[1:]]


def split(cell):
    return [] if cell == "" else cell.split(",")


def out_because(d):
    """Why a decoder is not in the pool, or None when it is."""
    if d["inputs"] != "logic":
        return "reads %s, not pins (its timing is the bus beneath)" % d["inputs"]
    if "Util" in split(d["tags"]):
        return "a measuring tool (tag Util), not a protocol"
    if "?" in (d["channels"], d["optional_channels"]):
        return "its channels are not a literal list in pd.py"
    if len(split(d["channels"])) > MAX_CHANNELS:
        return "needs %d channels, past %d" % (len(split(d["channels"])), MAX_CHANNELS)
    if d["id"] in IN_LIBRARY:
        return "already in the library"
    return None


def pool(rows=None):
    return sorted(d["id"] for d in (rows or decoders()) if out_because(d) is None)


def digest(ids):
    return hashlib.sha256(("\n".join(ids) + "\n").encode()).hexdigest()


def round_time(r):
    return datetime.datetime.fromtimestamp(GENESIS + (r - 1) * PERIOD, datetime.timezone.utc)


def check_beacon(r, answers):
    """The round's randomness, once the relays that answered agree on it and on its signature,
    and it is the sha256 of that signature (drand's rule for unchained rounds)."""
    if not answers:
        raise SystemExit("no relay answered for round %d" % r)
    seen = {(a["round"], a["randomness"], a["signature"]) for a in answers.values()}
    if len(seen) != 1:
        raise SystemExit("relays disagree on round %d: %s" % (r, json.dumps(answers)))
    got, randomness, signature = seen.pop()
    if got != r:
        raise SystemExit("asked for round %d, got %d" % (r, got))
    if hashlib.sha256(bytes.fromhex(signature)).hexdigest() != randomness:
        raise SystemExit("round %d's randomness is not the sha256 of its signature" % r)
    return randomness, signature


def fetch(r):
    answers = {}
    for relay in RELAYS:
        try:
            url = "%s/%s/public/%d" % (relay, CHAIN, r)
            request = urllib.request.Request(url, headers={"User-Agent": "corpus_draw"})
            with urllib.request.urlopen(request, timeout=20) as f:
                answers[relay] = json.loads(f.read())
        except (OSError, ValueError) as e:
            print("relay %s: %s" % (relay, e), file=sys.stderr)
    if len(answers) < 2:
        raise SystemExit("fewer than two relays answered for round %d" % r)
    return answers


def order(randomness, ids):
    seed = bytes.fromhex(randomness)
    return sorted(ids, key=lambda i: hashlib.sha256(seed + i.encode()).hexdigest())


def salted(salt, decoder):
    return hashlib.sha256((salt + ":" + decoder).encode()).hexdigest()


def seal(ids, salt=None, pad=PAD):
    """The exclusion file for [ids]: a salt and each id's salted hash, padded with random hashes
    so its length does not tell how many there are, in sorted order."""
    salt = salt or secrets.token_hex(32)
    hashes = {salted(salt, i) for i in ids}
    while len(hashes) < pad:
        hashes.add(secrets.token_hex(32))
    return "salt %s\n%s\n" % (salt, "\n".join(sorted(hashes)))


def excluded(text):
    lines = [line.strip() for line in text.splitlines() if line.strip()
             and not line.startswith("#")]
    if not lines or not lines[0].startswith("salt "):
        raise SystemExit("an exclusion file starts with its salt line, from seal")
    salt = lines[0].split()[1]
    hashes = set(lines[1:])
    return lambda decoder: salted(salt, decoder) in hashes


def draw(randomness, ids, is_excluded, n=N):
    """The first [n] of the ranked pool the exclusion list lacks, with their places."""
    picks, withheld = [], 0
    for place, decoder in enumerate(order(randomness, ids), start=1):
        if len(picks) == n:
            break
        if is_excluded(decoder):
            withheld += 1
        else:
            picks.append((place, decoder))
    return picks, withheld


def record(r, answers, randomness, signature, exclude_text, rows):
    ids = pool(rows)
    picks, withheld = draw(randomness, ids, excluded(exclude_text))
    longname = {d["id"]: d["longname"] for d in rows}
    channels = {d["id"]: d["channels"] or "(" + d["optional_channels"] + ")" for d in rows}
    lines = ["round %d of drand quicknet %s, %s" % (r, CHAIN[:16], round_time(r).isoformat())]
    if r != ROUND:
        lines.append("REHEARSAL: the announced round is %d (%s)"
                     % (ROUND, round_time(ROUND).isoformat()))
    lines += [
        "randomness %s" % randomness,
        "signature %s" % signature,
        "relays agreeing %s" % " ".join(sorted(answers)),
        "snapshot libsigrokdecode %s, sha256 %s" % (COMMIT, SNAPSHOT_SHA256),
        "pool %d decoders, sha256 %s" % (len(ids), digest(ids)),
        "exclusion file sha256 %s" % hashlib.sha256(exclude_text.encode()).hexdigest(),
        "rank: sha256(randomness || id), smallest first; %d of the first %d withheld by the"
        " exclusion list" % (withheld, picks[-1][0]),
        "",
        "place\tid\tchannels\tlongname",
    ]
    lines += ["%d\t%s\t%s\t%s" % (place, d, channels[d], longname[d]) for place, d in picks]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("snapshot")
    p.add_argument("decoders_dir")
    p.add_argument("commit")
    sub.add_parser("pool")
    p = sub.add_parser("seal")
    p.add_argument("--pad", type=int, default=PAD)
    p = sub.add_parser("draw")
    p.add_argument("--exclude", required=True, help="the owner's file from seal")
    p.add_argument("--round", type=int, default=ROUND)
    p.add_argument("--beacon", help="the relays' saved answers, from a record, not the network")
    p.add_argument("--record", help="also write the answers and the result here, as JSON")
    args = parser.parse_args()
    if args.command == "snapshot":
        sys.stdout.write(snapshot(args.decoders_dir, args.commit))
    elif args.command == "pool":
        rows = decoders()
        ids = pool(rows)
        print("pool %d decoders, sha256 %s" % (len(ids), digest(ids)))
        print("\n".join(ids))
        print("\nout:")
        print("\n".join("%s\t%s" % (d["id"], out_because(d)) for d in rows if out_because(d)))
    elif args.command == "seal":
        ids = [line.strip() for line in sys.stdin if line.strip()]
        sys.stdout.write(seal(ids, pad=args.pad))
    else:
        if args.round == ROUND and round_time(ROUND) > datetime.datetime.now(datetime.timezone.utc):
            raise SystemExit("round %d is at %s, not yet" % (ROUND, round_time(ROUND).isoformat()))
        answers = json.load(open(args.beacon))["answers"] if args.beacon else fetch(args.round)
        randomness, signature = check_beacon(args.round, answers)
        exclude_text = open(args.exclude).read()
        if args.round == ROUND and EXCLUSION_SHA256 != hashlib.sha256(
                exclude_text.encode()).hexdigest():
            raise SystemExit("the exclusion file is not the one committed in EXCLUSION_SHA256")
        text = record(args.round, answers, randomness, signature, exclude_text, decoders())
        sys.stdout.write(text)
        if args.record:
            with open(args.record, "w") as f:
                json.dump({"answers": answers, "record": text}, f, indent=1)
                f.write("\n")


if __name__ == "__main__":
    main()
