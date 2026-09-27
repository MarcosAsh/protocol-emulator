; ws2812 waiting after its gap, with the last add t, p of the gap made add t, x: each
; pass moves t ahead by a different amount, so the analyser accepts it but no row the
; kernel has bounds the phase round the loop, and it fails
    mov t, now
    set pins, 0
    set p, 6
latch:
    mov t, now
    set x, 31
gap:
    add t, p
    add t, p
    add t, p
    add t, p
    add t, x
    jmp x--, gap
    wait t
    wait tx
    mov t, now
    add t, p
pixel:
    set y, 15
word:
    pull
    mov x, y
bit:
    wait t+
    set pins, 1              ; rise
    wait t+
    out pins, 1              ; a zero falls here
    wait t+
    set pins, 0              ; a one falls here
    add t, 7
    jmp x--, bit
    set x, 15
    jmp x!=y, last
    set y, 7
    jmp word
last:
    jmp tx, pixel
    jmp latch
