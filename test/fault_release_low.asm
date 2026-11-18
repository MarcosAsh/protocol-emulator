; Drives the set pin low until the host writes a word, then pulls twice: the second pull
; finds the fifo empty, an underflow, and the chip lets go of the pin. Nothing here
; releases it or drives it high, so on a pulled-up pin a rise is the chip letting go.
    set pindirs, 1
    set pins, 0
    wait tx
    pull
    pull
    halt
