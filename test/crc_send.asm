; the tx fifo onto OUT0 MSB first, then the CRC unit's own bits, six cycles a bit; OUT1
; rises the cycle before the first; the first word is the data's length in bits less two
    pull
    mov y, osr
    out null, 16             ; so the next out pulls the data
    set pins, 2
bit:
    out pins, 1 [3]
    jmp y--, bit
    out pins, 1 [3]          ; the data's last bit
    crc_send                 ; with the set, the rest of its six cycles
    set x, 31
crc:
    out pins, 1 [3]
    jmp x--, crc
    halt
