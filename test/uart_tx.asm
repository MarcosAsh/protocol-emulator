; uart tx at 16 cycles per bit; the twin of Uart.tx ~period:16 in uart.ml
    set p, 16
    set pins, 1              ; idle high
idle:
    wait tx
    pull
    set x, 7
    mov t, now               ; anchor the frame
    set pins, 0              ; start bit
    add t, p
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1              ; stop bit
    wait t
    jmp idle
