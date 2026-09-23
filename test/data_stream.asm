; the data memory a byte at a time onto IO0-7, the low byte of each word first
    mov pindirs, !null
    seek [1]                 ; the shared memory needs a cycle to fetch the word
loop:
    out pins, 8 [3]
    jmp loop
