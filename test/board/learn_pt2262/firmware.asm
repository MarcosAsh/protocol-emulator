; learned from a recording, unit 315.24 us, 1 ticks of the period a unit
    set pins, 0
    wait tx
    pull
    mov p, osr               ; the period
frame:
    wait tx
kind0:
    pull                     ; the first word
    mov t, now
    add t, p
    set y, 23
bit1:
    jmp !osre, have4
    pull
have4:
    out x, 1
    jmp x--, one2
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    wait t+
    jmp y--, bit1
    jmp after3
one2:
    wait t+
    set pins, 1
    wait t+
    wait t+
    wait t+
    set pins, 0
    jmp y--, bit1
after3:
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    set x, 29
hold5:
    wait t+
    jmp x--, hold5
    jmp frame
