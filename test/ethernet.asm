; 10BASE-T transmit at 40 MHz; the twin of Ethernet.firmware
    pull                     ; a tenth of the link pulse interval
    mov p, osr
    set pindirs, 3
    mov t, now
    add t, p
link:
    set x, 9
tenth:
    wait t+
    jmp tx, send             ; a frame is waiting
    jmp x--, tenth
    set pins, 1 [3]          ; the link pulse, 100 ns
    set pins, 0
    jmp link
send:
    pull                     ; its length in bits less one
    mov y, osr
    set x, 0
    seek
    out null, 16             ; so the next out pulls from the data memory
    set x, 30
    set pins, 2 [1]          ; the preamble: the first half of its first one
preamble:
    set pins, 1 [3]          ; a one's second half and a zero's first
    set pins, 2 [1]          ; a zero's second half and, with the jump, a one's first
    jmp x--, preamble
    set pins, 1 [1]          ; the start of frame ends in two ones
    set pins, 2 [1]
    set pins, 1 [1]
bit:
    out pins, 1 [1]          ; the first half of the bit, and with the jump the second
    jmp y--, bit
    set pins, 1 [10]         ; TP_IDL, high 275 ns
    set pins, 0
    mov t, now
    add t, p
    jmp link
