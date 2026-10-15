; Drives the set pin and OUT0 high until the host writes a word, then pulls twice: the
; second pull finds the fifo empty, an underflow, and the chip lets go of both pins.
.side_set 1
    set pindirs, 1 side 1
    set pins, 1 side 1
    wait tx side 1
    pull side 1
    pull side 1
    set pins, 0 side 0
    halt side 0
