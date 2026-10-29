# Flexibility

## Protocols drawn at random

To show it handles protocols it wasn't built for, we let a public random beacon pick six
from sigrok's decoders, pinned each one's spec before any run, and had an agent write the
firmware blind from the spec (`demo/corpus_draw_33346612.json`, `demo/corpus_specs.tsv`,
`demo/intake.sh`). Two readers pulled the timing limits out of each spec separately, and I
ruled where they disagreed. Each run took 24 to 50 minutes.

| Protocol | Spec | Result |
|---|---|---|
| Microwire | National AN-452 | certified against the limits in its tables |
| XY2-100 | rhothor X7 datasheet | certified against its setup and hold limits |
| Caliper | ShumaTech's page | certified, but the page only gives "about" values, read as minimums |
| LFAST | NXP AN5134 | certified, but its one limit is a top speed, so it binds nothing |
| RC-6 | SB-Projects page | certified, but the page gives no limits at all |
| TDM audio | Cirrus AN301 | failed: the note has no timing limits to check against |

So three real certificates, two that are hollow because the spec is, and one failure. Every
result stays here, including the ones that don't flatter us.

## The held-out list

Eight more protocols, none of them in the library, are sealed in `test/heldout.sha256`, the
SHA-256 of a salted list committed on 2026-10-02. When the list is opened in November they
go through the same pipeline, and the results go here too.
