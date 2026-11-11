# Run it on the board

Open a GitHub issue with a waveform and the bench runs it. The bench is an Icepi Zero FPGA
(ECP5) on my desk, running the chip's RTL at 48 MHz. No silicon exists yet. A worker on the
PC next to it picks up the issue, runs the job and answers there.

A job is a WaveDrom diagram and the frames to send. It is compiled to a table for an
interpreter the kernel certified once, so the chip runs that one certified program and your
job only brings data words. A diagram that can't meet its timing is refused before it reaches
the board, and the refusal names the limit.

## Sending a job

1. On the [lab page](https://marcosash.github.io/protocol-emulator/playground/lab.html),
   write the diagram, give the frames (a line of bits per frame, first bit sent first) and
   pick a decoder: none, `ws281x`, or `uart` at 300 to 4,000,000 baud.
2. Press Check. Your browser runs the same check as the bench and shows the certificate or
   the refusal.
3. Press "Run on the real chip". It opens the issue form with the job filled in and the `lab`
   label set. You can also copy the job into an
   [empty form](https://github.com/MarcosAsh/protocol-emulator/issues/new?template=lab.yml).

This is the job from [issue #2](https://github.com/MarcosAsh/protocol-emulator/issues/2), two
UART bytes at 1.846 Mbaud, 26 cycles a bit at 48 MHz:

```json
{
 "lab": 1,
 "diagram": "{ \"signal\": [\n    { \"name\": \"tx\", \"wave\": \"10========1\", \"data\": [\"b0\", \"b1\", \"b2\", \"b3\", \"b4\", \"b5\", \"b6\", \"b7\"] }\n  ],\n  \"head\": { \"text\": \"UART 8N1, 1.92 Mbaud\" },\n  \"table\": { \"cycles\": 26 }\n}\n",
 "frames": "11000101\n00111010",
 "decode": "uart:1846154"
}
```

## What happens to it

The worker checks for open `lab` issues every 10 minutes. It waits while Tiny Tapeout CI or
a game has the PC, or another run has the board, so an answer can take hours.

The bench takes a job if every output lane is on OUT0, the job reads nothing, and all the
host's words fit the transmit FIFO before the start. Analyser A captures OUT0 at 24 MS/s and
sigrok decodes it. Other jobs run on the model of the core. Each answer says which it was:
captured on the bench, rehearsed on the RTL in cocotb, or simulated on the model.

The answer is one comment with the verdict, the sealed `result.json` and a link to the run's
files on the `bench-runs` branch. Then the issue gets the `lab-done` label and is closed.
Refusals get the same.

## Limits

Each person gets 3 bench runs an hour, 10 a day and 30 jobs an hour, and the lab as a whole
takes 30 bench runs an hour. A job over its limit gets a comment saying when it will run, and
the issue stays open.

Everything in the issue is public. The worker reads the first `json` block and treats it as
data.

## Checking an answer

Enter the issue number under "Already submitted?" on the lab page to fetch the answer. You can
also open a result folder's `result.json`, or every file in the folder, and the page checks
each file against the hashes in `result.json`.
