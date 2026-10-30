; learned from a recording, unit 135.31 us, 1 ticks of the period a unit
    set pins, 1
    wait tx
    pull
    mov p, osr               ; the period
frame:
    wait tx
kind0:
    pull                     ; the first word
    mov t, now
    add t, p
    set y, 7
char1:
    wait t+
    set pins, 0
    set x, 7
bits2:
    wait t+
    out pins, 1
    jmp x--, bits2
    wait t+
    set pins, 1
    jmp y--, next3
    jmp after4
next3:
    pull
    jmp char1
after4:
    wait t+
    set pins, 1
    set y, 3
outer5:
    set x, 31
inner6:
    wait t+
    jmp x--, inner6
    jmp y--, outer5
    set x, 5
rest7:
    wait t+
    jmp x--, rest7
    jmp frame
