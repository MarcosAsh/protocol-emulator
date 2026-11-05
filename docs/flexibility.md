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
| TDM audio | Cirrus AN301 | certified, but the note gives no timing limits, so nothing binds |

So three real certificates and three that are hollow because the spec is. TDM was listed
here as a failure at first, and is now certified with no limits, like RC-6. Every result stays
here, including the ones that don't flatter us.

## The held-out list

Eight more protocols, none of them in the library when sealed, went into
`test/heldout.sha256`, the SHA-256 of a salted list committed on 2026-10-02. The list was
opened on 2026-11-02 (`test/heldout.txt`, specs pinned in `demo/heldout_specs.tsv`) and all
eight went through the same pipeline. Each spec's limits were read twice blind. All eight
readings disagreed somewhere and were ruled by hand (rulings in each run directory). Limit rows are all, then those with a min or max, then those
typical only. The binding rows are the limits that fail a hertz past each end of the firmware's
clock window (`test/test_clock_window.ml`). Times, cost and turns are the intake agent's run.
Board runs on 2026-11-03, Icepi Zero with main's 6x4 bitstream (`v1.3.bit`).

| Protocol | Spec | Limit rows | Fields ruled | Verdict | Binding rows (low end / high end, MHz) | sigrok from simulation | Board | Agent run | Cost | Turns | Library overlap |
|---|---|---|---|---|---|---|---|---|---|---|---|
| SWD (`swd_blind`) | ARM IHI 0031C (ADIv5.2) | 9 / 8 / 1 | 75 of 82 | certified | none / 49.000, Trn >= 1000 ns | PASS, 7 lines, 2 teeth refused | PASS: DPIDR read ACK OK, 0x0bc12477; sigrok reads the dormant wake and TARGETSEL before it as FAULT, ERROR, WAIT and NOREPLY lines, then IDCODE, OK, 0x0bc12477 | 40.2 min | $9.04 | 151 | the library's `swd` entered after the seal; run with `--hide nec,swd`, 0 tool inputs name its files |
| LIN 2.x | LIN 2.2A (consortium package) | 54 / 39 / 15 | 105 of 342 | certified | 47.780, FTOL_RES_MASTER bit <= 52343.8 ns / 48.222, FTOL_RES_MASTER bit >= 51822.9 ns | PASS, 9 lines, 2 teeth refused | PASS: Break, Sync, ID 0x16 parity 3, on IO5 (moved from IO0, which no analyser sees); nothing on the bench answers, so no response | 67.8 min | $8.86 | 163 | - |
| DMX512 | Wikipedia rev. 1380777110 | 10 / 8 / 2 | 8 of 57 | certified | 48.000, longest channel low <= 4000 ns / 48.000, shortest low >= 4000 ns | PASS joined, 1033 lines, 2 teeth refused; from reset misframed, as recorded | PASS: the second of two packets, start code and 512 channels exact; the first misframed by the line low from reset, as in simulation | 68.5 min | $8.22 | 168 | - |
| DALI | Wikipedia rev. 1363488623 | 7 / 2 / 5 | 2 of 37 | certified | none / 48.800, forward frames 25 ms apart >= 2.5e+07 ns | PASS, 38 lines, 1 tooth refused | PASS: short address 1, Query Level (160), reply 254 | 36.8 min | $4.18 | 87 | - |
| NEC IR (`ir_nec`) | SB-Projects, NEC Protocol | 13 / 0 / 13 | 1 of 67 | certified, hollow | none / 48.070, carrier frequency as its period >= 26315.8 ns | PASS, 45 lines, 2 teeth refused | PASS: address 0x59, command 0x16, repeat code | 54.6 min | $7.41 | 143 | the library's `nec` entered after the seal; this run with `--hide nec,swd`, 0 tool inputs name its files. A first run (2026-11-02 17:33, 36.7 min, $5.01, 91 turns) read `test/nec.ml` a minute in and is kept as a record only |
| Wiegand | Wikipedia rev. 1374164469 | 0 / 0 / 0 | 1 of 2 | certified, hollow | none / none | PASS joined, 1 line, 2 teeth refused | PASS: 26 bits 00010101000010010001101001, facility 42 and card 4660 with both parities; DATA1 on OUT1 read on analyser A D5 through CAN board A, Pico B on can_node to hold the bus recessive | 60.5 min | $4.08 | 113 | - |
| S/PDIF | Wikipedia rev. 1378032122 | 7 / 4 / 3 | 6 of 37 | certified | 47.947, a block of 192 frames, 44.1 kHz less 1100 ppm <= 4.35854e+06 ns / 48.052, the same, plus 1100 ppm, >= 4.34896e+06 ns | PASS joined, 17 lines, 2 teeth refused | PASS from where the line idles, as the trace joins: the five samples after the first, then silence; the whole capture decodes to nothing, as sigrok's spdif takes its clock from the line low from reset | 49.0 min | $7.37 | 121 | - |
| USB Power Delivery | USB PD R3.2 V1.2 | 153 / 131 / 22 | 23 of 777 | certified | 43.514, tUnitInterval max <= 3700 ns / 52.470, fBitRate max, each bit cell >= 3030.3 ns | PASS, 33 lines, 3 teeth refused | PASS: header 0x11a1, Source_Capabilities, PDO 0x0001912c (Fixed 5 V 3 A), CRC 0x312c2eda | 52.3 min | $6.82 | 134 | - |
