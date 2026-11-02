; learned from a recording, unit 100.19 us, 1 ticks of the period a unit
    set pins, 3
    wait tx
    pull
    mov p, osr               ; the period
frame:
    wait tx
kind0:
    pull                     ; the first word
    mov t, now
    add t, p
    set y, 31
bit1:
    jmp !osre, have2
    pull
have2:
    wait t+
    set pins, 2
    out pins, 1
    wait t+
    set pins, 3
    jmp y--, bit1
    wait t+
    set pins, 3
    set x, 1
    mov pins, x
    wait t+
    set y, 0
outer3:
    set x, 31
inner4:
    wait t+
    jmp x--, inner4
    jmp y--, outer3
    set x, 17
rest5:
    wait t+
    jmp x--, rest5
    jmp frame
