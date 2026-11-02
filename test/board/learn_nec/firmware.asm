; learned from a recording, unit 557.00 us, 1 ticks of the period a unit
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
    set x, 14
hold1:
    wait t+
    jmp x--, hold1
    wait t+
    set pins, 1
    set x, 6
hold2:
    wait t+
    jmp x--, hold2
    set y, 31
bit3:
    jmp !osre, have6
    pull
have6:
    out x, 1
    jmp x--, one4
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    jmp y--, bit3
    jmp after5
one4:
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    wait t+
    wait t+
    jmp y--, bit3
after5:
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    set y, 1
outer7:
    set x, 31
inner8:
    wait t+
    jmp x--, inner8
    jmp y--, outer7
    set x, 5
rest9:
    wait t+
    jmp x--, rest9
    wait t+
    set pins, 0
    set x, 14
hold10:
    wait t+
    jmp x--, hold10
    wait t+
    set pins, 1
    wait t+
    wait t+
    wait t+
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    set y, 25
outer11:
    set x, 31
inner12:
    wait t+
    jmp x--, inner12
    jmp y--, outer11
    set x, 16
rest13:
    wait t+
    jmp x--, rest13
    jmp frame
