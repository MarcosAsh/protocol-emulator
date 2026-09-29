; Each pass of the gap moves t ahead by x, which changes from pass to pass. The analyser
; bounds the wait after the loop; the kernel's rows cannot, so it refuses.
    mov t, now
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
    jmp latch
