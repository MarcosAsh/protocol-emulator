# Compared with PIO and PRU

The brief asks what we would do differently. PIO and PRU both give you exact cycles, and
adding them up is your job. If you get it wrong, an edge is late and nothing tells you.

Here the deadline is in the instruction set, the sum is checked before the program loads,
and a late edge at run time is a fault that takes the engine off its pins. None of the parts
are new on their own. Timed waits come from FlexPRET, and XMOS's XTA checked timing at
compile time. What this adds is a deadline theorem on the RTL itself, for every program the
kernel accepts.
