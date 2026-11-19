# SPDX-License-Identifier: Apache-2.0
# Checks a draw record's drand signature against quicknet's public key, which
# corpus_draw.py's --beacon replay takes on trust. Needs py_ecc (pip install py_ecc).
# Usage: python3 demo/beacon_verify.py demo/corpus_draw_33346612.json
import hashlib
import json
import sys

from py_ecc.bls.hash_to_curve import hash_to_G1
from py_ecc.bls.point_compression import decompress_G1, decompress_G2
from py_ecc.optimized_bls12_381 import G2, pairing

# quicknet's group key, as every relay's /info gives it (scheme bls-unchained-g1-rfc9380)
PUBLIC_KEY = ("83cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c"
              "8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e17e63aaf4bcb"
              "5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a")
DST = b"BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_"


def verify(r, signature):
    """Whether signature (hex, a G1 point) is quicknet's on round r."""
    key = bytes.fromhex(PUBLIC_KEY)
    public = decompress_G2((int.from_bytes(key[:48], "big"), int.from_bytes(key[48:], "big")))
    point = decompress_G1(int.from_bytes(bytes.fromhex(signature), "big"))
    message = hashlib.sha256(r.to_bytes(8, "big")).digest()
    return pairing(G2, point) == pairing(public, hash_to_G1(message, DST, hashlib.sha256))


def main():
    answers = json.load(open(sys.argv[1]))["answers"]
    seen = {(a["round"], a["randomness"], a["signature"]) for a in answers.values()}
    if len(seen) != 1:
        raise SystemExit("the record's relays disagree")
    r, randomness, signature = seen.pop()
    if hashlib.sha256(bytes.fromhex(signature)).hexdigest() != randomness:
        raise SystemExit("round %d's randomness is not the sha256 of its signature" % r)
    if not verify(r, signature):
        raise SystemExit("round %d's signature is not quicknet's" % r)
    print("round %d: quicknet signed it, randomness %s" % (r, randomness))


if __name__ == "__main__":
    main()
