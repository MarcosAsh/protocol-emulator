; ws2812 waiting after its gap: the analyser accepts it, no interval row can, so it fails
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
    add t, p
    jmp x--, gap
    wait t
    wait tx                  ; the line has been low for 160 thirds
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
