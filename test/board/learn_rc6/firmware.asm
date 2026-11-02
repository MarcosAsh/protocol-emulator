; learned from a recording, unit 446.23 us, 1 ticks of the period a unit
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
    wait t+
    set pins, 0
    set x, 4
hold1:
    wait t+
    jmp x--, hold1
    wait t+
    set pins, 1
    wait t+
    set y, 3
bit2:
    jmp !osre, have5
    pull
have5:
    out x, 1
    jmp x--, one3
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    jmp y--, bit2
    jmp after4
one3:
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    jmp y--, bit2
after4:
    set y, 0
bit6:
    jmp !osre, have9
    pull
have9:
    out x, 1
    jmp x--, one7
    wait t+
    set pins, 1
    wait t+
    wait t+
    set pins, 0
    wait t+
    jmp y--, bit6
    jmp after8
one7:
    wait t+
    set pins, 0
    wait t+
    wait t+
    set pins, 1
    wait t+
    jmp y--, bit6
after8:
    set y, 15
bit10:
    jmp !osre, have13
    pull
have13:
    out x, 1
    jmp x--, one11
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    jmp y--, bit10
    jmp after12
one11:
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    jmp y--, bit10
after12:
    wait t+
    set pins, 1
    set y, 4
outer14:
    set x, 31
inner15:
    wait t+
    jmp x--, inner15
    jmp y--, outer14
    set x, 23
rest16:
    wait t+
    jmp x--, rest16
    jmp frame
