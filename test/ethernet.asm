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
    pull                     ; the frame's length in bits less two
    mov y, osr
    set x, 0
    seek
    out null, 16             ; so the next out pulls from the data memory
    set x, 30
preamble:
    out pins, 1 [1]          ; the first half of the bit, and with the jump the second
    jmp x--, preamble
    out pins, 1 [1]
    set x, 30 [1]            ; the second half of the preamble's 32nd bit
start:
    out pins, 1 [1]
    jmp x--, start
    out pins, 1 [1]          ; the start of frame's last bit
    crc_init [1]             ; the FCS covers what follows
bit:
    out pins, 1 [1]
    jmp y--, bit
    out pins, 1 [1]          ; the frame's last bit
    crc_send                 ; so the outs send the FCS
    set x, 31
fcs:
    out pins, 1 [1]
    jmp x--, fcs
    set pins, 1 [10]         ; TP_IDL, high 275 ns
    set pins, 0
    mov t, now
    add t, p
    jmp link
