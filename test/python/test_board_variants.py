# SPDX-License-Identifier: Apache-2.0
# Checks that write_kernel_variants.exe still makes the variants test/board/kernel_vs_board
# ran: the same bytes SHA256SUMS.inputs named before the run, and the verdicts.tsv the
# witness scores the board's rows against.
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
import kernel_vs_board as kvb  # noqa: E402

made = Path(sys.argv[2]).read_bytes()
board = Path(sys.argv[3])
named = {name: sha for sha, name in
         (line.split() for line in (board / "SHA256SUMS.inputs").read_text().splitlines())}
assert hashlib.sha256(made).hexdigest() == named["variants.jsonl"], (
    "the variants are not the ones the board ran")
variants = [json.loads(line) for line in made.decode().splitlines()]
# --chip skips a variant with no certificate, and the witness wants a row for each
assert all(v["certificate"] is not None for v in variants)
assert kvb.verdicts(variants) == (board / "verdicts.tsv").read_text(), (
    "verdicts.tsv is not what the variants make")
