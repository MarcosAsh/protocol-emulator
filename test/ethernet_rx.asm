; 10BASE-T receive: once the chip's receiver has the frame, its words to the host
    pull                     ; where the frame lands
    mov x, osr
    wait 1 pin 28            ; finished, the owner's first status pin
    seek
    out null, 16             ; so the next out pulls from the data memory
loop:
    out isr, 16
    wait rx
    push
    jmp loop
