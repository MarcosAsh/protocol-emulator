# How AI was used

AI was used extensively. Agents wrote much of this: firmware, models, checkers, proof
harnesses and reviews. I stayed in the loop for the times an agent made a mistake, or had
little confidence it could do a task itself. Nothing an agent wrote counts until it passes a gate, and a finding counts only with a reproducer
that fails on the code. Not every gate is independent of the agents. One agent wrote the
DShot600, SENT and CEC firmware and their decoders, and an agent wrote the self-check's
contract (4ea99d7), which is trusted. Counts are per finding as filed, so one bug can count
twice.

| AI does | Gate | Result | Against it |
|---|---|---|---|
| writes DShot600, SENT and CEC firmware from the specs | the kernel, then a decoder per line | 4 of 8 drafts refused, all SENT: 1 by the assembler, 3 by the kernel, 2 of them drafts the analyser had passed (`test/test_sent.ml`) | the kernel accepted 3 protocol bugs it cannot see. A decoder caught 1 and review 2 |
| attacks our claims, 10 rounds on 2026-09-30 | a reproducer, then two refuters for HIGH and MEDIUM | 76 confirmed (9 HIGH, 18 MEDIUM) and 44 rejected. All HIGH and MEDIUM were in tested code, none in proved | self-check passed 1000 quickcheck trials with 8 holes. Earlier rounds, uncounted and with no refute step, found 37 overclaims in proof work |
| finds a bug in someone else's code | a bench capture beside the RP2040's I2C block, which holds a start 4.42 us | pico-examples pio/i2c holds a start 3.125 us where I2C needs 4.0, at all 1356 starts captured. Filed as [#796](https://github.com/raspberrypi/pico-examples/issues/796) | the checker that found it had 3 HIGH soundness bugs in each of two rounds before it landed |
| writes a miner that proposes invariants for the self-check's proof (`test/certify/write_self_check.ml`) | 12-step induction, dropping claims it cannot keep, with the witness checked by Certifaiger and cake_lpr | 1957 claims from 2000 simulated runs, 6 dropped. With the rest, 7 core invariants and the reachable keys, induction proves the for-all-time self-check claim above | nine earlier sets failed. The 6 drops rest on unchecked counterexamples, from a loop not in the repo |
| reviews code with 27 planted bugs, blind | the reproducer fails on the planted tree, passes on the clean one | 22 found. It also found 10 real bugs on main, each since fixed with a test (1754480 to 3c39091, 7e9626f, b042b1e), none touching a proved claim | the planted tree's test outputs, regenerated from the bugs, show some hardware-model mismatches, so 22/27 is an upper bound |
